#!/usr/bin/env python3
"""Add a copyright block from cr.txt to the top of files that don't already have it."""

import sys
import os
import shutil
import re

COMMENT_STYLES = {
    # hash-style: .py, .rb, .sh, .yaml, .yml, .cmake, .txt, .env, .dockerfile, .ini, .cfg
    'hash': ('# ', '# '),
    # slash-style: .js, .ts, .jsx, .tsx, .css, .scss, .less, .java, .c, .cpp, .h,
    #             .hpp, .cs, .swift, .go, .rs, .qml, .kt, .kts, .dart, .groovy
    'slash': ('// ', '// '),
    # html-style: .html, .htm, .xml, .svg, .xhtml
    'html': ('<!-- ', ' -->'),
    # lua-style: .lua
    'lua': ('-- ', '-- '),
    # haskell-style: .hs
    'haskell': ('-- ', '-- '),
    # fortran-style: .f, .f90, .f95
    'fortran': ('! ', '! '),
    # percent-style: .tex
    'tex': ('% ', '% '),
    # semicolon-style: .asm
    'asm': ('; ', '; '),
    # no comments (plain text prepend)
    'plain': ('', ''),
}

EXTENSION_MAP = {
    # hash
    '.py': 'hash', '.pyw': 'hash', '.pyx': 'hash',
    '.rb': 'hash', '.rbw': 'hash',
    '.sh': 'hash', '.bash': 'hash', '.zsh': 'hash', '.ksh': 'hash',
    '.yaml': 'hash', '.yml': 'hash',
    '.cmake': 'hash', '.makefile': 'hash', '.mk': 'hash',
    '.txt': 'plain',
    '.env': 'hash', '.ini': 'hash', '.cfg': 'hash', '.conf': 'hash',
    '.dockerfile': 'hash',
    '.procfile': 'hash',
    '.gemfile': 'hash', '.gemspec': 'hash',
    '.rakefile': 'hash',
    '.editorconfig': 'hash',
    '.gitignore': 'hash', '.dockerignore': 'hash', '.gitattributes': 'hash',
    # slash
    '.js': 'slash', '.jsx': 'slash', '.mjs': 'slash', '.cjs': 'slash',
    '.ts': 'slash', '.tsx': 'slash', '.mts': 'slash', '.cts': 'slash',
    '.css': 'slash', '.scss': 'slash', '.less': 'slash',
    '.java': 'slash',
    '.c': 'slash', '.cpp': 'slash', '.h': 'slash', '.hpp': 'slash',
    '.cs': 'slash',
    '.swift': 'slash',
    '.go': 'slash',
    '.rs': 'slash',
    '.qml': 'slash',
    '.kt': 'slash', '.kts': 'slash',
    '.dart': 'slash',
    '.groovy': 'slash', '.gvy': 'slash',
    '.scala': 'slash',
    '.sass': 'slash',
    '.pcss': 'slash',
    # html
    '.html': 'html', '.htm': 'html',
    '.xml': 'html', '.svg': 'html', '.xhtml': 'html', '.xslt': 'html',
    '.xsd': 'html', '.xsl': 'html',
    '.csproj': 'html', '.vcxproj': 'html', '.fsproj': 'html',
    # lua
    '.lua': 'lua',
    # haskell
    '.hs': 'haskell',
    # fortran
    '.f': 'fortran', '.f90': 'fortran', '.f95': 'fortran', '.f03': 'fortran',
    # tex
    '.tex': 'tex', '.sty': 'tex', '.cls': 'tex', '.bib': 'tex',
    # asm
    '.asm': 'asm', '.s': 'asm', '.S': 'asm',
}

SHEBANG_LIKE = re.compile(r'^(#!|-\*-|// ==)')

def detect_style(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    basename = os.path.basename(filepath).lower()
    if basename in ('makefile', 'rakefile', 'gemfile', 'procfile'):
        return 'hash'
    if basename == 'dockerfile':
        return 'hash'
    return EXTENSION_MAP.get(ext, 'plain')

def read_copyright(path='cr.txt'):
    if not os.path.exists(path):
        print(f"error: {path} not found", file=sys.stderr)
        sys.exit(1)
    with open(path, encoding='utf-8') as f:
        return f.read()

def copyright_block(text, style):
    prefix, suffix = COMMENT_STYLES[style]
    lines = text.strip().splitlines()
    commented = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            commented.append(prefix.rstrip())
        elif suffix:
            # suffix after content
            commented.append(f"{prefix}{stripped}{suffix}")
        else:
            commented.append(f"{prefix}{stripped}")
    return '\n'.join(commented) + '\n'

def already_has_copyright(content, text):
    lines = content.splitlines()
    if not lines:
        return False
    first_line = lines[0].strip()
    if not first_line:
        return False
    cr_first = text.strip().splitlines()[0].strip()
    if not cr_first:
        return False
    return cr_first in first_line or first_line in cr_first

def process_file(filepath, cr_text, style, backup_dir):
    with open(filepath, encoding='utf-8') as f:
        content = f.read()

    if already_has_copyright(content, cr_text):
        print(f"skip  {filepath}")
        return

    os.makedirs(backup_dir, exist_ok=True)
    backup_path = os.path.join(backup_dir, os.path.basename(filepath))
    shutil.copy2(filepath, backup_path)

    lines = content.splitlines(keepends=True)
    insert_idx = 0
    for i, line in enumerate(lines):
        if SHEBANG_LIKE.match(line.strip()) or line.strip() == '':
            insert_idx = i + 1
        else:
            break

    block = copyright_block(cr_text, style)
    prefix = ''.join(lines[:insert_idx])
    rest = ''.join(lines[insert_idx:])
    new_content = prefix + block + '\n' + rest

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"patch {filepath}")

def main():
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <file> [file ...]", file=sys.stderr)
        sys.exit(1)

    cr_text = read_copyright()
    backup_dir = 'backup'

    for filepath in sys.argv[1:]:
        if not os.path.isfile(filepath):
            print(f"skip  {filepath} (not a file)")
            continue
        style = detect_style(filepath)
        process_file(filepath, cr_text, style, backup_dir)

if __name__ == '__main__':
    main()
