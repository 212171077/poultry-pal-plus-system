"""Rebuild the bundled Fluent Emoji subset with fonttools 4.68.0."""

from pathlib import Path
from xml.etree import ElementTree

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path


ROOT = Path(__file__).resolve().parents[1]
ICONS = {"chicken": 0xE900, "chick": 0xE901, "hatching_chick": 0xE902}


def build():
    builder = FontBuilder(1024, isTTF=True)
    builder.setupGlyphOrder([".notdef", *ICONS])
    builder.setupCharacterMap({code: name for name, code in ICONS.items()})
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    for name in ICONS:
        pen = TTGlyphPen(None)
        # SVG's downward Y axis becomes the font's upward Y axis.
        svg_pen = TransformPen(Cu2QuPen(pen, max_err=0.5), (32, 0, 0, -32, 0, 896))
        svg = ElementTree.parse(ROOT / "assets/icons" / f"{name}.svg")
        for path in svg.iter("{http://www.w3.org/2000/svg}path"):
            parse_path(path.attrib["d"], svg_pen)
        glyphs[name] = pen.glyph()
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics({
        name: (1024, getattr(glyph, "xMin", 0))
        for name, glyph in glyphs.items()
    })
    builder.setupHorizontalHeader(ascent=896, descent=-128)
    builder.setupNameTable({
        "familyName": "PoultryIcons",
        "styleName": "Regular",
        "uniqueFontIdentifier": "PoultryIcons",
        "fullName": "PoultryIcons",
        "psName": "PoultryIcons",
        "copyright": "Copyright (c) Microsoft Corporation. Licensed under MIT.",
    })
    builder.setupOS2(sTypoAscender=896, sTypoDescender=-128,
                     usWinAscent=896, usWinDescent=128)
    builder.setupPost()
    builder.save(ROOT / "assets/icons/poultry_icons.ttf")


if __name__ == "__main__":
    build()
