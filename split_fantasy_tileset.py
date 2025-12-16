#!/usr/bin/env python3
"""
Script to split fantasy hex tileset images into individual tile files.
"""
import os
from PIL import Image

# Tile dimensions (determined from the 256x288 source image)
TILE_SIZE = 32  # Each tile is 32x32 pixels
TILES_PER_ROW = 8

# Output directories
OUTPUT_DIR_BORDERED = "godot_project/assets/tile_art/fantasy_bordered"
OUTPUT_DIR_BORDERLESS = "godot_project/assets/tile_art/fantasy_borderless"

# Terrain type mapping based on visual inspection of the tileset
# This maps grid position (row, col) to terrain type name
# These must match the TERRAIN_NAMES in world_map.gd:
# 0: water, 1: sand, 2: grass, 3: forest, 4: hills,
# 5: stone, 6: mountains, 7: deep_sea, 8: chasm, 9: lava,
# 10: snow_peak, 11: ice_water, 12: cold_water, 13: jungle,
# 14: dry_grassland, 15: rocky_peak
TILE_MAPPING = {
    # Row 0 (top row) - Various grass, forest, mountains, water
    (0, 0): "grass",           # Light green hex
    (0, 1): "grass",           # Grass with flowers
    (0, 2): "grass",           # Grass variant
    (0, 3): "grass",           # Light grass
    (0, 4): "forest",          # Dense forest
    (0, 5): "forest",          # Forest with snow
    (0, 6): "mountains",       # Grey mountain
    (0, 7): "water",           # Light blue water

    # Row 1 - Villages, settlements, and terrain
    (1, 0): "hills",           # Village on hills
    (1, 1): "hills",           # Settlement variant
    (1, 2): "stone",           # Rocky village
    (1, 3): "sand",            # Desert settlement
    (1, 4): "forest",          # Forest settlement
    (1, 5): "grass",           # Grass village
    (1, 6): "grass",           # Grass variant
    (1, 7): "forest",          # Forest variant

    # Row 2 - Ice, snow, and water variants
    (2, 0): "ice_water",       # Frozen water
    (2, 1): "cold_water",      # Ice chunks
    (2, 2): "cold_water",      # Cold water variant
    (2, 3): "snow_peak",       # Snowy mountain
    (2, 4): "snow_peak",       # Snow forest
    (2, 5): "water",           # Water variant
    (2, 6): "water",           # Settlement on water
    (2, 7): "deep_sea",        # Dark blue water

    # Row 3 - Desert and tropical terrain
    (3, 0): "sand",            # Light sand
    (3, 1): "sand",            # Sand with cacti
    (3, 2): "sand",            # Brown sand
    (3, 3): "dry_grassland",   # Dry grass/savanna
    (3, 4): "jungle",          # Tropical jungle
    (3, 5): "sand",            # Desert variant
    (3, 6): "sand",            # Desert settlement
    (3, 7): "sand",            # Sand village

    # Row 4 - Small objects and terrain details
    (4, 0): "forest",          # Dense forest cluster
    (4, 1): "forest",          # Small forest
    (4, 2): "water",           # Water puddle
    (4, 3): "stone",           # Rock cluster
    (4, 4): "water",           # Water settlement
    (4, 5): "water",           # Boat/dock
    (4, 6): "grass",           # Grass patch
    (4, 7): "forest",          # Forest patch

    # Row 5 - Special terrain
    (5, 0): "rocky_peak",      # Rocky mountain
}

def create_output_dirs():
    """Create output directories if they don't exist."""
    os.makedirs(OUTPUT_DIR_BORDERED, exist_ok=True)
    os.makedirs(OUTPUT_DIR_BORDERLESS, exist_ok=True)
    print(f"Created output directories:")
    print(f"  - {OUTPUT_DIR_BORDERED}")
    print(f"  - {OUTPUT_DIR_BORDERLESS}")

def split_tileset(input_path, output_dir, tileset_name):
    """Split a tileset image into individual tiles."""
    print(f"\nProcessing {tileset_name}...")

    # Load the image
    img = Image.open(input_path)
    img_width, img_height = img.size

    print(f"  Image size: {img_width}x{img_height}")

    tiles_extracted = 0
    terrain_counters = {}  # Track how many of each terrain type we've saved

    # Extract tiles (9 rows total based on 288px height / 32px tiles)
    max_rows = img_height // TILE_SIZE
    for row in range(max_rows):
        for col in range(TILES_PER_ROW):
            # Calculate position
            x = col * TILE_SIZE
            y = row * TILE_SIZE

            # Skip if position is out of bounds
            if y + TILE_SIZE > img_height or x + TILE_SIZE > img_width:
                continue

            # Skip if no mapping exists for this tile
            if (row, col) not in TILE_MAPPING:
                continue

            # Extract tile
            tile_box = (x, y, x + TILE_SIZE, y + TILE_SIZE)
            tile = img.crop(tile_box)

            # Get base terrain name from mapping
            base_name = TILE_MAPPING.get((row, col))

            # Track variants of the same terrain type
            if base_name in terrain_counters:
                terrain_counters[base_name] += 1
                tile_name = f"{base_name}_{terrain_counters[base_name]}"
            else:
                terrain_counters[base_name] = 0
                tile_name = base_name

            # Save tile
            output_path = os.path.join(output_dir, f"{tile_name}.png")
            tile.save(output_path)
            tiles_extracted += 1
            print(f"    Saved: {tile_name}.png (row {row}, col {col})")

    print(f"  Extracted {tiles_extracted} tiles to {output_dir}")
    print(f"  Terrain types covered: {sorted(set(TILE_MAPPING.values()))}")
    return tiles_extracted

def main():
    """Main function to split both tilesets."""
    print("Fantasy Hex Tileset Splitter")
    print("=" * 50)

    # Create output directories
    create_output_dirs()

    # Split bordered tileset
    bordered_input = "godot_project/assets/fantasyhextiles_v3.png"
    if os.path.exists(bordered_input):
        split_tileset(bordered_input, OUTPUT_DIR_BORDERED, "Bordered Tileset")
    else:
        print(f"Warning: {bordered_input} not found!")

    # Split borderless tileset
    borderless_input = "godot_project/assets/fantasyhextiles_v3_borderless.png"
    if os.path.exists(borderless_input):
        split_tileset(borderless_input, OUTPUT_DIR_BORDERLESS, "Borderless Tileset")
    else:
        print(f"Warning: {borderless_input} not found!")

    print("\n" + "=" * 50)
    print("Tileset splitting complete!")
    print("\nNext steps:")
    print("1. Review the extracted tiles in the output directories")
    print("2. Update the terrain mapping if needed")
    print("3. Integrate with the game's tile system")

if __name__ == "__main__":
    main()
