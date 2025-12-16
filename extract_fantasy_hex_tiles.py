#!/usr/bin/env python3
"""
Extract fantasy hex tiles with proper positioning and color-based terrain detection.
"""
from PIL import Image
from collections import Counter
import os

# Terrain classification based on center pixel color
def classify_terrain_by_color(center_pixel):
    """Classify terrain type based on the center pixel color."""
    r, g, b, a = center_pixel

    # If mostly transparent, skip
    if a < 128:
        return None

    # Classify based on color ranges (tuned to the actual tileset colors)

    # Bright green -> grass (RGB around 105, 193, 39 or 183, 204, 106)
    if g > 150 and g > r * 1.3 and g > b * 1.3:
        return "grass"

    # Medium/dark green -> forest (RGB around 39, 130, 25 or 23, 128, 65 or 41, 148, 95)
    if 20 < g < 160 and g > r and g > b and b < 100:
        return "forest"

    # Blue variants -> water
    if b > g and b > r:
        if b > 200 and r > 180:  # Very light blue -> ice/snow water (208, 236, 247)
            return "ice_water"
        elif b > 150:  # Light blue -> water (24, 174, 228)
            return "water"
        elif b > 100:  # Medium blue -> cold water
            return "cold_water"
        else:  # Dark blue -> deep sea (11, 88, 158)
            return "deep_sea"

    # Orange/yellow -> sand (246, 157, 2)
    if r > 200 and 100 < g < 200 and b < 50:
        return "sand"

    # Brown -> hills (79, 34, 13)
    if r > 50 and r < 150 and g < 80 and b < 50:
        return "hills"

    # Gray -> stone/mountains (58, 63, 66 or 135, 154, 146)
    if abs(r - g) < 30 and abs(g - b) < 30:
        if r > 180:  # Very light gray/white -> snow
            return "snow_peak"
        elif r > 100:  # Medium gray -> mountains
            return "mountains"
        else:  # Dark gray -> stone
            return "stone"

    # Yellowish green -> dry grassland
    if r > 100 and g > 100 and b < 80 and abs(r - g) < 50:
        return "dry_grassland"

    # Default to rocky_peak for anything else
    return "rocky_peak"

def extract_hex_tiles(image_path, output_dir, h_spacing=31, v_spacing=51):
    """Extract individual hex tiles from the tileset."""
    print(f"\nExtracting hex tiles from: {image_path}")
    img = Image.open(image_path).convert('RGBA')
    width, height = img.size

    os.makedirs(output_dir, exist_ok=True)

    # Hex extraction parameters
    hex_width = 30  # Width to extract around center
    hex_height = 52  # Height to extract around center
    output_size = 16  # Final size

    extracted = 0
    terrain_counts = Counter()

    # Extract hexes based on grid layout
    for row in range(10):
        y = 24 + row * v_spacing
        if y >= height - hex_height//2:
            break

        for col in range(10):
            # Offset every other row for hexagonal layout
            offset = (h_spacing // 2) if row % 2 == 1 else 0
            x = 16 + col * h_spacing + offset

            if x >= width - hex_width//2:
                continue

            # Check if there's content at this position
            if x < width and y < height:
                try:
                    pixel = img.getpixel((x, y))
                    if pixel[3] < 128:  # Skip if mostly transparent
                        continue
                except:
                    continue

                # Extract hex tile area
                left = max(0, x - hex_width//2)
                top = max(0, y - hex_height//2)
                right = min(width, x + hex_width//2)
                bottom = min(height, y + hex_height//2)

                hex_img = img.crop((left, top, right, bottom))

                # Classify terrain by center pixel color
                center_pixel = img.getpixel((x, y))
                terrain_type = classify_terrain_by_color(center_pixel)

                if terrain_type is None:
                    continue

                terrain_counts[terrain_type] += 1

                # Create filename with variant number
                count = terrain_counts[terrain_type] - 1
                if count == 0:
                    filename = f"{terrain_type}.png"
                else:
                    filename = f"{terrain_type}_{count}.png"

                # Resize to 16x16
                resized = hex_img.resize((output_size, output_size), Image.Resampling.LANCZOS)

                # Save
                output_path = os.path.join(output_dir, filename)
                resized.save(output_path)

                extracted += 1
                r, g, b, a = center_pixel
                print(f"  [{extracted:2d}] ({row}, {col}): {filename:25s} RGB({r:3d},{g:3d},{b:3d})")

    print(f"\nExtraction complete: {extracted} tiles")
    print(f"Terrain types found: {dict(terrain_counts)}")
    return extracted

def main():
    print("="*70)
    print("FANTASY HEX TILE EXTRACTOR WITH COLOR DETECTION")
    print("="*70)

    bordered_input = "godot_project/assets/fantasyhextiles_v3.png"
    borderless_input = "godot_project/assets/fantasyhextiles_v3_borderless.png"

    bordered_output = "godot_project/assets/tile_art/fantasy_bordered"
    borderless_output = "godot_project/assets/tile_art/fantasy_borderless"

    # Clear old extracted tiles
    for output_dir in [bordered_output, borderless_output]:
        if os.path.exists(output_dir):
            for file in os.listdir(output_dir):
                if file.endswith('.png'):
                    os.remove(os.path.join(output_dir, file))
            print(f"Cleared old tiles from {output_dir}")

    # Extract bordered tileset
    if os.path.exists(bordered_input):
        extract_hex_tiles(bordered_input, bordered_output)

    print("\n" + "="*70)

    # Extract borderless tileset
    if os.path.exists(borderless_input):
        extract_hex_tiles(borderless_input, borderless_output)

    print("\n" + "="*70)
    print("All tiles extracted and resized to 16x16!")
    print("=" * 70)

if __name__ == "__main__":
    main()
