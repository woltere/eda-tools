#!/usr/bin/env python3

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert a flat binary to a 32-bit little-endian memory hex file.")
    parser.add_argument("binary", type=Path)
    parser.add_argument("hexfile", type=Path)
    parser.add_argument("--size", type=int, default=65536, help="RAM size in bytes")
    args = parser.parse_args()

    blob = args.binary.read_bytes()
    if len(blob) > args.size:
        raise SystemExit(f"binary size {len(blob)} exceeds RAM size {args.size}")

    padded = blob + bytes(args.size - len(blob))
    words = [int.from_bytes(padded[i:i + 4], "little") for i in range(0, len(padded), 4)]
    args.hexfile.parent.mkdir(parents=True, exist_ok=True)
    args.hexfile.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
