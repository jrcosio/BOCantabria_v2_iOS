#!/usr/bin/env python3
"""Genera el escudo de la pantalla de lanzamiento a partir del escudo del catálogo.

El sistema centra la imagen del lanzamiento en la pantalla, a su tamaño natural, y no admite
posicionarla. La portada, en cambio, coloca el escudo por encima del centro óptico. Para que el
escudo no salte en la transición, el desplazamiento va **dentro del lienzo** del recurso: el
escudo se dibuja arriba y debajo queda relleno transparente, de modo que al centrarse quede a la
altura a la que la portada lo dibuja. Ver research.md D-203 de la feature 002.

No se edita a mano el SVG resultante: si cambia el escudo de origen, se vuelve a ejecutar esto.
"""

import pathlib
import re
import sys

ICONS = pathlib.Path("BOCantabria-ios/Assets.xcassets/Icons")
SOURCE = ICONS / "ic_escudo_cantabria.imageset" / "ic_escudo_cantabria.svg"
TARGET_DIR = ICONS / "ic_launch_emblem.imageset"
TARGET = TARGET_DIR / "ic_launch_emblem.svg"

# Geometría, toda en puntos y toda derivada del documento de diseño:
EMBLEM_HEIGHT = 104.0      # §13.2: «Escudo: 104 dp de alto»
CENTER_OFFSET = 68.2       # Cuánto queda el centro del escudo por encima del centro de la pantalla.
                           # **Medido, no calculado.** La portada centra el bloque escudo + BOC +
                           # denominación + línea, y de ahí sale esta cifra: se captura la portada
                           # en el simulador de referencia y se mide dónde cae el escudo. Si cambia
                           # la composición, se vuelve a medir y se regenera esto; al revés no
                           # funciona, porque la altura del bloque depende de la tipografía.

# La caja del contenido dentro del viewBox de origen, tomada de su clipPath.
BOX_X, BOX_Y, BOX_W, BOX_H = 3.76, 2.97, 71.52, 131.06


def main() -> int:
    source = SOURCE.read_text()

    scale = EMBLEM_HEIGHT / BOX_H
    width = BOX_W * scale
    canvas_w = round(width + 2, 2)                      # un punto de aire a cada lado
    canvas_h = round(2 * (CENTER_OFFSET + EMBLEM_HEIGHT / 2), 2)
    tx = round((canvas_w - width) / 2 - BOX_X * scale, 4)
    ty = round(-BOX_Y * scale, 4)

    defs = re.search(r"<defs>.*?</defs>", source, re.S)
    body = re.search(r'<g clip-path="url\(#clip1\)">.*</g>', source, re.S)
    if defs is None or body is None:
        print("El SVG de origen no tiene la forma esperada.", file=sys.stderr)
        return 1

    out = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_w}" height="{canvas_h}" '
        f'viewBox="0 0 {canvas_w} {canvas_h}">\n'
        f"  {defs.group(0)}\n"
        f'  <g transform="translate({tx},{ty}) scale({round(scale, 6)})">\n'
        f"    {body.group(0)}\n"
        f"  </g>\n"
        f"</svg>\n"
    )

    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(out)
    (TARGET_DIR / "Contents.json").write_text(
        '{\n'
        '  "images" : [\n'
        '    {\n'
        '      "filename" : "ic_launch_emblem.svg",\n'
        '      "idiom" : "universal"\n'
        '    }\n'
        '  ],\n'
        '  "info" : {\n'
        '    "author" : "xcode",\n'
        '    "version" : 1\n'
        '  },\n'
        '  "properties" : {\n'
        '    "preserves-vector-representation" : true,\n'
        '    "template-rendering-intent" : "original"\n'
        '  }\n'
        '}\n'
    )
    print(f"{TARGET}: lienzo {canvas_w}×{canvas_h}, escudo {round(width, 2)}×{EMBLEM_HEIGHT}, "
          f"centro a {CENTER_OFFSET} pt por encima del centro del lienzo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
