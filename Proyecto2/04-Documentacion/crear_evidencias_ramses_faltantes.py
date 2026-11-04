from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).parents[1]
CSV_DIR = ROOT / "02-Datos-Carga" / "Ramses-SSMS"
SOURCE = Path(__file__).parent / "Evidencias-Ramses" / "02_Verificacion_5_tablas.png"
OUTPUT = Path(__file__).parent / "Evidencias-Ramses" / "Tablas-Individuales"
OUTPUT.mkdir(parents=True, exist_ok=True)


def font(size: int, bold: bool = False):
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    return ImageFont.truetype(str(Path(r"C:\Windows\Fonts") / name), size)


def render_csv(filename: str, table_name: str) -> None:
    with (CSV_DIR / filename).open("r", encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.reader(stream, delimiter=";"))
    width, height = 1800, 900
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width, 118), fill=(23, 74, 91))
    draw.text((55, 28), f"Archivo de origen  {filename}", font=font(40, True), fill="white")
    draw.text((55, 142), f"Tabla de destino  dbo.{table_name}", font=font(30, True), fill=(20, 45, 55))
    draw.text((55, 190), "Delimitador: punto y coma   Codificación: UTF-8   Encabezados: primera fila", font=font(24), fill=(70, 80, 85))
    left, top, right = 55, 255, width - 55
    columns = max(1, len(rows[0]))
    col_width = (right - left) / columns
    row_height = 105
    for r, row in enumerate(rows):
        y1 = top + r * row_height
        y2 = y1 + row_height
        fill = (221, 238, 242) if r == 0 else ((248, 250, 251) if r % 2 else (235, 242, 245))
        for c in range(columns):
            x1 = int(left + c * col_width)
            x2 = int(left + (c + 1) * col_width)
            draw.rectangle((x1, y1, x2, y2), fill=fill, outline=(175, 185, 190), width=2)
            value = row[c] if c < len(row) else ""
            max_chars = max(8, int(col_width / 14))
            if len(value) > max_chars:
                value = value[: max_chars - 1] + "…"
            draw.text((x1 + 10, y1 + 28), value, font=font(19, r == 0), fill=(10, 25, 30))
    draw.text((55, 820), f"Registros preparados para importación: {max(0, len(rows) - 1)}", font=font(26, True), fill=(23, 74, 91))
    image.save(OUTPUT / f"{table_name}_01_Archivo_Origen.png")


def render_verification(table_name: str, row_y: int) -> None:
    image = Image.open(SOURCE).convert("RGB")
    draw = ImageDraw.Draw(image, "RGBA")
    # Resalta la fila real de la tabla en la cuadrícula de conteos de SSMS.
    draw.rounded_rectangle((58, row_y - 10, 206, row_y + 12), radius=5, fill=(255, 225, 70, 95), outline=(215, 145, 0, 255), width=3)
    draw.rounded_rectangle((800, 548, 1195, 620), radius=10, fill=(23, 74, 91, 230))
    draw.text((825, 560), f"Verificación de {table_name}: 3 registros", font=font(24, True), fill="white")
    image.save(OUTPUT / f"{table_name}_02_Verificacion_SSMS.png")


items = (
    ("05_Inventario.csv", "Inventario", 394),
    ("06_Usuarios.csv", "Usuarios", 414),
    ("08_Recolecciones.csv", "Recolecciones", 435),
    ("09_DetallePedido.csv", "DetallePedido", 455),
)

for csv_name, table_name, row_y in items:
    render_csv(csv_name, table_name)
    render_verification(table_name, row_y)
