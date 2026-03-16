#!/usr/bin/env python3
"""
fix-pdf-unicode.py
Remove 4-byte (SMP) Unicode characters from a PDF file.

Targets:
  1. XMP metadata stream (uncompressed, patched in-place)
  2. ToUnicode CMap streams (FlateDecode compressed; decompressed, patched,
     recompressed, /Length updated, xref table rebuilt)

SMP characters (U+10000+) encode as 4-byte UTF-8 and are rejected by EasyChair.
They appear in pdfLaTeX/XeLaTeX/LuaLaTeX output when math fonts map italic
letters (cmmi) and script letters (cmsy) to Mathematical Alphanumeric Symbols
(U+1D400-U+1D7FF).

Usage:
    python fix-pdf-unicode.py input.pdf output.pdf
"""

import sys
import re
import zlib

# ---------------------------------------------------------------------------
# SMP codepoint -> ASCII fallback
# ---------------------------------------------------------------------------

_MATH_RANGES = [
    (0x1D400, 26, 'A'), (0x1D41A, 26, 'a'),  # Bold
    (0x1D434, 26, 'A'), (0x1D44E, 26, 'a'),  # Italic        <- most common
    (0x1D468, 26, 'A'), (0x1D482, 26, 'a'),  # Bold Italic
    (0x1D49C, 26, 'A'), (0x1D4B6, 26, 'a'),  # Script
    (0x1D4D0, 26, 'A'), (0x1D4EA, 26, 'a'),  # Bold Script
    (0x1D504, 26, 'A'), (0x1D51E, 26, 'a'),  # Fraktur
    (0x1D538, 26, 'A'), (0x1D552, 26, 'a'),  # Double-struck
    (0x1D56C, 26, 'A'), (0x1D586, 26, 'a'),  # Bold Fraktur
    (0x1D5A0, 26, 'A'), (0x1D5BA, 26, 'a'),  # Sans-serif
    (0x1D5D4, 26, 'A'), (0x1D5EE, 26, 'a'),  # Sans-serif Bold
    (0x1D608, 26, 'A'), (0x1D622, 26, 'a'),  # Sans-serif Italic
    (0x1D63C, 26, 'A'), (0x1D656, 26, 'a'),  # Sans-serif Bold Italic
    (0x1D670, 26, 'A'), (0x1D68A, 26, 'a'),  # Monospace
]

def smp_to_ascii(cp: int) -> str:
    for start, count, base in _MATH_RANGES:
        if start <= cp < start + count:
            return chr(ord(base) + (cp - start))
    if 0x1D7CE <= cp <= 0x1D7FF:
        return str((cp - 0x1D7CE) % 10)
    return '?'

# ---------------------------------------------------------------------------
# XMP metadata — in-place patch (safe; XMP packets carry whitespace padding)
# ---------------------------------------------------------------------------

def patch_xmp(data: bytearray) -> int:
    s = data.find(b'<?xpacket begin=')
    if s < 0:
        return 0
    e = data.rfind(b'<?xpacket end=')
    if e < 0:
        return 0
    end = data.find(b'?>', e)
    if end < 0:
        return 0
    end += 2

    raw = bytes(data[s:end])
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        return 0

    fixed = []
    n = 0
    for ch in text:
        if ord(ch) > 0xFFFF:
            fixed.append(smp_to_ascii(ord(ch)))
            n += 1
        else:
            fixed.append(ch)
    if not n:
        return 0

    fixed_bytes = ''.join(fixed).encode('utf-8')
    if len(fixed_bytes) > len(raw):
        print('  Warning: fixed XMP would be larger than original; skipping.')
        return 0
    # Absorb size difference with trailing spaces (XMP padding exists for this)
    fixed_bytes += b' ' * (len(raw) - len(fixed_bytes))
    data[s:end] = fixed_bytes
    return n

# ---------------------------------------------------------------------------
# ToUnicode CMap streams — decompress, patch hex destinations, recompress
# ---------------------------------------------------------------------------

# PDF CMap destination hex values.
# BMP:      <XXXX>     (4 nibbles)
# SMP raw:  <XXXXX> or <XXXXXX>   (5-6 nibbles)
# SMP UTF-16BE surrogate pair: <D8xxDCyy>  (8 nibbles)
_HEX_DEST = re.compile(rb'<([0-9A-Fa-f]{4,8})>')

def _decode_hex_dest(h: bytes) -> int:
    n = int(h, 16)
    # Detect UTF-16BE high surrogate + low surrogate
    if len(h) == 8:
        hi = (n >> 16) & 0xFFFF
        lo = n & 0xFFFF
        if 0xD800 <= hi <= 0xDBFF and 0xDC00 <= lo <= 0xDFFF:
            return 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
    return n

def patch_cmap_content(raw: bytes):
    """Return (patched_bytes, n_replaced)."""
    n = 0
    def repl(m):
        nonlocal n
        cp = _decode_hex_dest(m.group(1))
        if cp > 0xFFFF:
            n += 1
            return f'<{ord(smp_to_ascii(cp)):04X}>'.encode()
        return m.group(0)
    patched = _HEX_DEST.sub(repl, raw)
    return patched, n

_CMAP_MARKER = re.compile(rb'beginbfchar|beginbfrange|/CMapName')

def _deflate(data: bytes):
    for wbits in (15, -15, 31):
        try:
            return zlib.decompress(data, wbits)
        except zlib.error:
            pass
    return None

# ---------------------------------------------------------------------------
# PDF object / stream scanner
# ---------------------------------------------------------------------------

# Matches: <num> <gen> obj <body> endobj
_OBJ_RE = re.compile(rb'(\d+\s+\d+\s+obj\b.*?endobj)', re.DOTALL)

# Within an object body, matches: <<dict>> stream\n<data>\nendstream
_STREAM_BODY = re.compile(
    rb'(<<[\s\S]*?>>)\s*stream\r?\n([\s\S]*?)\r?\nendstream',
    re.DOTALL
)

_LENGTH_ENTRY = re.compile(rb'/Length\s+\d+')
_FILTER_ENTRY = re.compile(rb'/Filter\s*/(\w+)')


def patch_streams(pdf: bytes):
    """Scan all PDF objects, patch ToUnicode CMap streams.
    Returns (new_pdf_bytes, n_total_replacements).
    """
    result = []
    pos = 0
    total = 0
    changed = False

    for m in _OBJ_RE.finditer(pdf):
        # Copy gap before this object
        result.append(pdf[pos:m.start()])
        pos = m.end()

        obj_text = m.group(1)
        sm = _STREAM_BODY.search(obj_text)
        if sm is None:
            result.append(obj_text)
            continue

        hdr = sm.group(1)
        raw_stream = sm.group(2)

        fm = _FILTER_ENTRY.search(hdr)
        filt = fm.group(1) if fm else b''

        # Decompress
        if filt == b'FlateDecode':
            content = _deflate(raw_stream)
        elif filt == b'':
            content = raw_stream
        else:
            result.append(obj_text)
            continue

        if content is None:
            result.append(obj_text)
            continue

        # Only process ToUnicode CMap streams
        if not _CMAP_MARKER.search(content[:512]):
            result.append(obj_text)
            continue

        patched_content, n = patch_cmap_content(content)
        if n == 0:
            result.append(obj_text)
            continue

        changed = True
        total += n

        # Recompress (or keep raw)
        if filt == b'FlateDecode':
            new_stream = zlib.compress(patched_content)
        else:
            new_stream = patched_content

        # Update /Length in the header dict
        new_hdr = _LENGTH_ENTRY.sub(
            b'/Length ' + str(len(new_stream)).encode(),
            hdr
        )

        # Detect line ending
        sep = b'\r\n' if b'\r\n' in obj_text else b'\n'

        new_obj = (
            obj_text[:sm.start()]
            + new_hdr
            + b'\nstream' + sep
            + new_stream + sep
            + b'endstream'
            + obj_text[sm.end():]
        )
        result.append(new_obj)

    result.append(pdf[pos:])

    if not changed:
        return pdf, 0

    merged = b''.join(result)
    merged = rebuild_xref(merged)
    return merged, total

# ---------------------------------------------------------------------------
# Cross-reference table rebuilder (traditional xref; not xref streams)
# ---------------------------------------------------------------------------

_OBJ_HEADER = re.compile(rb'^(\d+)\s+(\d+)\s+obj\b', re.MULTILINE)
_STARTXREF   = re.compile(rb'startxref\s+\d+\s+%%EOF', re.IGNORECASE)
_TRAILER_RE  = re.compile(rb'trailer\s*(<<[\s\S]*?>>)', re.DOTALL)


def rebuild_xref(pdf: bytes) -> bytes:
    # Collect (obj_num, gen, byte_offset) for every object
    offsets: dict[int, int] = {}
    for m in _OBJ_HEADER.finditer(pdf):
        num = int(m.group(1))
        # gen = int(m.group(2))  # always 0 for new documents
        offsets[num] = m.start()

    if not offsets:
        return pdf

    max_obj = max(offsets)

    # Build xref table
    xref_pos = len(pdf.rstrip(b'\n\r '))
    xref_lines = [b'xref\n', f'0 {max_obj + 1}\n'.encode()]
    xref_lines.append(b'0000000000 65535 f \n')
    for i in range(1, max_obj + 1):
        off = offsets.get(i)
        if off is not None:
            xref_lines.append(f'{off:010d} 00000 n \n'.encode())
        else:
            xref_lines.append(b'0000000000 65535 f \n')
    xref_block = b''.join(xref_lines)

    # Preserve trailer dict; update /Size
    tm = _TRAILER_RE.search(pdf)
    if tm:
        tdict = re.sub(
            rb'/Size\s+\d+',
            f'/Size {max_obj + 1}'.encode(),
            tm.group(1)
        )
        trailer = b'trailer\n' + tdict + b'\n'
    else:
        trailer = f'trailer\n<< /Size {max_obj + 1} >>\n'.encode()

    startxref = f'startxref\n{xref_pos}\n%%EOF\n'.encode()

    # Trim old xref / startxref / %%EOF from tail
    last_xref = pdf.rfind(b'\nxref\n')
    if last_xref < 0:
        last_xref = pdf.rfind(b'\nstartxref')
    base = pdf[:last_xref].rstrip() if last_xref > 0 else pdf.rstrip()

    return base + b'\n' + xref_block + trailer + startxref

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage: python {sys.argv[0]} input.pdf output.pdf')
        sys.exit(1)

    src, dst = sys.argv[1], sys.argv[2]
    print(f'Reading {src} ...')
    with open(src, 'rb') as f:
        data = bytearray(f.read())

    # Step 1: XMP metadata (safe in-place patch)
    n_xmp = patch_xmp(data)
    print(f'XMP metadata: {"fixed " + str(n_xmp) + " SMP char(s)" if n_xmp else "nothing to fix"}')

    # Step 2: ToUnicode CMap streams
    patched, n_cmap = patch_streams(bytes(data))
    print(f'ToUnicode CMaps: {"fixed " + str(n_cmap) + " mapping(s), xref rebuilt" if n_cmap else "nothing to fix"}')

    with open(dst, 'wb') as f:
        f.write(patched)
    print(f'Written: {dst}')
    if n_xmp == 0 and n_cmap == 0:
        print('No SMP characters were found.')
        print('If EasyChair still rejects the file, the SMP chars may be in')
        print('compressed streams with non-FlateDecode filters, or in a')
        print('cross-reference stream (PDF 1.5+ format). In that case run:')
        print('  gswin64c -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=output.pdf input.pdf')
