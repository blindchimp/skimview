Mon May 18 09:08:21 MDT 2026

This is a simple image viewer using Qt/QML 6.11.

WARNING: this was vibe-coded using AI available around the date mentioned above, using claude code and opencode.  The models were variously glm-4.7 and qwen3-coder-next, in what ever size was available for free via ollama. with opencode, the default model was used (Big Pickle?). i preferred using opencode, and the model produced much better results than claud code (and it was significantly faster.)

I used macos at the time, and have not ported it to other OS's.

## Features

- **Thumbnail Grid** — grid of image thumbnails with keyboard navigation and filename/date sorting
- **Full-Screen Viewer** — zoom to 2x, 1:1, 1/2; pinch-to-zoom; click-and-drag pan
- **Filename Search** — filter thumbnails by substring
- **Jump to Date** — scroll to images by date via natural-language input
- **Trash Support** — press `d` to send current image to macOS Trash
- **Clipboard Copy** — copy current image path to clipboard
- **AI Tagging & OCR** — Python script using Tesseract + Ollama vision models to tag and OCR images; results stored in SQLite
- **Tag & OCR Search** — query tags.db to filter thumbnails; view tags and OCR text per image
- **macOS Packaging** — build script creates signed, notarized DMG


