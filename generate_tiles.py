import os
import math
from PIL import Image, ImageDraw

# Base directory for assets
base_dir = "godot_project/assets/tile_art"
os.makedirs(base_dir, exist_ok=True)

# Use a 16x16 square tile size for debugging.
tile_size = (16, 16)
grass_color = (102, 178, 51)
name = "grass"

def get_hexagon_points(center_x, center_y, size):
    """Calculates the 6 points of a flat-topped hexagon."""
    hex_points = []
    for i in range(6):
        angle_deg = 60 * i
        angle_rad = math.pi / 180 * angle_deg
        x = center_x + size * math.cos(angle_rad)
        y = center_y + size * math.sin(angle_rad)
        hex_points.append((x, y))
    return hex_points

print(f"Generating a single 16x16 grass tile in {base_dir}...")

hex_size = 7.5 # Leave a little padding
center_x, center_y = tile_size[0] / 2, tile_size[1] / 2
hex_points = get_hexagon_points(center_x, center_y, hex_size)

# Create base tile
img_base = Image.new("RGBA", tile_size, (0, 0, 0, 0)) # Transparent background
draw = ImageDraw.Draw(img_base)
draw.polygon(hex_points, fill=grass_color)
img_base.save(os.path.join(base_dir, f"{name}.png"))

print(f"  Created {name}.png")
print("Single tile generation complete.")
