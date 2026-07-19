#!/usr/bin/env python3

import argparse
import base64
from pathlib import Path

from fontTools.ttLib import TTFont

SCRIPT_DIR = Path(__file__).parent
FONT_PATH = SCRIPT_DIR.parent / "fonts" / "Oaboe.ttf"

PAD_X = 5
PAD_Y = 2
SCALE = 3
FONT_SIZE = 8

THEME = {
    "BG": "#0E1116",
    "SURFACE": "#161B22",
    "SURFACE_HI": "#20262F",
    "BORDER": "#2A313C",
    "TEXT": "#FFFFFF",
    "TEXT_MUTED": "#E6E8EC",
    "ICON": "#8B93A1",
    "ACCENT": "#2F81F7",
    "DANGER": "#E5484D",
    "WARN": "#F6AA1C",
    "SUCCESS": "#2FBF71",
}


def load_font_metrics(font_path: Path):
    font = TTFont(str(font_path))
    cmap = font.getBestCmap()
    upm = font["head"].unitsPerEm
    hmtx = font["hmtx"]
    ascent = font["hhea"].ascent
    descent = font["hhea"].descent
    return font, upm, cmap, hmtx, ascent, descent


def measure_text(text, upm, cmap, hmtx, font_size):
    total_units = 0
    for ch in text:
        if ch == " ":
            gname = cmap.get(ord(" "))
            if gname:
                total_units += hmtx[gname][0]
            else:
                total_units += upm // 2
            continue
        gname = cmap.get(ord(ch))
        if gname is None:
            raise ValueError(f"Font has no glyph for character {ch!r}")
        total_units += hmtx[gname][0]
    return total_units / upm * font_size


def embed_font_css(font_path: Path, family_name="Oaboe"):
    data = font_path.read_bytes()
    b64 = base64.b64encode(data).decode("ascii")
    return f"""
    @font-face {{
      font-family: '{family_name}';
      src: url(data:font/ttf;base64,{b64}) format('truetype');
    }}
    """


def resolve_color(value):
    if value in THEME:
        return THEME[value]
    return value


def build_svg(text, label_color="TEXT", bg_color="SURFACE", border_color=None, border_width=1):
    label_color = resolve_color(label_color)
    bg_color = resolve_color(bg_color)
    border_color = resolve_color(border_color) if border_color else None
    font, upm, cmap, hmtx, ascent, descent = load_font_metrics(FONT_PATH)

    text_w_design = measure_text(text, upm, cmap, hmtx, FONT_SIZE)
    text_h_design = FONT_SIZE

    frame_w_design = text_w_design + PAD_X * 2
    frame_h_design = text_h_design + PAD_Y * 2

    frame_w = round(frame_w_design * SCALE)
    frame_h = round(frame_h_design * SCALE)

    font_size_scaled = FONT_SIZE * SCALE
    pad_x_scaled = PAD_X * SCALE
    pad_y_scaled = PAD_Y * SCALE

    font_css = embed_font_css(FONT_PATH)

    ascent_ratio = ascent / upm
    baseline_y = pad_y_scaled + ascent_ratio * font_size_scaled

    if border_color:
        bw = border_width
        rect_attrs = f'fill="{bg_color}" stroke="{border_color}" stroke-width="{bw}"'
        rect_geom = f'x="{bw/2}" y="{bw/2}" width="{frame_w - bw}" height="{frame_h - bw}"'
    else:
        rect_attrs = f'fill="{bg_color}"'
        rect_geom = 'width="100%" height="100%"'

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{frame_w}" height="{frame_h}" viewBox="0 0 {frame_w} {frame_h}">
  <defs>
    <style>
      {font_css}
      text.badge-label {{
        font-family: 'Oaboe', monospace;
        font-size: {font_size_scaled}px;
        fill: {label_color};
        dominant-baseline: alphabetic;
      }}
    </style>
  </defs>
  <rect {rect_geom} {rect_attrs} shape-rendering="crispEdges"/>
  <text x="{pad_x_scaled}" y="{baseline_y}" class="badge-label" style="image-rendering: pixelated;">{escape_xml(text)}</text>
</svg>
"""
    return svg


def escape_xml(s):
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--text", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--bg", default="SURFACE")
    ap.add_argument("--fg", default="TEXT")
    ap.add_argument("--border", default=None)
    ap.add_argument("--border-width", type=float, default=3)
    args = ap.parse_args()

    svg = build_svg(
        args.text,
        label_color=args.fg,
        bg_color=args.bg,
        border_color=args.border,
        border_width=args.border_width,
    )

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(svg, encoding="utf-8")


if __name__ == "__main__":
    main()
