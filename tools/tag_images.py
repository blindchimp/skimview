#!/usr/bin/env python3
"""Tag images using Ollama vision models and Tesseract OCR.

Scans a directory for images, runs OCR + vision model tagging,
and stores results in a local tags.db SQLite database.

Usage:
    python tools/tag_images.py ~/Pictures [--model llava]
"""

import argparse
import base64
import hashlib
import os
import json
import platform
import shutil
import sqlite3
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Optional

import requests
from PIL import Image

try:
    import pytesseract
except ImportError:
    pytesseract = None

OLLAMA_BASE_URL = "http://localhost:11434"
SUPPORTED_EXTENSIONS = frozenset({
    ".bmp", ".gif", ".jpg", ".jpeg", ".pbm", ".pgm", ".pnm",
    ".png", ".ppm", ".svg", ".tif", ".tiff", ".webp",
    ".xbm", ".xpm", ".heic", ".heif", ".avif",
})
MAX_WORKERS = 4
MAX_OCR_PIXELS = 2500  # largest image dimension handed to tesseract
OCR_TIMEOUT_SECONDS = 120


class ProgressTracker:
    def __init__(self, ocr_total: int, tag_total: int, ocr_done: int = 0, tag_done: int = 0):
        self.ocr_total = ocr_total
        self.tag_total = tag_total
        self.ocr_count = ocr_done
        self.tag_count = tag_done
        self._lock = threading.Lock()
        self._emit()

    def ocr_done(self):
        with self._lock:
            self.ocr_count += 1
            self._emit()

    def tag_done(self):
        with self._lock:
            self.tag_count += 1
            self._emit()

    def _emit(self):
        print(json.dumps({
            "type": "progress",
            "ocr": self.ocr_count,
            "ocr_total": self.ocr_total,
            "tag": self.tag_count,
            "tag_total": self.tag_total,
        }), flush=True)

OLLAMA_CHECK_RETRIES = 15
OLLAMA_RETRY_DELAY = 2
TAG_PROMPT = (
    "List 5-15 concise, comma-separated tags describing this image's content "
    "(objects, scenes, people, colors, style). "
    "Reply with only the tags, nothing else."
)


def _find_ollama() -> Optional[str]:
    """Locate the ollama binary."""
    path = shutil.which("ollama")
    if path:
        return path
    for candidate in [
        "/usr/local/bin/ollama",
        "/opt/homebrew/bin/ollama",
        os.path.expanduser("~/bin/ollama"),
    ]:
        if os.path.isfile(candidate):
            return candidate
    return None


def ensure_ollama() -> bool:
    """Check if Ollama is running; try to start it if not."""
    def is_alive() -> bool:
        try:
            resp = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=3)
            return resp.ok
        except requests.RequestException:
            return False

    if is_alive():
        return True

    print("Ollama is not running. Starting it...", file=sys.stderr)

    ollama_bin = _find_ollama()
    if not ollama_bin:
        print("Error: could not find 'ollama' binary in PATH or standard locations.",
              file=sys.stderr)
        return False

    subprocess.Popen(
        [ollama_bin, "serve"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )

    for i in range(OLLAMA_CHECK_RETRIES):
        time.sleep(OLLAMA_RETRY_DELAY)
        if is_alive():
            print("Ollama is ready.", file=sys.stderr)
            return True
        print(f"  Waiting for Ollama... ({i + 1}/{OLLAMA_CHECK_RETRIES})",
              file=sys.stderr)

    print("Error: Ollama did not start. See https://ollama.ai",
          file=sys.stderr)
    return False


def get_db(dir_path: Path) -> sqlite3.Connection:
    db_path = dir_path / "tags.db"
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            file_hash TEXT NOT NULL,
            tags TEXT,
            ocr_text TEXT,
            description TEXT,
            model TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_path ON images(path);
        CREATE INDEX IF NOT EXISTS idx_hash ON images(file_hash);
    """)
    conn.commit()
    return conn


def file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def needs_update(conn: sqlite3.Connection, path: str, fhash: str) -> bool:
    row = conn.execute(
        "SELECT file_hash, tags, ocr_text FROM images WHERE path = ?", (path,)
    ).fetchone()
    if row is None or row["file_hash"] != fhash:
        return True
    if not (row["tags"] or "").strip():
        return True
    if row["ocr_text"] is None:
        return True
    return False


def _find_tesseract() -> Optional[str]:
    """Locate the tesseract binary, independent of the current PATH."""
    candidates = []
    for name in ("tesseract", "tesseract.exe"):
        which = shutil.which(name)
        if which:
            candidates.append(which)
    for candidate in [
        "/opt/homebrew/bin/tesseract",
        "/usr/local/bin/tesseract",
        "/opt/local/bin/tesseract",
        os.path.expanduser("~/bin/tesseract"),
    ]:
        if candidate not in candidates:
            candidates.append(candidate)
    for candidate in candidates:
        if candidate and os.path.isfile(candidate):
            return candidate
    return None


def _prepare_for_ocr(img: Image.Image) -> Image.Image:
    """Downscale very large images; tesseract can hang for hours on 12MP+ frames."""
    if max(img.size) > MAX_OCR_PIXELS:
        img = img.convert("RGB")
        ratio = MAX_OCR_PIXELS / max(img.size)
        img = img.resize((max(1, int(img.width * ratio)), max(1, int(img.height * ratio))))
    elif img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    return img


def run_ocr(path: Path) -> Optional[str]:
    """OCR an image.

    Returns the extracted text ("" if the image has no readable text), or
    None if OCR could not run (pytesseract/tesseract unavailable, the image
    could not be opened, or tesseract timed out). None is stored as NULL so
    the file is retried on the next run instead of being skipped forever.
    """
    if pytesseract is None:
        return None
    tesseract_bin = _find_tesseract()
    if tesseract_bin:
        pytesseract.pytesseract.tesseract_cmd = tesseract_bin
    try:
        img = _prepare_for_ocr(Image.open(path))
        return pytesseract.image_to_string(img, timeout=OCR_TIMEOUT_SECONDS).strip()
    except Exception as e:
        print(f"  OCR failed for {path.name}: {e}", file=sys.stderr)
        return None


def run_ollama(model: str, prompt: str, image_path: Path) -> Optional[dict]:
    with open(image_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")
    try:
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json={
                "model": model,
                "prompt": prompt,
                "images": [b64],
                "stream": False,
                "num_predict": 128,
            },
            timeout=120,
        )
        resp.raise_for_status()
        data = resp.json()
        return data
    except requests.RequestException:
        return None


def parse_tags(text: str) -> list[str]:
    text = text.strip().strip("[]()")
    parts = [t.strip().strip('"\'') for t in text.split(",")]
    return [t.lower() for t in parts if t and len(t) < 100]


def process_image(path: Path, model: str, db_dir: Path, tracker: ProgressTracker, ocr_available: bool = True, ollama_available: bool = True, force: bool = False) -> dict:
    conn = get_db(db_dir)
    fhash = file_hash(path)
    rel = str(path)

    row = conn.execute(
        "SELECT file_hash, tags, ocr_text, description FROM images WHERE path = ?",
        (rel,),
    ).fetchone()

    hash_changed = row is None or row["file_hash"] != fhash
    existing_tags = (row["tags"] or "") if row is not None else ""
    existing_ocr = row["ocr_text"] if row is not None else None
    existing_desc = (row["description"] or "") if row is not None else ""

    # A row needs re-OCR when it was never successfully OCR'd (NULL value).
    # A row needs (re-)tagging when it has no tags or its hash changed.
    need_ocr = force or row is None or hash_changed or existing_ocr is None
    need_tags = force or row is None or hash_changed or not existing_tags.strip()

    if not need_ocr and not need_tags:
        conn.close()
        if ocr_available:
            tracker.ocr_done()
        tracker.tag_done()
        return {"path": rel, "status": "skipped"}

    if need_ocr:
        if ocr_available:
            print(f"  OCR: {path.name}", flush=True)
            ocr_text = run_ocr(path)
            tracker.ocr_done()
        else:
            ocr_text = None
    else:
        ocr_text = existing_ocr
        if ocr_available:
            tracker.ocr_done()

    if need_tags:
        if ollama_available:
            print(f"  Tag: {path.name}", flush=True)
            result = run_ollama(model, TAG_PROMPT, path)
        else:
            result = None
        tracker.tag_done()
        tags = ""
        description = ""
        if result and "response" in result:
            raw = result["response"]
            tags = ",".join(parse_tags(raw))
            if not tags:
                description = raw[:500]
    else:
        tags = existing_tags
        description = existing_desc
        if ollama_available:
            tracker.tag_done()

    conn.execute(
        """INSERT INTO images (path, file_hash, tags, ocr_text, description, model)
           VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(path) DO UPDATE SET
               file_hash = excluded.file_hash,
               tags = excluded.tags,
               ocr_text = excluded.ocr_text,
               description = excluded.description,
               model = excluded.model,
               updated_at = CURRENT_TIMESTAMP""",
        (rel, fhash, tags, ocr_text, description, model),
    )
    conn.commit()
    conn.close()
    return {"path": rel, "status": "tagged", "tags": tags, "ocr_len": len(ocr_text or "")}


def collect_images(root: Path) -> list[Path]:
    return [
        p for p in root.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
    ]


def main():
    parser = argparse.ArgumentParser(
        description="Tag images using Ollama vision models + Tesseract OCR"
    )
    parser.add_argument("directory", nargs="?", type=Path,
                        help="Directory of images")
    parser.add_argument("--file", type=Path,
                        help="Process a single image file instead of directory")
    parser.add_argument("--force", action="store_true",
                        help="Force reprocess even if file hash hasn't changed")
    parser.add_argument("--model", default="llava",
                        help="Ollama vision model (default: llava)")
    parser.add_argument("--max-workers", type=int, default=MAX_WORKERS,
                        help=f"Parallel workers (default: {MAX_WORKERS})")
    parser.add_argument("--dry-run", action="store_true",
                        help="List files that would be processed without doing it")
    args = parser.parse_args()

    if args.file:
        if not args.file.is_file():
            print(f"Error: {args.file} is not a file", file=sys.stderr)
            sys.exit(1)
        images = [args.file]
        db_dir = args.file.parent
        force = args.force
    else:
        if not args.directory or not args.directory.is_dir():
            print(f"Error: {args.directory} is not a directory", file=sys.stderr)
            sys.exit(1)
        images = collect_images(args.directory)
        db_dir = args.directory
        force = args.force

    if not images:
        print("No supported images found.")
        return

    # Filter to images needing processing
    conn = get_db(db_dir)
    to_process = []
    for img in images:
        if args.dry_run or force or needs_update(conn, str(img), file_hash(img)):
            to_process.append(img)

    if args.dry_run:
        print(f"Would process {len(to_process)} images:")
        for p in to_process:
            print(f"  {p}")
        conn.close()
        return

    total_to_process = len(to_process)
    print(f"Found {len(images)} images, {total_to_process} to process "
          f"(model: {args.model})")

    if pytesseract is None:
        print("OCR unavailable (tesseract/pytesseract not found).", file=sys.stderr)

    ollama_available = True
    if to_process:
        ollama_available = ensure_ollama()
        if not ollama_available:
            print("Tag generation unavailable (Ollama not available).", file=sys.stderr)

    already_done = len(images) - total_to_process
    ocr_available = pytesseract is not None
    ocr_total = len(images) if ocr_available else 0
    tag_total = len(images) if ollama_available else 0
    ocr_done = already_done if ocr_available else 0
    tag_done = already_done if ollama_available else 0
    tracker = ProgressTracker(ocr_total, tag_total, ocr_done, tag_done)
    start = time.time()
    tagged = skipped = errors = 0

    with ThreadPoolExecutor(max_workers=args.max_workers) as pool:
        futures = {
            pool.submit(process_image, img, args.model, db_dir, tracker, ocr_available, ollama_available, force): img
            for img in to_process
        }
        for future in as_completed(futures):
            try:
                result = future.result()
                if result["status"] == "skipped":
                    skipped += 1
                else:
                    tagged += 1
                    t = result.get("tags", "")
                    print(f"  -> {Path(result['path']).name}: {t[:80]}")
            except Exception as e:
                errors += 1
                img = futures[future]
                print(f"  [ERR] {img.name}: {e}", file=sys.stderr)

    elapsed = time.time() - start
    print(f"\nDone: {tagged} tagged, {skipped} skipped, {errors} errors "
          f"in {elapsed:.1f}s")

    conn.close()


if __name__ == "__main__":
    main()
