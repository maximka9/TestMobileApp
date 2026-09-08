"""Offline cleanup of the approved two-cell SASAVOT reference sheet.

Only border-connected neutral checkerboard pixels become transparent. Face,
eyes and clothing pixels enclosed by the silhouette are preserved. No runtime
masking or shader is involved. Pillow is a developer-only dependency.
"""
import argparse
from collections import deque
from pathlib import Path
from PIL import Image


def prepare(source, output):
    sheet = Image.open(source).convert("RGBA")
    width, height = sheet.size
    if width != height * 2:
        raise ValueError("Expected two square cells")
    pixels = sheet.load()
    visited = bytearray(width * height)
    queue = deque()

    def visit(x, y):
        index = y * width + x
        if visited[index]:
            return
        visited[index] = 1
        red, green, blue, _ = pixels[x, y]
        if min(red, green, blue) >= 165 and max(red, green, blue) - min(red, green, blue) <= 18:
            pixels[x, y] = (0, 0, 0, 0)
            queue.append((x, y))

    for x in range(width):
        visit(x, 0)
        visit(x, height - 1)
    for y in range(height):
        visit(0, y)
        visit(width - 1, y)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                visit(nx, ny)
    result = sheet.resize((256, 128), Image.Resampling.NEAREST)
    if result.getextrema()[3] != (0, 255):
        raise ValueError("Transparent and opaque pixels required")
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    result.save(output, optimize=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("output")
    args = parser.parse_args()
    prepare(args.source, args.output)
