# build_zip.ps1
# Copyright (c) 2026-present, Dwyco, Inc.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at https://mozilla.org/MPL/2.0/.

#
# Build and package script for SkimView Qt6 app on Windows (portable ZIP)
# Usage:
#   .\build_zip.ps1 [-QtPath <path>] [-OutputDir <dir>] [-BuildDir <dir>]
#                   [-Clean] [-SkipBuild] [-Help]
#
# Produces a portable ZIP distribution containing the built SkimView.exe with
# all required Qt runtime dependencies, QML modules, image/SQL drivers, and the
# Python helper scripts in a tools/ directory. The ZIP is named
#   SkimView-<version>-win64.zip
# and can be extracted and run without installation.
#
# NOTE: For the optional AI tagging/OCR feature the app launches "python3".
# On Windows you must ensure a "python3" command is available on PATH (e.g.
# install Python from https://python.org and tick "Add to PATH", or create a
# python3 -> python shim). Tesseract and Ollama are also required for tagging.

[CmdletBinding()]
param(
    [string]$QtPath,
    [string]$OutputDir,
    [string]$BuildDir,
    [switch]$Clean,
    [switch]$SkipBuild,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$APP_NAME      = "SkimView"
$PROJECT_DIR   = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BuildDir)  { $BuildDir  = Join-Path ([System.IO.Path]::GetTempPath()) "skimview-build" }
if (-not $OutputDir) { $OutputDir = $PROJECT_DIR }
$VERSION_FILE  = Join-Path $PROJECT_DIR "VERSION.txt"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
function Show-Help {
    Write-Host "Usage: .\build_zip.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -QtPath <path>      Path to Qt installation (e.g. C:\Qt\6.11.1\msvc2022_64)"
    Write-Host "                      Searched automatically if omitted."
    Write-Host "  -OutputDir <dir>    Directory to place the final ZIP (default: project root)"
    Write-Host "  -BuildDir <dir>     CMake build directory (default: %TEMP%\skimview-build)"
    Write-Host "  -Clean              Remove previous build directory before starting"
    Write-Host "  -SkipBuild          Skip cmake configure & build; only re-package"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Environment:"
    Write-Host "  QT_PATH  Path to Qt installation (used if -QtPath not given)"
    exit 0
}

if ($Help) { Show-Help }

# ---------------------------------------------------------------------------
# Version (mirrors vers.sh / build_appimage.sh)
# ---------------------------------------------------------------------------
function Generate-Version {
    $major = ""
    if (Test-Path $VERSION_FILE) {
        $major = (Get-Content $VERSION_FILE -Raw).Trim()
    }
    if (-not $major) { $major = "0" }

    $build = (git -C $PROJECT_DIR rev-list --count HEAD 2>$null).Trim()
    if (-not $build) { $build = "0" }

    $sha = (git -C $PROJECT_DIR rev-parse --short HEAD 2>$null).Trim()
    if (-not $sha) { $sha = "unknown" }

    return "$major+$build-$sha"
}

$VERSION = Generate-Version
Write-Host "=========================================="
Write-Host "Building $APP_NAME  (version $VERSION)"
Write-Host "=========================================="
Write-Host "Project dir: $PROJECT_DIR"
Write-Host "Build dir:   $BUILD_DIR"

# ---------------------------------------------------------------------------
# Qt detection
# ---------------------------------------------------------------------------
function Find-Qt {
    # 1. Explicit parameter
    if ($QtPath -and (Test-Path (Join-Path $QtPath "bin\windeployqt.exe"))) {
        return $QtPath
    }
    # 2. QT_PATH env
    $qt = $env:QT_PATH
    if ($qt -and (Test-Path (Join-Path $qt "bin\windeployqt.exe"))) {
        return $qt
    }
    # 3. QTDIR env
    $qt = $env:QTDIR
    if ($qt -and (Test-Path (Join-Path $qt "bin\windeployqt.exe"))) {
        return $qt
    }
    # 4. Common install roots (C:\Qt and per-user Qt dirs)
    $roots = @()
    if (Test-Path "C:\Qt")             { $roots += "C:\Qt" }
    if ($env:USERNAME)                 { $roots += "C:\Users\$env:USERNAME\Qt" }
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($dir1 in (Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path (Join-Path $dir1.FullName "bin\windeployqt.exe")) { return $dir1.FullName }
            # Descend one level (e.g. 6.11.1\msvc2022_64)
            foreach ($dir2 in (Get-ChildItem -Path $dir1.FullName -Directory -ErrorAction SilentlyContinue)) {
                if (Test-Path (Join-Path $dir2.FullName "bin\windeployqt.exe")) { return $dir2.FullName }
            }
        }
    }
    # 5. windeployqt on PATH -> derive Qt dir (parent of bin)
    $found = Get-Command windeployqt.exe -ErrorAction SilentlyContinue
    if ($found) {
        return Split-Path -Parent $found.Source
    }
    return ""
}

$QT_PATH = Find-Qt
if ($QT_PATH) {
    $QT_BIN = Join-Path $QT_PATH "bin"
    Write-Host "Qt found: $QT_PATH"
} else {
    Write-Error "Error: Qt not found.`n" +
        "  Install Qt 6 from https://www.qt.io/download-qt-installer`n" +
        "  Then pass -QtPath <path>, or set the QT_PATH environment variable."
    exit 1
}

$WINDDEPLOYQT = Join-Path $QT_BIN "windeployqt.exe"
if (-not (Test-Path $WINDDEPLOYQT)) {
    Write-Error "Error: windeployqt.exe not found at $WINDDEPLOYQT"
    exit 1
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
$cmake = Get-Command cmake.exe -ErrorAction SilentlyContinue
if (-not $cmake) {
    Write-Error "Error: cmake not found. Install CMake from https://cmake.org/download/"
    exit 1
}

# A C++ compiler must be discoverable by CMake. On Windows this is typically
# satisfied when running from a "Developer Command Prompt for Visual Studio".
$ninja = Get-Command ninja.exe -ErrorAction SilentlyContinue
if ($ninja) {
    $USE_NINJA = $true
    Write-Host "Generator: Ninja"
} else {
    $USE_NINJA = $false
    Write-Host "Generator: default (Visual Studio)"
    Write-Host "  Make sure a C++ compiler and Windows SDK are on PATH"
    Write-Host "  (run from a 'Developer Command Prompt for VS' if in doubt)."
}

# ---------------------------------------------------------------------------
# Configure & build
# ---------------------------------------------------------------------------
if ($Clean -and (Test-Path $BUILD_DIR)) {
    Write-Host "Cleaning previous build directory..."
    Remove-Item -Recurse -Force $BUILD_DIR
}

if (-not $SkipBuild) {
    New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Configuring with CMake..."
    Write-Host "=========================================="
    if ($USE_NINJA) {
        & cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" -G Ninja `
            -DCMAKE_BUILD_TYPE=Release `
            -DCMAKE_PREFIX_PATH="$QT_PATH"
    } else {
        & cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" `
            -DCMAKE_PREFIX_PATH="$QT_PATH"
    }
    if ($LASTEXITCODE -ne 0) { Write-Error "CMake configuration failed."; exit 1 }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Building..."
    Write-Host "=========================================="
    if ($USE_NINJA) {
        & cmake --build "$BUILD_DIR" --parallel
    } else {
        & cmake --build "$BUILD_DIR" --config Release --parallel
    }
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed."; exit 1 }
} else {
    Write-Host "Skipping build (--SkipBuild). Using existing binaries in $BUILD_DIR"
}

# ---------------------------------------------------------------------------
# Locate the built executable
# ---------------------------------------------------------------------------
$EXE_NAME = "$APP_NAME.exe"
$exeCandidates = @(
    (Join-Path $BUILD_DIR $EXE_NAME),
    (Join-Path $BUILD_DIR "Release" $EXE_NAME),
    (Join-Path $BUILD_DIR "Debug" $EXE_NAME)
)
$BINARY = $null
foreach ($c in $exeCandidates) {
    if (Test-Path $c) { $BINARY = $c; break }
}
if (-not $BINARY) {
    Write-Error "Error: Built executable ($EXE_NAME) not found under $BUILD_DIR"
    exit 1
}
Write-Host "Binary: $BINARY"

# ---------------------------------------------------------------------------
# Stage the distribution tree
# ---------------------------------------------------------------------------
$STAGING = Join-Path $BUILD_DIR "$APP_NAME-$VERSION-win64"
if (Test-Path $STAGING) { Remove-Item -Recurse -Force $STAGING }
New-Item -ItemType Directory -Force -Path $STAGING | Out-Null

# Copy the executable into the staging root
Copy-Item -Path $BINARY -Destination $STAGING

# Run windeployqt: bundles Qt DLLs, QML modules (via --qmldir), platform/sql/
# imageformat plugins, and the MSVC compiler runtime (--compiler-runtime).
Write-Host ""
Write-Host "=========================================="
Write-Host "Running windeployqt..."
Write-Host "=========================================="
Push-Location $STAGING
try {
    $exePath = Join-Path $STAGING $EXE_NAME
    & "$WINDDEPLOYQT" --release --compiler-runtime `
        --qmldir "$PROJECT_DIR" `
        --dir "$STAGING" `
        "$exePath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "windeployqt failed."
        exit 1
    }
} finally {
    Pop-Location
}

# Copy the Python helper scripts next to the executable so
# TaggingHandler::findScript() resolves them via "appDir/tools/tag_images.py".
Write-Host "Copying tools/ directory..."
$TOOLS_SRC = Join-Path $PROJECT_DIR "tools"
$TOOLS_DST = Join-Path $STAGING "tools"
Copy-Item -Path $TOOLS_SRC -Destination $TOOLS_DST -Recurse -Force

# ---------------------------------------------------------------------------
# A short README inside the distribution
# ---------------------------------------------------------------------------
$README_TEXT = @"
SkimView - portable distribution (version $VERSION)
====================================================

Contents:
  SkimView.exe  - the application executable
  *.dll         - Qt runtime libraries + MSVC C++ runtime
  qml/          - bundled Qt QML modules
  plugins/      - platform, SQL driver, and image-format plugins
  tools/        - Python helper scripts (tag_images.py, add_copyright.py)

Run SkimView.exe directly; no installation is required.

Optional (only needed for the AI tagging / OCR feature):
  * Python 3        https://python.org  (the app launches "python3")
  * pip install pytesseract pillow requests
  * Tesseract OCR   https://github.com/UB-Mannheim/tesseract/wiki
  * Ollama          https://ollama.ai   ->  run: ollama pull llava

On Windows, ensure a "python3" command is on your PATH for the tagging feature.
"@
Set-Content -Path (Join-Path $STAGING "README.txt") -Value $README_TEXT -Encoding UTF8

# ---------------------------------------------------------------------------
# Create the portable ZIP
# ---------------------------------------------------------------------------
$ZIP_NAME = "$APP_NAME-$VERSION-win64.zip"
$ZIP_PATH = Join-Path $OutputDir $ZIP_NAME

Write-Host ""
Write-Host "=========================================="
Write-Host "Packaging ZIP..."
Write-Host "=========================================="

# Compress-Archive stores paths relative to the common root of the input
# paths, but its handling of directory prefixes differs across PowerShell
# versions. The .NET ZipFile.CreateFromDirectory API with
# includeBaseDirectory:$true is well-defined: it produces a single top-level
# folder (named after $STAGING) and is independent of the current directory.
# Remove any pre-existing archive; CreateFromDirectory throws if the target exists.
if (Test-Path $ZIP_PATH) { Remove-Item $ZIP_PATH }

# Compress-Archive stores paths relative to the common root of the input
# paths, but its handling of directory prefixes differs across PowerShell
# versions. The .NET ZipFile.CreateFromDirectory API with
# includeBaseDirectory:$true is well-defined: it produces a single top-level
# folder (named after $STAGING) and is independent of the current directory.
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $STAGING, $ZIP_PATH, [System.IO.Compression.CompressionLevel]::Optimal, $true)

Write-Host ""
Write-Host "=========================================="
Write-Host "Build Complete!"
Write-Host "=========================================="
Write-Host "ZIP:  $ZIP_PATH"
Write-Host "Size: $((Get-Item $ZIP_PATH).Length / 1MB) MB"
Write-Host ""
Write-Host "To use: extract the ZIP and run SkimView.exe."
