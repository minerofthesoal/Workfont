#!/usr/bin/env python3
"""
GlyphCrafter App Icon Generator

Generates a 1024x1024 PNG app icon for GlyphCrafter.
The icon features a stylized calligraphy pen nib drawing the letter 'G'
on a gradient background, symbolizing hand-crafted font creation.

Usage:
    python3 generate_app_icon.py
    python3 generate_app_icon.py --output path/to/icon.png
    python3 generate_app_icon.py --svg  # Output SVG string instead

Requirements:
    pip install Pillow  (for PNG output)
    No dependencies needed for SVG output.
"""

import argparse
import math
import sys

# SVG icon definition
APP_ICON_SVG = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6271F9"/>
      <stop offset="50%" style="stop-color:#7B71F9"/>
      <stop offset="100%" style="stop-color:#9B8AFB"/>
    </linearGradient>
    <linearGradient id="penGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FFFFFF;stop-opacity:0.95"/>
      <stop offset="100%" style="stop-color:#E8E8F0;stop-opacity:0.9"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="4" stdDeviation="8" flood-opacity="0.3"/>
    </filter>
    <filter id="innerGlow">
      <feGaussianBlur stdDeviation="3" result="blur"/>
      <feComposite in="SourceGraphic" in2="blur" operator="over"/>
    </filter>
  </defs>

  <!-- Background rounded square -->
  <rect width="1024" height="1024" rx="224" ry="224" fill="url(#bg)"/>

  <!-- Subtle grid pattern (representing glyph grid) -->
  <g opacity="0.08" stroke="white" stroke-width="1">
    <line x1="256" y1="0" x2="256" y2="1024"/>
    <line x1="512" y1="0" x2="512" y2="1024"/>
    <line x1="768" y1="0" x2="768" y2="1024"/>
    <line x1="0" y1="256" x2="1024" y2="256"/>
    <line x1="0" y1="512" x2="1024" y2="512"/>
    <line x1="0" y1="768" x2="1024" y2="768"/>
  </g>

  <!-- Baseline guide -->
  <line x1="180" y1="700" x2="844" y2="700" stroke="white" stroke-width="2"
        stroke-dasharray="12,8" opacity="0.25"/>

  <!-- x-height guide -->
  <line x1="180" y1="450" x2="844" y2="450" stroke="white" stroke-width="1.5"
        stroke-dasharray="8,6" opacity="0.15"/>

  <!-- Stylized letter 'G' (hand-drawn feel) -->
  <g filter="url(#shadow)">
    <path d="M 580 320
             C 530 260, 420 230, 350 280
             C 280 330, 250 420, 260 500
             C 270 580, 310 650, 380 680
             C 450 710, 540 690, 590 640
             C 620 610, 630 570, 620 530
             L 520 530
             L 520 490
             L 670 490
             L 670 560
             C 670 630, 630 700, 560 740
             C 490 780, 380 780, 310 730
             C 240 680, 200 590, 200 500
             C 200 410, 230 320, 300 270
             C 370 220, 490 210, 570 250
             C 610 270, 640 300, 650 340
             Z"
          fill="url(#penGrad)"
          stroke="white"
          stroke-width="3"
          opacity="0.95"
          filter="url(#innerGlow)"/>
  </g>

  <!-- Pen nib drawing the G -->
  <g transform="translate(620, 280) rotate(-45)" filter="url(#shadow)">
    <!-- Pen body -->
    <rect x="-12" y="-120" width="24" height="100" rx="4"
          fill="#FFD700" opacity="0.9"/>
    <!-- Pen nib -->
    <polygon points="-10,0 10,0 3,40 -3,40"
             fill="#C0C0C0" opacity="0.85"/>
    <!-- Nib tip -->
    <polygon points="-3,40 3,40 0,55"
             fill="#333"/>
    <!-- Ink drops -->
    <circle cx="0" cy="65" r="4" fill="white" opacity="0.7"/>
    <circle cx="-12" cy="75" r="3" fill="white" opacity="0.5"/>
    <circle cx="8" cy="80" r="2.5" fill="white" opacity="0.4"/>
  </g>

  <!-- "GlyphCrafter" text arc at bottom -->
  <text x="512" y="900" text-anchor="middle"
        font-family="system-ui, -apple-system, Helvetica, Arial, sans-serif"
        font-size="56" font-weight="600" fill="white" opacity="0.9"
        letter-spacing="8">GLYPHCRAFTER</text>

  <!-- Corner decorations (small glyph previews) -->
  <g opacity="0.15" fill="white" font-family="Georgia, serif" font-size="48">
    <text x="80" y="120">A</text>
    <text x="920" y="120">z</text>
    <text x="80" y="970">0</text>
    <text x="920" y="970">&amp;</text>
  </g>
</svg>"""


def generate_png(output_path: str, size: int = 1024):
    """Generate a PNG icon from the SVG using Pillow + cairosvg or a fallback."""
    try:
        import cairosvg
        from io import BytesIO
        png_data = cairosvg.svg2png(
            bytestring=APP_ICON_SVG.encode('utf-8'),
            output_width=size,
            output_height=size
        )
        with open(output_path, 'wb') as f:
            f.write(png_data)
        print(f"Icon generated: {output_path} ({size}x{size})")
        return

    except ImportError:
        pass

    # Fallback: generate a simpler icon using Pillow only
    try:
        from PIL import Image, ImageDraw, ImageFont

        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Rounded rectangle background
        radius = size // 4.5
        # Draw background gradient approximation
        for y in range(size):
            r = int(98 + (155 - 98) * y / size)
            g = int(113 + (138 - 113) * y / size)
            b = int(249 + (251 - 249) * y / size)
            draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

        # Apply rounded corners mask
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        r = int(size / 4.5)
        mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=r, fill=255)
        img.putalpha(mask)

        # Draw the letter G
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                                      int(size * 0.5))
        except (OSError, IOError):
            font = ImageFont.load_default()

        # Center the G
        bbox = draw.textbbox((0, 0), "G", font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        tx = (size - tw) // 2
        ty = (size - th) // 2 - size // 10
        draw.text((tx, ty), "G", fill=(255, 255, 255, 240), font=font)

        # Small label
        try:
            small_font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                int(size * 0.05))
        except (OSError, IOError):
            small_font = ImageFont.load_default()

        label = "GLYPHCRAFTER"
        lbox = draw.textbbox((0, 0), label, font=small_font)
        lw = lbox[2] - lbox[0]
        draw.text(((size - lw) // 2, int(size * 0.82)), label,
                  fill=(255, 255, 255, 200), font=small_font)

        img.save(output_path, 'PNG')
        print(f"Icon generated (Pillow fallback): {output_path} ({size}x{size})")

    except ImportError:
        print("ERROR: Neither cairosvg nor Pillow are installed.")
        print("Install with: pip install Pillow cairosvg")
        print("Alternatively, use --svg to get the SVG source and convert manually.")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Generate GlyphCrafter app icon")
    parser.add_argument("--output", "-o",
                        default="GlyphCrafter/Assets.xcassets/AppIcon.appiconset/appicon_1024.png",
                        help="Output path for PNG icon")
    parser.add_argument("--svg", action="store_true",
                        help="Print SVG source to stdout instead of generating PNG")
    parser.add_argument("--size", type=int, default=1024,
                        help="Icon size in pixels (default: 1024)")

    args = parser.parse_args()

    if args.svg:
        print(APP_ICON_SVG)
    else:
        generate_png(args.output, args.size)


if __name__ == "__main__":
    main()
