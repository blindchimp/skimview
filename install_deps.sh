#!/bin/bash
# install_deps.sh — Install dependencies for SkimView on macOS (Homebrew)
#
# Usage:
#   ./install_deps.sh          # install all dependencies (build + run + tagging)
#   ./install_deps.sh --run    # install only deps needed to run the app + tagging
#   ./install_deps.sh --build  # install only deps needed to build the app

set -euo pipefail

MODE="${1:-all}"

echo "==> SkimView Dependency Installer (macOS + Homebrew)"

if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is required. Install from https://brew.sh" >&2
    exit 1
fi

install_build_deps() {
    echo ""
    echo "--- Build Dependencies ---"

    # Xcode Command Line Tools (provides compiler, macOS SDK, etc.)
    if ! xcode-select -p &>/dev/null; then
        echo "Installing Xcode Command Line Tools..."
        xcode-select --install
        echo "   (Follow the GUI prompt, then re-run this script)"
        exit 0
    else
        echo "[ok] Xcode Command Line Tools"
    fi

    # CMake
    if ! command -v cmake &>/dev/null; then
        echo "Installing cmake..."
        brew install cmake
    else
        echo "[ok] cmake $(cmake --version | head -1 | awk '{print $3}')"
    fi

    # Qt 6
    if ! brew list qt &>/dev/null 2>&1; then
        echo "Installing Qt 6 via Homebrew (this may take a while)..."
        brew install qt
    else
        echo "[ok] Qt 6 (Homebrew)"
    fi
    echo ""
}

install_run_deps() {
    echo ""
    echo "--- Runtime / Tagging Dependencies ---"

    # Python 3
    if ! command -v python3 &>/dev/null; then
        echo "Installing python3..."
        brew install python
    else
        echo "[ok] python3"
    fi

    # Tesseract OCR (used by tag_images.py)
    if ! command -v tesseract &>/dev/null; then
        echo "Installing tesseract..."
        brew install tesseract
    else
        echo "[ok] tesseract"
    fi

    # Ollama (AI vision model runner)
    if ! command -v ollama &>/dev/null; then
        echo "Installing ollama..."
        brew install ollama
    else
        echo "[ok] ollama"
    fi

    # Python packages
    echo "Installing Python packages (pytesseract, Pillow, requests)..."
    python3 -m pip install --quiet --upgrade pytesseract Pillow requests

    echo ""
}

case "$MODE" in
    --run)
        install_run_deps
        echo "==> Run dependencies installed."
        echo "    The app itself is a macOS .app bundle with Qt bundled inside."
        echo "    To run from source, you also need --build deps."
        ;;
    --build)
        install_build_deps
        echo "==> Build dependencies installed."
        echo "    To build: mkdir build && cd build && cmake .. && cmake --build ."
        echo "    Note: make sure Homebrew's Qt is on your path:"
        echo "      export PATH=\"\$(brew --prefix qt)/bin:\$PATH\""
        echo "      cmake .. -DCMAKE_PREFIX_PATH=\"\$(brew --prefix qt)\""
        ;;
    *)
        install_build_deps
        install_run_deps
        echo "==> All dependencies installed!"
        echo "    To build:"
        echo "      export PATH=\"\$(brew --prefix qt)/bin:\$PATH\""
        echo "      mkdir build && cd build"
        echo "      cmake .. -DCMAKE_PREFIX_PATH=\"\$(brew --prefix qt)\""
        echo "      cmake --build ."
        echo ""
        echo "    To pull an Ollama vision model for tagging:"
        echo "      ollama pull llava"
        ;;
esac
