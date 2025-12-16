#!/usr/bin/env python3
"""
Analyze the fantasy hex tileset to understand its structure.
"""
from PIL import Image
from collections import Counter

def analyze_image(image_path):
    """Analyze the tileset image structure."""
    img = Image.open(image_path)
    width, height = img.size

    print(f"Image: {image_path}")
    print(f"Dimensions: {width}x{height}")
    print(f"Mode: {img.mode}")

    # Sample some points to understand spacing
    print("\nSampling pixel colors at different positions:")
    for y in range(0, min(height, 128), 32):
        for x in range(0, min(width, 128), 32):
            pixel = img.getpixel((x, y))
            if img.mode == 'RGBA':
                print(f"  Position ({x:3d}, {y:3d}): RGBA{pixel}")
            else:
                print(f"  Position ({x:3d}, {y:3d}): RGB{pixel}")

    return img

def find_hex_centers(image_path):
    """Try to find the centers of hexagonal tiles."""
    img = Image.open(image_path).convert('RGBA')
    width, height = img.size

    print(f"\nAnalyzing hex layout for: {image_path}")

    # For hex tiles in flat-top orientation, try different spacings
    best_centers = []
    best_h = 0
    best_v = 0

    for h_spacing in range(28, 36):
        for v_spacing in range(44, 52):  # Increased for flat-top hex
            centers = []

            for row in range(10):  # More rows to cover 288px height
                y = 24 + row * v_spacing
                if y >= height - 16:
                    break

                for col in range(10):  # More cols
                    # Offset every other row for hexagonal layout
                    offset = (h_spacing // 2) if row % 2 == 1 else 0
                    x = 16 + col * h_spacing + offset

                    if x >= width - 16:
                        continue

                    # Check if there's visible content here
                    if x < width and y < height:
                        try:
                            pixel = img.getpixel((x, y))
                            if pixel[3] > 128:  # Alpha > 128
                                centers.append((x, y, row, col))
                        except:
                            pass

            if len(centers) > len(best_centers):
                best_centers = centers
                best_h = h_spacing
                best_v = v_spacing

    if best_centers:
        return best_centers, best_h, best_v

    return None, None, None

def main():
    print("="*60)
    print("FANTASY HEX TILESET ANALYSIS")
    print("="*60)

    bordered_path = "godot_project/assets/fantasyhextiles_v3.png"

    print("\n" + "="*60)
    print("BORDERED TILESET")
    print("="*60)
    img1 = analyze_image(bordered_path)
    centers1, h_space1, v_space1 = find_hex_centers(bordered_path)

    if centers1:
        print(f"\nOptimal spacing found: h={h_space1}, v={v_space1}")
        print(f"Detected {len(centers1)} hexes")
        print("\nFirst 15 hex centers:")
        for i, (x, y, row, col) in enumerate(centers1[:15]):
            pixel = img1.getpixel((x, y))
            print(f"  Hex {i}: center at ({x:3d}, {y:3d}), grid (row={row}, col={col}), color=RGBA{pixel}")

if __name__ == "__main__":
    main()
