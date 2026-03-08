#!/usr/bin/env python3
"""Convert a PNG image to SNES 4bpp tile data, palette, and tilemap.

Handles the full pipeline:
1. Snap colors to BGR555 space
2. Per-tile color reduction (max 16 per tile)
3. Greedy palette assignment (8 sub-palettes of 16 colors)
4. Tile encoding (4bpp planar format)
5. Tilemap encoding (tile index + palette + flip flags)
6. Tile deduplication with horizontal/vertical flip detection

Output files:
  .pal   - 256 bytes (8 palettes * 16 colors * 2 bytes BGR555)
  .tiles - N * 32 bytes (4bpp 8x8 tiles)
  .map   - W/8 * H/8 * 2 bytes (tilemap entries, little-endian)
"""

import sys
import struct
from PIL import Image
from collections import Counter

def rgb_to_bgr555(r, g, b):
    return ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)

def bgr555_to_rgb(c):
    return ((c & 0x1F) << 3, ((c >> 5) & 0x1F) << 3, ((c >> 10) & 0x1F) << 3)

def snap_pixel(r, g, b):
    """Snap to SNES 5-bit color space."""
    return bgr555_to_rgb(rgb_to_bgr555(r, g, b))

def get_tile_pixels(pixels, tx, ty):
    """Get 8x8 tile as list of (r,g,b) tuples."""
    tile = []
    for py in range(8):
        row = []
        for px in range(8):
            row.append(pixels[tx*8+px, ty*8+py])
        tile.append(row)
    return tile

def quantize_tile_colors(tile, max_colors=16):
    """Reduce a tile to at most max_colors unique colors using median cut."""
    from PIL import Image as PILImage
    # Create tiny 8x8 image
    img = PILImage.new('RGB', (8, 8))
    px = img.load()
    for y in range(8):
        for x in range(8):
            px[x, y] = tile[y][x]
    colors = set()
    for y in range(8):
        for x in range(8):
            colors.add(tile[y][x])
    if len(colors) <= max_colors:
        return tile  # Already fine

    q = img.quantize(colors=max_colors, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.NONE).convert('RGB')
    qpx = q.load()
    result = []
    for y in range(8):
        row = []
        for x in range(8):
            r, g, b = qpx[x, y]
            row.append(snap_pixel(r, g, b))
        result.append(row)
    return result

def tile_colors(tile):
    """Get set of unique colors in a tile."""
    colors = set()
    for row in tile:
        for c in row:
            colors.add(c)
    return colors

def color_distance_sq(c1, c2):
    return sum((a - b) ** 2 for a, b in zip(c1, c2))

def nearest_color(color, palette):
    """Find nearest color in palette."""
    best = None
    best_d = float('inf')
    for pc in palette:
        d = color_distance_sq(color, pc)
        if d < best_d:
            best_d = d
            best = pc
    return best

def assign_palettes(tiles_data, num_palettes=8, colors_per_pal=16):
    """Assign tiles to sub-palettes using greedy bin-packing with refinement.
    Tries multiple orderings and picks the one with fewest remapped tiles."""
    import random
    tile_color_sets = [tile_colors(t) for t in tiles_data]

    # Try multiple orderings, keep the best result
    orderings = [
        sorted(range(len(tiles_data)),
               key=lambda i: len(tile_color_sets[i]), reverse=True),  # most constrained
        list(range(len(tiles_data))),  # spatial (top-left to bottom-right)
        sorted(range(len(tiles_data)),
               key=lambda i: len(tile_color_sets[i])),  # least constrained first
    ]
    # Add randomized orderings
    rng = random.Random(42)
    for _ in range(20):
        order = list(range(len(tiles_data)))
        rng.shuffle(order)
        orderings.append(order)

    best_remaps = float('inf')
    best_assignments = None
    best_palettes = None

    for order in orderings:
        palettes = [set() for _ in range(num_palettes)]
        assignments = [None] * len(tiles_data)
        remaps = 0

        for ti in order:
            tc = tile_color_sets[ti]
            best_pal = None
            best_new_colors = float('inf')

            for pi in range(num_palettes):
                new_colors = len(tc - palettes[pi])
                total = len(palettes[pi]) + new_colors
                if total <= colors_per_pal:
                    if new_colors < best_new_colors:
                        best_new_colors = new_colors
                        best_pal = pi

            if best_pal is not None:
                palettes[best_pal] |= tc
                assignments[ti] = best_pal
            else:
                remaps += 1
                best_pal = 0
                best_overlap = -1
                for pi in range(num_palettes):
                    overlap = len(tc & palettes[pi])
                    if overlap > best_overlap:
                        best_overlap = overlap
                        best_pal = pi
                assignments[ti] = best_pal

        if remaps < best_remaps:
            best_remaps = remaps
            best_assignments = assignments[:]
            best_palettes = [s.copy() for s in palettes]
            if remaps == 0:
                break

    print(f"  Best ordering: {best_remaps} remapped tiles")
    assignments = best_assignments
    palettes = best_palettes

    # Apply remapping for tiles that couldn't fit
    if best_remaps > 0:
        for ti in range(len(tiles_data)):
            tc = tile_color_sets[ti]
            pi = assignments[ti]
            if not tc.issubset(palettes[pi]):
                pal_colors = list(palettes[pi])
                remapped_tile = []
                for row in tiles_data[ti]:
                    new_row = []
                    for c in row:
                        if c in palettes[pi]:
                            new_row.append(c)
                        else:
                            new_row.append(nearest_color(c, pal_colors))
                    remapped_tile.append(new_row)
                tiles_data[ti] = remapped_tile

    # --- Refinement pass: fix tiles where ANY color was lost ---
    refine_count = 0
    for ti in range(len(tiles_data)):
        tc = tile_color_sets[ti]  # Original colors
        pi = assignments[ti]
        lost = tc - palettes[pi]
        if not lost:
            continue

        # Try to find a palette that contains ALL this tile's colors
        for cpi in range(num_palettes):
            new_colors = len(tc - palettes[cpi])
            if len(palettes[cpi]) + new_colors <= colors_per_pal:
                palettes[cpi] |= tc
                assignments[ti] = cpi
                refine_count += 1
                break

    if refine_count > 0:
        print(f"  Refinement: {refine_count} tiles reassigned to preserve colors")

    return assignments, palettes

def encode_tile_4bpp(tile, palette_list):
    """Encode 8x8 tile as 32 bytes of 4bpp planar data.
    palette_list: ordered list of colors, index 0 = color 0.
    """
    # Build color-to-index map
    color_to_idx = {}
    for i, c in enumerate(palette_list):
        color_to_idx[c] = i

    # 4bpp format: bp0+bp1 interleaved (16 bytes), then bp2+bp3 (16 bytes)
    planes = [[], [], [], []]  # 4 bitplanes
    for y in range(8):
        bp = [0, 0, 0, 0]
        for x in range(8):
            color = tile[y][x]
            idx = color_to_idx.get(color, 0)
            bit = 7 - x
            for p in range(4):
                if idx & (1 << p):
                    bp[p] |= (1 << bit)
        for p in range(4):
            planes[p].append(bp[p])

    # Interleave: bp0[0],bp1[0], bp0[1],bp1[1], ... bp2[0],bp3[0], ...
    data = bytearray()
    for y in range(8):
        data.append(planes[0][y])
        data.append(planes[1][y])
    for y in range(8):
        data.append(planes[2][y])
        data.append(planes[3][y])
    return bytes(data)

def flip_tile_h(tile):
    return [list(reversed(row)) for row in tile]

def flip_tile_v(tile):
    return list(reversed(tile))

def tiles_equal(t1, t2):
    for y in range(8):
        for x in range(8):
            if t1[y][x] != t2[y][x]:
                return False
    return True

def convert(input_path, out_pal, out_tiles, out_map, num_palettes=8):
    img = Image.open(input_path).convert('RGB')
    w, h = img.size
    assert w % 8 == 0 and h % 8 == 0, f"Image must be multiple of 8x8 ({w}x{h})"

    tiles_x = w // 8
    tiles_y = h // 8
    pixels = img.load()

    print(f"  Image: {w}x{h} ({tiles_x}x{tiles_y} tiles)")

    # Step 1: Snap all pixels to SNES color space
    for y in range(h):
        for x in range(w):
            pixels[x, y] = snap_pixel(*pixels[x, y])

    unique_colors = set()
    for y in range(h):
        for x in range(w):
            unique_colors.add(pixels[x, y])
    print(f"  After SNES snap: {len(unique_colors)} unique colors")

    # Step 2: Extract and quantize each tile to <=16 colors
    tiles = []
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            tile = get_tile_pixels(pixels, tx, ty)
            tile = quantize_tile_colors(tile, 16)
            tiles.append(tile)

    print(f"  Tiles: {len(tiles)} total")

    # Step 3: Assign tiles to palettes
    assignments, palettes = assign_palettes(tiles, num_palettes, 16)

    # Report palette usage
    for i, pal in enumerate(palettes):
        if pal:
            print(f"  Palette {i}: {len(pal)} colors")

    # Step 4: Build ordered palette lists (pad to 16 colors each)
    palette_lists = []
    for pal_set in palettes:
        pal_list = sorted(pal_set, key=lambda c: rgb_to_bgr555(*c))
        while len(pal_list) < 16:
            pal_list.append((0, 0, 0))
        palette_lists.append(pal_list)

    # Step 5: Deduplicate tiles (with flip detection)
    unique_tiles = []  # list of (encoded_bytes, tile_pixel_data, palette_idx)
    tile_map = []  # per-tile: (unique_idx, h_flip, v_flip, palette)

    for i, tile in enumerate(tiles):
        pal_idx = assignments[i]
        pal_list = palette_lists[pal_idx]

        # Try all flip combinations against existing unique tiles
        found = False
        for ui, (uenc, upix, upal) in enumerate(unique_tiles):
            if upal != pal_idx:
                continue
            # No flip
            if tiles_equal(tile, upix):
                tile_map.append((ui, False, False, pal_idx))
                found = True
                break
            # H flip
            if tiles_equal(tile, flip_tile_h(upix)):
                tile_map.append((ui, True, False, pal_idx))
                found = True
                break
            # V flip
            if tiles_equal(tile, flip_tile_v(upix)):
                tile_map.append((ui, False, True, pal_idx))
                found = True
                break
            # HV flip
            if tiles_equal(tile, flip_tile_h(flip_tile_v(upix))):
                tile_map.append((ui, True, True, pal_idx))
                found = True
                break

        if not found:
            ui = len(unique_tiles)
            encoded = encode_tile_4bpp(tile, pal_list)
            unique_tiles.append((encoded, tile, pal_idx))
            tile_map.append((ui, False, False, pal_idx))

    print(f"  Unique tiles: {len(unique_tiles)} (after dedup+flip)")

    if len(unique_tiles) > 512:
        print(f"  WARNING: {len(unique_tiles)} tiles exceeds BG2 chr space (512 max)")

    # Step 6: Write palette file (256 bytes = 8 * 16 * 2)
    pal_data = bytearray()
    for pal_list in palette_lists:
        for color in pal_list:
            pal_data += struct.pack('<H', rgb_to_bgr555(*color))
    with open(out_pal, 'wb') as f:
        f.write(pal_data)
    print(f"  Palette: {len(pal_data)} bytes -> {out_pal}")

    # Step 7: Write tile data
    tile_data = bytearray()
    for encoded, _, _ in unique_tiles:
        tile_data += encoded
    with open(out_tiles, 'wb') as f:
        f.write(tile_data)
    print(f"  Tiles: {len(tile_data)} bytes ({len(unique_tiles)} tiles) -> {out_tiles}")

    # Step 8: Write tilemap (2 bytes per entry, little-endian)
    # Format: cccccccc VHOPPPcc  (10-bit tile#, PPP=palette, H=hflip, V=vflip, O=priority)
    map_data = bytearray()
    for entry in tile_map:
        ui, hf, vf, pal = entry
        lo = ui & 0xFF
        hi = (ui >> 8) & 0x03
        hi |= (pal & 0x07) << 2  # PPP
        if hf:
            hi |= 0x40
        if vf:
            hi |= 0x80
        map_data += bytes([lo, hi])
    with open(out_map, 'wb') as f:
        f.write(map_data)
    print(f"  Map: {len(map_data)} bytes -> {out_map}")

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} input.png out.pal out.tiles out.map [num_palettes]")
        sys.exit(1)
    np = int(sys.argv[5]) if len(sys.argv) > 5 else 8
    convert(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], np)
