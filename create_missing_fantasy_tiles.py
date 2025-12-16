#!/usr/bin/env python3
"""
Create missing fantasy tiles for both bordered and borderless variants.
"""
import os
from PIL import Image, ImageDraw

TILE_SIZE = 16  # Changed to 16x16

def create_chasm_tile(output_path):
    """Create a chasm tile - dark with purple/black tones."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark purple/black base
    base_color = (20, 10, 30, 255)
    img.paste(base_color, (0, 0, TILE_SIZE, TILE_SIZE))

    # Add some darker spots for depth
    for i in range(5):
        x = (i * 7) % TILE_SIZE
        y = (i * 11) % TILE_SIZE
        radius = 3 + (i % 3)
        draw.ellipse(
            [x - radius, y - radius, x + radius, y + radius],
            fill=(10, 5, 15, 255)
        )

    img.save(output_path)
    print(f"Created chasm tile: {output_path}")

def create_lava_tile(output_path):
    """Create a lava tile - bright orange/red."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))

    # Create lava pattern with oranges and reds
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            # Create a wavy lava pattern
            wave = ((x + y) % 8) / 8.0
            if (x * y) % 7 < 3:
                # Bright orange
                color = (255, int(140 + wave * 40), 0, 255)
            else:
                # Dark red
                color = (int(180 + wave * 50), int(30 + wave * 20), 0, 255)
            img.putpixel((x, y), color)

    img.save(output_path)
    print(f"Created lava tile: {output_path}")

def create_cold_water_tile(output_path):
    """Create a cold water tile - medium blue."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))

    # Medium blue water color
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            # Add some variation
            var = ((x + y) % 4) * 5
            img.putpixel((x, y), (50 + var, 120 + var, 180 + var, 255))

    img.save(output_path)
    print(f"Created cold_water tile: {output_path}")

def create_dry_grassland_tile(output_path):
    """Create a dry grassland tile - yellowish grass."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))

    # Yellowish grass color
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            var = ((x * y) % 3) * 8
            img.putpixel((x, y), (160 + var, 150 + var, 70, 255))

    img.save(output_path)
    print(f"Created dry_grassland tile: {output_path}")

def create_jungle_tile(output_path):
    """Create a jungle tile - very dark green."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))

    # Dark jungle green
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            var = ((x + y) % 5) * 4
            img.putpixel((x, y), (20 + var, 80 + var, 30 + var, 255))

    img.save(output_path)
    print(f"Created jungle tile: {output_path}")

def create_snow_peak_tile(output_path):
    """Create a snow peak tile - white with slight blue tint."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))

    # White with blue tint
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            var = ((x + y) % 3) * 3
            img.putpixel((x, y), (230 + var, 235 + var, 245 + var, 255))

    img.save(output_path)
    print(f"Created snow_peak tile: {output_path}")

def main():
    """Create missing fantasy tiles."""
    print("Creating missing fantasy tiles...")

    # Create tiles for both bordered and borderless versions
    for style in ["fantasy_bordered", "fantasy_borderless"]:
        output_dir = f"godot_project/assets/tile_art/{style}"

        if not os.path.exists(output_dir):
            print(f"Warning: Directory {output_dir} does not exist!")
            continue

        print(f"\nCreating tiles for {style}:")

        # Create chasm tile
        chasm_path = os.path.join(output_dir, "chasm.png")
        create_chasm_tile(chasm_path)

        # Create lava tile
        lava_path = os.path.join(output_dir, "lava.png")
        create_lava_tile(lava_path)

        # Create cold_water tile (if doesn't exist)
        cold_water_path = os.path.join(output_dir, "cold_water.png")
        if not os.path.exists(cold_water_path):
            create_cold_water_tile(cold_water_path)

        # Create dry_grassland tile (if doesn't exist)
        dry_grassland_path = os.path.join(output_dir, "dry_grassland.png")
        if not os.path.exists(dry_grassland_path):
            create_dry_grassland_tile(dry_grassland_path)

        # Create jungle tile (if doesn't exist)
        jungle_path = os.path.join(output_dir, "jungle.png")
        if not os.path.exists(jungle_path):
            create_jungle_tile(jungle_path)

        # Create snow_peak tile (if doesn't exist)
        snow_peak_path = os.path.join(output_dir, "snow_peak.png")
        if not os.path.exists(snow_peak_path):
            create_snow_peak_tile(snow_peak_path)

    print("\nMissing tiles created successfully!")

if __name__ == "__main__":
    main()
