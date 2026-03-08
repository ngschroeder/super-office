#!/usr/bin/env python3
"""Quantize an image for SNES 4bpp tile conversion.

Two-pass approach:
1. Quantize globally to fit within N palettes * 16 colors
2. Then ensure each 8x8 tile fits within 16 colors
"""

import sys
from PIL import Image

def snap_to_snes(r, g, b):
    """Snap RGB to SNES 5-bit color space (3-bit truncation)."""
    r5 = (r >> 3) << 3
    g5 = (g >> 3) << 3
    b5 = (b >> 3) << 3
    return (r5, g5, b5)

def quantize_for_snes(input_path, output_path, num_palettes=8):
    img = Image.open(input_path).convert('RGB')
    w, h = img.size
    colors_per_palette = 16
    # Reserve 1 color per palette for transparency (color 0)
    # Total usable colors across all palettes
    total_colors = num_palettes * (colors_per_palette - 1) + 1  # ~113

    print(f"  Target: {num_palettes} palettes, {total_colors} total colors")

    # Aggressive quantize to total_colors
    quantized = img.quantize(colors=total_colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    img_q = quantized.convert('RGB')
    pixels = img_q.load()

    # Snap to SNES color space
    for y in range(h):
        for x in range(w):
            pixels[x, y] = snap_to_snes(*pixels[x, y])

    # Fix tiles that still have >16 colors after snapping
    tiles_x = w // 8
    tiles_y = h // 8
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            colors = set()
            for py in range(8):
                for px in range(8):
                    colors.add(pixels[tx*8+px, ty*8+py])
            if len(colors) > colors_per_palette:
                tile_img = img_q.crop((tx*8, ty*8, tx*8+8, ty*8+8))
                tile_q = tile_img.quantize(colors=colors_per_palette,
                    method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
                tile_rgb = tile_q.convert('RGB')
                tile_px = tile_rgb.load()
                for py in range(8):
                    for px in range(8):
                        pixels[tx*8+px, ty*8+py] = snap_to_snes(*tile_px[px, py])

    # Report stats
    all_colors = set()
    max_tile_colors = 0
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            colors = set()
            for py in range(8):
                for px in range(8):
                    c = pixels[tx*8+px, ty*8+py]
                    colors.add(c)
                    all_colors.add(c)
            max_tile_colors = max(max_tile_colors, len(colors))

    print(f"  Total unique colors: {len(all_colors)}")
    print(f"  Max colors per tile: {max_tile_colors}")

    img_q.save(output_path)
    print(f"  Saved to {output_path}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} input.png output.png [num_palettes]")
        sys.exit(1)
    num_pal = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    quantize_for_snes(sys.argv[1], sys.argv[2], num_palettes=num_pal)
