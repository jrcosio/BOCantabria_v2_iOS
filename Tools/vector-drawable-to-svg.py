#!/usr/bin/env python3
"""
Convierte los VectorDrawable de Android del proyecto BOCantabria (Kotlin) en SVG
para el catálogo de recursos de iOS.

Por qué existe: los cuarenta iconos de la aplicación son vectores propios con el
trazado tomado de Material Symbols sin modificar, más el escudo de Cantabria. No
son SF Symbols y no deben serlo: el documento de diseño los especifica uno a uno.
`pathData` de Android usa la misma gramática que el atributo `d` de SVG, así que
la conversión es mecánica y reproducible; lo que no es mecánico son los grupos con
traslación y las dos convenciones de lienzo del repositorio de origen (960 con
coordenadas negativas y 24 sin `viewBox`), que aquí se resuelven leyendo el lienzo
declarado en cada fichero y no suponiéndolo.

Uso:
    python3 Tools/vector-drawable-to-svg.py <dir-drawable-android> <dir-Assets.xcassets>
"""

import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"


def attr(el, name):
    return el.get(ANDROID + name)


def to_number(value, default=0.0):
    if value is None:
        return default
    return float(re.sub(r"(dp|dip|px|sp)$", "", value.strip()))


def to_color(value):
    """#AARRGGBB | #RRGGBB | #ARGB | #RGB -> (color css, opacidad)."""
    if value is None:
        return None, None
    v = value.strip()
    if not v.startswith("#"):
        return v, None
    h = v[1:]
    if len(h) == 3:
        return "#" + "".join(c * 2 for c in h), None
    if len(h) == 4:
        a, rgb = h[0], h[1:]
        return "#" + "".join(c * 2 for c in rgb), round(int(a * 2, 16) / 255, 4)
    if len(h) == 6:
        return "#" + h, None
    if len(h) == 8:
        a, rgb = h[:2], h[2:]
        alpha = int(a, 16) / 255
        return "#" + rgb, None if alpha == 1.0 else round(alpha, 4)
    return v, None


def group_transform(el):
    parts = []
    tx, ty = to_number(attr(el, "translateX")), to_number(attr(el, "translateY"))
    sx, sy = to_number(attr(el, "scaleX"), 1.0), to_number(attr(el, "scaleY"), 1.0)
    rot = to_number(attr(el, "rotation"))
    px, py = to_number(attr(el, "pivotX")), to_number(attr(el, "pivotY"))
    if tx or ty:
        parts.append(f"translate({tx:g},{ty:g})")
    if rot:
        parts.append(f"rotate({rot:g},{px:g},{py:g})")
    if sx != 1.0 or sy != 1.0:
        if px or py:
            parts.append(f"translate({px:g},{py:g}) scale({sx:g},{sy:g}) translate({-px:g},{-py:g})")
        else:
            parts.append(f"scale({sx:g},{sy:g})")
    return " ".join(parts)


def escape(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


class Converter:
    def __init__(self):
        self.defs = []
        self.colors = set()
        self.clip_seq = 0

    def path_element(self, el, indent):
        d = attr(el, "pathData")
        if not d:
            return ""
        bits = [f'd="{escape(d)}"']
        fill, fill_alpha = to_color(attr(el, "fillColor"))
        if fill:
            self.colors.add(fill.lower())
            bits.append(f'fill="{fill}"')
        else:
            bits.append('fill="none"')
        declared_alpha = attr(el, "fillAlpha")
        if declared_alpha is not None:
            fill_alpha = float(declared_alpha)
        if fill_alpha is not None and fill_alpha != 1.0:
            bits.append(f'fill-opacity="{fill_alpha:g}"')
        if attr(el, "fillType") == "evenOdd":
            bits.append('fill-rule="evenodd"')
        stroke, stroke_alpha = to_color(attr(el, "strokeColor"))
        if stroke:
            self.colors.add(stroke.lower())
            bits.append(f'stroke="{stroke}"')
            width = attr(el, "strokeWidth")
            if width:
                bits.append(f'stroke-width="{to_number(width):g}"')
            for android_name, svg_name in (
                ("strokeLineCap", "stroke-linecap"),
                ("strokeLineJoin", "stroke-linejoin"),
            ):
                value = attr(el, android_name)
                if value:
                    bits.append(f'{svg_name}="{value}"')
            if stroke_alpha is not None and stroke_alpha != 1.0:
                bits.append(f'stroke-opacity="{stroke_alpha:g}"')
        return f'{indent}<path {" ".join(bits)}/>\n'

    def children(self, parent, indent):
        out = ""
        for el in parent:
            tag = el.tag.split("}")[-1]
            if tag == "path":
                out += self.path_element(el, indent)
            elif tag == "group":
                clips = [c for c in el if c.tag.split("}")[-1] == "clip-path"]
                attrs = []
                transform = group_transform(el)
                if transform:
                    attrs.append(f'transform="{transform}"')
                for clip in clips:
                    self.clip_seq += 1
                    cid = f"clip{self.clip_seq}"
                    self.defs.append(
                        f'  <clipPath id="{cid}"><path d="{escape(attr(clip, "pathData"))}"/></clipPath>'
                    )
                    attrs.append(f'clip-path="url(#{cid})"')
                head = "<g" + ("" if not attrs else " " + " ".join(attrs)) + ">"
                out += f"{indent}{head}\n"
                out += self.children(el, indent + "  ")
                out += f"{indent}</g>\n"
        return out

    def convert(self, xml_path):
        root = ET.parse(xml_path).getroot()
        vw = to_number(attr(root, "viewportWidth"), 24.0)
        vh = to_number(attr(root, "viewportHeight"), 24.0)
        w = to_number(attr(root, "width"), vw)
        h = to_number(attr(root, "height"), vh)
        body = self.children(root, "  ")
        defs = ""
        if self.defs:
            defs = "  <defs>\n" + "\n".join("  " + d for d in self.defs) + "\n  </defs>\n"
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:g}" height="{h:g}" '
            f'viewBox="0 0 {vw:g} {vh:g}">\n{defs}{body}</svg>\n'
        )
        return svg, self.colors


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    src = pathlib.Path(sys.argv[1])
    dst = pathlib.Path(sys.argv[2]) / "Icons"
    dst.mkdir(parents=True, exist_ok=True)

    # El icono de la aplicación se compone aparte: en Android es un icono adaptativo
    # (fondo + primer plano) y en iOS es un PNG de 1024 sin zona segura.
    skip = {"ic_launcher_background", "ic_launcher_foreground"}

    made = 0
    for xml_path in sorted(src.glob("*.xml")):
        name = xml_path.stem
        if name in skip:
            continue
        svg, colors = Converter().convert(xml_path)
        monochrome = len({c for c in colors if c != "none"}) <= 1
        folder = dst / f"{name}.imageset"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{name}.svg").write_text(svg)
        contents = {
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {
                "preserves-vector-representation": True,
                # Los iconos de un solo color los tiñe el punto de uso, igual que
                # Compose teñía el `android:fillColor` marcador de posición.
                # El escudo y cualquier vector multicolor se dibujan tal cual.
                "template-rendering-intent": "template" if monochrome else "original",
            },
        }
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
        made += 1
        print(f"{name:32s} {'plantilla' if monochrome else 'original ':10s} {len(colors)} color(es)")
    print(f"\n{made} iconos convertidos en {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
