#!/usr/bin/env python3
"""
Simple SVG color inverter.
Finds hex color codes (#RRGGBB or #RGB) in an SVG file and replaces them with their inverted colors.
Usage:
  python scripts/invert_svg.py assets/icons/flask.svg
This writes a new file next to the input with suffix `-inverted.svg`.
"""
import re
import sys
from pathlib import Path

HEX_RE = re.compile(r"#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\b")


def expand_hex(h: str) -> str:
    # h is either 3 or 6 hex digits
    if len(h) == 3:
        return ''.join(c*2 for c in h)
    return h


def invert_hex(hexstr: str) -> str:
    h = expand_hex(hexstr)
    r = 255 - int(h[0:2], 16)
    g = 255 - int(h[2:4], 16)
    b = 255 - int(h[4:6], 16)
    return '#{0:02X}{1:02X}{2:02X}'.format(r, g, b)


def replace_match(m: re.Match) -> str:
    hexpart = m.group(1)
    return invert_hex(hexpart)


def invert_svg(path: Path) -> Path:
    text = path.read_text()
    new_text = HEX_RE.sub(lambda m: replace_match(m), text)
    out = path.with_name(path.stem + '-inverted' + path.suffix)
    out.write_text(new_text)
    return out


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python scripts/invert_svg.py <svg-path>')
        sys.exit(1)
    p = Path(sys.argv[1])
    if not p.exists():
        print('File not found:', p)
        sys.exit(2)
    out = invert_svg(p)
    print('Wrote inverted SVG to', out)
