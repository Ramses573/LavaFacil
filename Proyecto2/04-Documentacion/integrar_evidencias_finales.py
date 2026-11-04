"""Integra evidencias públicas de BCP y GraphQL en el manual del Proyecto 2."""

from __future__ import annotations

import argparse
import io
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Inches, Pt


REPLACEMENTS = {
    "100.70.40.33,1433": "[SERVIDOR PRIVADO]",
    "100.70.40.33": "[SERVIDOR PRIVADO]",
    "rachel_proyecto": "[USUARIO SQL]",
    "LAPTOP-D0TECCJR": "[EQUIPO PRIVADO]",
    "DESKTOP-EEOH9C5": "[EQUIPO PRIVADO]",
}

CONSOLE_REDACTIONS = {
    "image7.png": [(0.00, 0.00, 1.00, 0.48)],
    "image8.png": [(0.00, 0.00, 1.00, 0.40)],
    "image10.png": [(0.00, 0.38, 1.00, 0.62)],
    "image11.png": [(0.00, 0.06, 1.00, 0.25), (0.00, 0.43, 1.00, 0.64)],
    "image14.png": [(0.00, 0.00, 1.00, 0.36)],
    "image17.png": [(0.00, 0.00, 1.00, 0.34)],
    "image20.png": [(0.00, 0.00, 1.00, 0.34)],
}


def redact_text(text: str) -> str:
    for original, replacement in REPLACEMENTS.items():
        text = text.replace(original, replacement)
    return text


def font(size: int = 20):
    for candidate in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def cover(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], label: str) -> None:
    draw.rectangle(box, fill=(18, 22, 27))
    x1, y1, x2, y2 = box
    text_box = draw.textbbox((0, 0), label, font=font(18))
    tx = x1 + max(8, (x2 - x1 - (text_box[2] - text_box[0])) // 2)
    ty = y1 + max(5, (y2 - y1 - (text_box[3] - text_box[1])) // 2)
    draw.text((tx, ty), label, fill=(255, 255, 255), font=font(18))


def redact_image(blob: bytes, filename: str, output_dir: Path) -> Path:
    image = Image.open(io.BytesIO(blob)).convert("RGB")
    draw = ImageDraw.Draw(image)
    width, height = image.size

    if filename == "image3.png":
        cover(draw, (20, 90, width - 25, 205), "Conexiones privadas ocultadas")
        cover(draw, (185, 220, width - 35, 360), "Servidor usuario y clave ocultados")

    extra_boxes = {
        "image1.png": [(40, 320, 260, 370, "Servidor privado ocultado")],
        "image4.png": [(40, 315, 250, 365, "Servidor privado ocultado")],
        "image22.png": [(35, 335, 560, 390, "Servidor y usuario ocultados")],
        "image24.png": [(35, 325, 180, 385, "Usuario ocultado")],
        "image25.png": [
            (0, 105, 365, 195, "Conexión privada ocultada"),
            (0, 285, 365, 380, "Conexión privada ocultada"),
            (365, 590, width, 665, "Servidor y usuario ocultados"),
        ],
    }
    for x1, y1, x2, y2, label in extra_boxes.get(filename, []):
        cover(draw, (x1, y1, min(x2, width), min(y2, height)), label)

    for left, top, right, bottom in CONSOLE_REDACTIONS.get(filename, []):
        cover(
            draw,
            (int(width * left), int(height * top), int(width * right), int(height * bottom)),
            "Servidor y usuario SQL ocultados",
        )

    # Las capturas de SSMS muestran servidor y usuario en la barra inferior.
    if ImageStat.Stat(image.convert("L")).mean[0] > 150 and filename != "image3.png":
        cover(draw, (0, int(height * 0.93), width, height), "Conexión privada ocultada")

    output = output_dir / filename
    image.save(output, format="PNG", optimize=True)
    return output


def add_picture(document: Document, image_path: Path) -> None:
    with Image.open(image_path) as image:
        width, height = image.size
    max_width = 6.25
    max_height = 7.0
    rendered_width = max_width
    rendered_height = rendered_width * height / width
    if rendered_height > max_height:
        rendered_height = max_height
        rendered_width = rendered_height * width / height
    paragraph = document.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_after = Pt(9)
    paragraph.add_run().add_picture(str(image_path), width=Inches(rendered_width))


def image_parts(paragraph, evidence: Document):
    for blip in paragraph._p.xpath(".//a:blip"):
        relationship_id = blip.get(qn("r:embed"))
        part = evidence.part.related_parts[relationship_id]
        yield Path(str(part.partname)).name, part.blob


def append_evidence(base: Document, evidence_path: Path, work_dir: Path) -> None:
    evidence = Document(evidence_path)
    base.add_page_break()
    base.add_heading("Evidencias de carga masiva con BCP", level=1)
    base.add_paragraph(
        "Esta sección reúne las evidencias aportadas por Rachel para las cargas de Clientes, "
        "Servicios, Promociones, Pedidos y Pagos. Los datos privados de conexión fueron ocultados "
        "sin alterar los resultados de las cargas ni las consultas de verificación."
    )

    redacted_dir = work_dir / "redacted_media"
    redacted_dir.mkdir(parents=True, exist_ok=True)

    for index, paragraph in enumerate(evidence.paragraphs):
        if index < 3:
            continue
        text = redact_text(paragraph.text.strip())
        if text:
            style = "Heading 2" if paragraph.style.name.startswith("Heading") else "Normal"
            target = base.add_paragraph(text, style=style)
            if style == "Heading 2":
                target.paragraph_format.keep_with_next = True
            else:
                target.paragraph_format.space_after = Pt(6)
        for filename, blob in image_parts(paragraph, evidence):
            redacted = redact_image(blob, filename, redacted_dir)
            add_picture(base, redacted)


def append_ramses_evidence(base: Document, evidence_dir: Path, work_dir: Path) -> None:
    base.add_page_break()
    base.add_heading("Evidencias del Asistente de importación de SSMS", level=1)
    base.add_paragraph(
        "Ramsés utilizó el Asistente de importación de SQL Server Management Studio para demostrar "
        "el segundo método de carga exigido. Después verificó conjuntamente las cinco tablas asignadas."
    )
    items = (
        (
            "Carga de Empleados mediante el asistente",
            "La ejecución transfirió tres filas a la tabla existente dbo.Empleados con inserción de identidad habilitada.",
            "01_Empleados_3_filas_transferidas.png",
        ),
        (
            "Verificación final de las cinco tablas de Ramsés",
            "La consulta final confirmó los registros 2001, 2002 y 2003 en Empleados, Inventario, Usuarios, Recolecciones y DetallePedido.",
            "02_Verificacion_5_tablas.png",
        ),
    )
    redacted_dir = work_dir / "redacted_ramses"
    redacted_dir.mkdir(parents=True, exist_ok=True)
    for heading, description, filename in items:
        base.add_heading(heading, level=2)
        base.add_paragraph(description)
        source = evidence_dir / filename
        redacted = redact_image(source.read_bytes(), filename, redacted_dir)
        add_picture(base, redacted)


def append_graphql(base: Document, screenshot: Path) -> None:
    base.add_page_break()
    base.add_heading("Pruebas reales de GraphQL", level=1)
    base.add_paragraph(
        "El backend se ejecutó contra la base LavaFacil mediante las conexiones privadas de los "
        "roles Invitado, Cliente y Empleado. Las pruebas utilizaron una cuenta administrativa "
        "temporal y eliminaron todos los registros creados al finalizar."
    )
    for item in (
        "Consulta pública de Servicios y Promociones con respuesta HTTP 200.",
        "Inicio de sesión temporal con rol Administrador.",
        "Consultas protegidas de las diez tablas.",
        "Inserción, actualización y eliminación de Clientes, Servicios, Promociones, Pedidos y Pagos.",
        "Eliminación de los registros y de la cuenta temporal al finalizar.",
    ):
        paragraph = base.add_paragraph(style="List Bullet")
        paragraph.add_run(item)
    add_picture(base, screenshot)
    caption = base.add_paragraph("Figura. Consulta pública GraphQL con estado HTTP 200 y datos obtenidos de SQL Server.")
    caption.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in caption.runs:
        run.italic = True
        run.font.size = Pt(9)


def normalize_project2_scope(document: Document) -> None:
    """El Proyecto 2 se entrega con una sola instancia, sin mirroring ni failover."""
    paragraph_replacements = {
        "La cadena incluye Initial Catalog y Failover Partner para que una conexión nueva pueda alcanzar al servidor que tenga el rol principal.":
            "La cadena utiliza Initial Catalog=LavaFacil y una conexión privada al único servidor principal definido para el Proyecto 2.",
        "Ambos deben trabajar contra el servidor que tenga el rol principal y confirmar que el mirroring vuelva a SYNCHRONIZED después de cada bloque de carga.":
            "Ambos integrantes trabajan contra la misma instancia principal y verifican las dependencias antes de cada bloque de carga.",
        "Las tres cuentas SQL se crean en ambas instancias con los mismos SID.":
            "Las tres cuentas SQL se crean en la instancia principal con contraseñas privadas.",
        "Conservar Initial Catalog=LavaFacil cuando se configure Failover Partner.":
            "Conservar Initial Catalog=LavaFacil en las tres cadenas de conexión locales.",
    }
    for paragraph in document.paragraphs:
        text = paragraph.text
        if text.strip() == "Prueba de failover":
            paragraph.text = "Continuidad del servidor principal"
            continue
        if text.startswith("Antes de conmutar, ambos servidores"):
            paragraph.text = (
                "Para este avance se utiliza una sola instancia principal de SQL Server. Antes de la demostración se comprueba "
                "que SQL Server esté iniciado, que el puerto configurado responda por la red privada y que las tres conexiones "
                "GraphQL puedan ejecutar sus procedimientos autorizados. La técnica de replicación no forma parte de este avance."
            )
            continue
        for original, replacement in paragraph_replacements.items():
            if original in text:
                paragraph.text = text.replace(original, replacement)
                break
    for table in document.tables:
        for row in table.rows:
            if row.cells[0].text.strip() == "Alta disponibilidad":
                row.cells[0].text = "Servidor principal"
                if len(row.cells) > 1:
                    row.cells[1].text = "Conexión, roles y consulta GraphQL exitosa"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--ramses-dir", type=Path, required=True)
    parser.add_argument("--graphql", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    args = parser.parse_args()

    args.work_dir.mkdir(parents=True, exist_ok=True)
    document = Document(args.base)
    document.core_properties.title = "Manual técnico del Proyecto 2 LavaFácil"
    document.core_properties.subject = "Carga masiva con BCP y SSMS, seguridad y API GraphQL"
    document.core_properties.author = "Ramsés Aguilar y Rachel Rosales"

    normalize_project2_scope(document)

    append_ramses_evidence(document, args.ramses_dir, args.work_dir)
    append_evidence(document, args.evidence, args.work_dir)
    append_graphql(document, args.graphql)

    document.add_page_break()
    document.add_heading("Conclusión de las pruebas", level=1)
    document.add_paragraph(
        "Las diez tablas contienen los registros previstos, las cargas masivas fueron verificadas y "
        "GraphQL ejecutó consultas y operaciones CRUD mediante procedimientos almacenados. Las "
        "credenciales permanecen fuera del repositorio y las evidencias públicas no revelan datos "
        "privados de conexión."
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    document.save(args.output)


if __name__ == "__main__":
    main()
