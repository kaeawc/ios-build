#!/usr/bin/env python3
"""Drops the alpha channel from 8-bit RGBA PNGs in place (standard library only).

App Store Connect rejects app icons whose opaque layers carry an alpha channel, and rsvg-convert
always writes RGBA. Usage: python3 flatten_png.py <file.png>...
"""

import struct
import sys
import zlib

SIGNATURE = b"\x89PNG\r\n\x1a\n"


def chunks(data):
    pos = len(SIGNATURE)
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        kind = data[pos + 4 : pos + 8]
        yield kind, data[pos + 8 : pos + 8 + length]
        pos += 12 + length


def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def unfilter(raw, width, height, bpp):
    stride = width * bpp
    rows, prev, pos = [], bytearray(stride), 0
    for _ in range(height):
        kind, line = raw[pos], bytearray(raw[pos + 1 : pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            left = line[i - bpp] if i >= bpp else 0
            up = prev[i]
            if kind == 1:
                line[i] = (line[i] + left) & 0xFF
            elif kind == 2:
                line[i] = (line[i] + up) & 0xFF
            elif kind == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
            elif kind == 4:
                upper_left = prev[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + paeth(left, up, upper_left)) & 0xFF
        rows.append(line)
        prev = line
    return rows


def flatten(path):
    with open(path, "rb") as file:
        data = file.read()
    if not data.startswith(SIGNATURE):
        sys.exit(f"{path}: not a PNG")
    header, idat = None, b""
    for kind, body in chunks(data):
        if kind == b"IHDR":
            header = body
        elif kind == b"IDAT":
            idat += body
    width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", header)
    if color == 2:
        return  # already RGB
    if (depth, color, interlace) != (8, 6, 0):
        sys.exit(f"{path}: expected a non-interlaced 8-bit RGBA PNG")
    rows = unfilter(zlib.decompress(idat), width, height, 4)
    rgb = b"".join(b"\x00" + bytes(row[i] for i in range(len(row)) if i % 4 != 3) for row in rows)
    out = SIGNATURE
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(rgb, 9))
    out += chunk(b"IEND", b"")
    with open(path, "wb") as file:
        file.write(out)


if __name__ == "__main__":
    for png in sys.argv[1:]:
        flatten(png)
