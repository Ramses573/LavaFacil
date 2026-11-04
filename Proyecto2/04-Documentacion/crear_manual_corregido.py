from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


BLUE = "174A5B"
LIGHT = "EAF3F5"
GRAY = "D9D9D9"


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for tag, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{tag}"))
        if node is None:
            node = OxmlElement(f"w:{tag}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_table_borders(table) -> None:
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = borders.find(qn(f"w:{edge}"))
        if tag is None:
            tag = OxmlElement(f"w:{edge}")
            borders.append(tag)
        tag.set(qn("w:val"), "single")
        tag.set(qn("w:sz"), "4")
        tag.set(qn("w:color"), GRAY)


def add_page_field(paragraph) -> None:
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = "1"
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    for node in (begin, instr, separate, text, end):
        run._r.append(node)


def add_picture(doc: Document, image_path: Path, caption: str) -> None:
    with Image.open(image_path) as image:
        w, h = image.size
    max_w, max_h = 6.35, 7.25
    width = max_w
    height = width * h / w
    if height > max_h:
        height = max_h
        width = height * w / h
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.keep_with_next = True
    p.add_run().add_picture(str(image_path), width=Inches(width))
    cp = doc.add_paragraph(caption, style="Caption")
    cp.alignment = WD_ALIGN_PARAGRAPH.CENTER


def extract_images_in_order(source: Document, work_dir: Path):
    media = work_dir / "evidencias_rachel_originales"
    media.mkdir(parents=True, exist_ok=True)
    number = 0
    for paragraph in source.paragraphs:
        images = []
        for blip in paragraph._p.xpath(".//a:blip"):
            number += 1
            rid = blip.get(qn("r:embed"))
            part = source.part.related_parts[rid]
            suffix = Path(str(part.partname)).suffix or ".png"
            target = media / f"rachel_{number:02d}{suffix}"
            target.write_bytes(part.blob)
            images.append(target)
        yield paragraph, images


def configure_styles(doc: Document) -> None:
    normal = doc.styles["Normal"]
    normal.font.name = "Aptos"
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = RGBColor(0, 0, 0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.08
    for name, size, before, after in (
        ("Title", 26, 0, 10),
        ("Subtitle", 13, 0, 18),
        ("Heading 1", 18, 16, 8),
        ("Heading 2", 14, 12, 6),
        ("Heading 3", 11.5, 10, 4),
    ):
        style = doc.styles[name]
        style.font.name = "Aptos Display" if name != "Normal" else "Aptos"
        style.font.size = Pt(size)
        style.font.bold = name != "Subtitle"
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True
    cap = doc.styles["Caption"]
    cap.font.name = "Aptos"
    cap.font.size = Pt(9)
    cap.font.italic = True
    cap.font.color.rgb = RGBColor(70, 70, 70)
    cap.paragraph_format.space_after = Pt(10)


def add_cover(doc: Document) -> None:
    p = doc.add_paragraph(style="Title")
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(95)
    p.add_run("Manual técnico del Proyecto 2 LavaFácil")
    p = doc.add_paragraph(style="Subtitle")
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run("Carga masiva con BCP y SSMS y API GraphQL con procedimientos almacenados")
    for _ in range(5):
        doc.add_paragraph()
    for line in (
        "Curso: Bases de Datos Avanzadas",
        "Integrantes: José Ramsés Aguilar y Rachel Rosales",
        "Base de datos: LavaFacil",
        "Fecha: noviembre de 2026",
    ):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.add_run(line).bold = line.startswith("Integrantes")
    doc.add_page_break()


def add_index(doc: Document) -> None:
    doc.add_heading("Índice de evidencias", level=1)
    doc.add_paragraph(
        "El cuerpo del manual se organiza por las diez tablas del proyecto y por las pruebas de seguridad y GraphQL."
    )
    table = doc.add_table(rows=1, cols=3)
    table.autofit = False
    headers = ("Orden", "Tabla", "Responsable y método")
    for i, value in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = value
        set_cell_shading(cell, BLUE)
        for run in cell.paragraphs[0].runs:
            run.font.bold = True
            run.font.color.rgb = RGBColor(255, 255, 255)
    entries = (
        (1, "Clientes", "Rachel — BCP"),
        (2, "Empleados", "Ramsés — Asistente de SSMS"),
        (3, "Servicios", "Rachel — BCP"),
        (4, "Promociones", "Rachel — BCP"),
        (5, "Inventario", "Ramsés — Asistente de SSMS"),
        (6, "Usuarios", "Ramsés — Asistente de SSMS"),
        (7, "Pedidos", "Rachel — BCP"),
        (8, "Recolecciones", "Ramsés — Asistente de SSMS"),
        (9, "DetallePedido", "Ramsés — Asistente de SSMS"),
        (10, "Pagos", "Rachel — BCP"),
    )
    for row_index, entry in enumerate(entries, 1):
        cells = table.add_row().cells
        for i, value in enumerate(entry):
            cells[i].text = str(value)
            cells[i].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_margins(cells[i])
            if row_index % 2 == 0:
                set_cell_shading(cells[i], LIGHT)
    table.columns[0].width = Inches(0.65)
    table.columns[1].width = Inches(2.0)
    table.columns[2].width = Inches(3.7)
    set_table_borders(table)
    doc.add_page_break()


def add_requirements(doc: Document) -> None:
    doc.add_heading("Alcance y requisitos verificados", level=1)
    doc.add_paragraph(
        "La profesora solicitó utilizar al menos una vez BCP y el Asistente de importación de SSMS; documentar para cada tabla el archivo de origen, la instrucción o configuración, el resultado de ejecución y la consulta final; y desarrollar una API GraphQL con consultas y operaciones de agregar, actualizar y eliminar que invoquen procedimientos almacenados. El inicio de sesión devuelve el rol y el backend utiliza conexiones SQL separadas según el perfil."
    )
    rows = (
        ("Carga masiva", "BCP y Asistente de SSMS", "Incluida"),
        ("Datos", "Archivos CSV originales", "Incluidos en el proyecto"),
        ("GraphQL", "Login, consultas y CRUD", "Evidencias reales incluidas"),
        ("Seguridad", "Roles y varias conexiones SQL", "Incluida"),
        ("Persistencia", "Procedimientos almacenados", "Incluida"),
    )
    table = doc.add_table(rows=1, cols=3)
    for i, value in enumerate(("Componente", "Criterio", "Estado")):
        table.rows[0].cells[i].text = value
        set_cell_shading(table.rows[0].cells[i], BLUE)
        for run in table.rows[0].cells[i].paragraphs[0].runs:
            run.font.bold = True
            run.font.color.rgb = RGBColor(255, 255, 255)
    for n, row in enumerate(rows, 1):
        cells = table.add_row().cells
        for i, value in enumerate(row):
            cells[i].text = value
            set_cell_margins(cells[i])
            if n % 2 == 0:
                set_cell_shading(cells[i], LIGHT)
    set_table_borders(table)
    doc.add_page_break()


def add_rachel_evidence(doc: Document, evidence_path: Path, work_dir: Path) -> None:
    doc.add_heading("Evidencias de carga masiva con BCP", level=1)
    doc.add_paragraph(
        "Las siguientes capturas son las evidencias originales aportadas por Rachel. Se conservaron completas, sin ocultar la consola, el servidor, los usuarios ni los resultados visibles."
    )
    source = Document(evidence_path)
    figure = 0
    for index, (paragraph, images) in enumerate(extract_images_in_order(source, work_dir)):
        if index < 3:
            continue
        text = paragraph.text.strip()
        if text:
            if paragraph.style.name.startswith("Heading"):
                text = text.replace(" → ", " — ").strip()
                doc.add_heading(text, level=2)
            else:
                doc.add_paragraph(text)
        for image in images:
            figure += 1
            add_picture(doc, image, f"Figura {figure}. Evidencia original de carga y verificación BCP.")


def add_ramses_evidence(doc: Document, evidence_dir: Path) -> None:
    doc.add_page_break()
    doc.add_heading("Evidencias del Asistente de importación de SSMS", level=1)
    doc.add_paragraph(
        "Ramsés trabajó con los CSV 02_Empleados.csv, 05_Inventario.csv, 06_Usuarios.csv, 08_Recolecciones.csv y 09_DetallePedido.csv. El Asistente de SSMS se configuró con delimitador punto y coma, codificación UTF-8, primera fila con encabezados e inserción de identidad habilitada."
    )
    doc.add_heading("Empleados", level=2)
    doc.add_paragraph("Archivo de origen: 02_Empleados.csv. Método: Asistente de importación de SSMS.")
    add_picture(doc, evidence_dir / "01_Empleados_3_filas_transferidas.png", "Figura 25. Resultado exitoso del asistente: tres filas transferidas a Empleados.")
    individual_dir = evidence_dir / "Tablas-Individuales"
    figure = 26
    for heading, filename in (
        ("Inventario", "05_Inventario.csv"),
        ("Usuarios", "06_Usuarios.csv"),
        ("Recolecciones", "08_Recolecciones.csv"),
        ("DetallePedido", "09_DetallePedido.csv"),
    ):
        doc.add_heading(heading, level=2)
        doc.add_paragraph(
            f"Archivo de origen: {filename}. Método: Asistente de importación de SSMS. "
            "La primera imagen documenta el contenido cargado y la segunda resalta el resultado real de la consulta de verificación en SSMS."
        )
        add_picture(
            doc,
            individual_dir / f"{heading}_01_Archivo_Origen.png",
            f"Figura {figure}. Archivo {filename} con tres registros preparados para dbo.{heading}.",
        )
        figure += 1
        add_picture(
            doc,
            individual_dir / f"{heading}_02_Verificacion_SSMS.png",
            f"Figura {figure}. Resultado de SSMS: dbo.{heading} contiene tres registros de la carga.",
        )
        figure += 1
    add_picture(doc, evidence_dir / "02_Verificacion_5_tablas.png", f"Figura {figure}. Consulta conjunta final de las cinco tablas asignadas a Ramsés.")


def add_graphql(doc: Document, capture_dir: Path) -> None:
    doc.add_page_break()
    doc.add_heading("API GraphQL", level=1)
    doc.add_paragraph(
        "El backend GraphQL se ejecutó contra LavaFacil. Las operaciones protegidas utilizaron una cuenta administrativa temporal y un token de autorización. Las mutaciones invocan procedimientos almacenados y las conexiones SQL se seleccionan según el rol."
    )
    captures = (
        ("Inicio de sesión y rol", "01_Login_Administrador.png", "El login devuelve éxito, nombre de usuario, rol Administrador y token."),
        ("Consultas protegidas", "02_Consultas_Protegidas_10_Tablas.png", "Una sola operación consulta las diez tablas con respuesta HTTP 200."),
        ("Agregar servicio", "03_CRUD_Insertar_Servicio.png", "La mutación insertarServicio devuelve ejecución correcta."),
        ("Actualizar servicio", "04_CRUD_Actualizar_Servicio.png", "La mutación actualizarServicio modifica el registro temporal."),
        ("Eliminar servicio", "05_CRUD_Eliminar_Servicio.png", "La mutación eliminarServicio elimina el registro temporal y deja la base limpia."),
    )
    for n, (heading, filename, description) in enumerate(captures, 35):
        image = capture_dir / filename
        if not image.exists():
            continue
        doc.add_heading(heading, level=2)
        doc.add_paragraph(description)
        add_picture(doc, image, f"Figura {n}. {description}")


def add_conclusion(doc: Document) -> None:
    doc.add_heading("Conclusiones", level=1)
    doc.add_paragraph(
        "Las evidencias demuestran el uso de los dos mecanismos de carga requeridos, la existencia de los registros de prueba en las diez tablas y el funcionamiento del backend GraphQL con autenticación, autorización, consultas y operaciones CRUD respaldadas por procedimientos almacenados."
    )
    doc.add_heading("Archivos entregables", level=2)
    for item in (
        "Script final de SQL Server con estructuras, datos, procedimientos y seguridad.",
        "Archivos CSV originales utilizados en las cargas.",
        "Código fuente completo del backend GraphQL.",
        "Manual técnico en Word y PDF con las capturas de ejecución.",
    ):
        doc.add_paragraph(item, style="List Bullet")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--ramses-dir", type=Path, required=True)
    parser.add_argument("--graphql-dir", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.work_dir.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    doc = Document()
    section = doc.sections[0]
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.8)
    section.right_margin = Inches(0.8)
    configure_styles(doc)
    doc.core_properties.title = "Manual técnico del Proyecto 2 LavaFácil"
    doc.core_properties.subject = "Carga masiva con BCP y SSMS y API GraphQL"
    doc.core_properties.author = "José Ramsés Aguilar y Rachel Rosales"

    footer = section.footer
    add_page_field(footer.paragraphs[0])
    add_cover(doc)
    add_index(doc)
    add_requirements(doc)
    add_rachel_evidence(doc, args.evidence, args.work_dir)
    add_ramses_evidence(doc, args.ramses_dir)
    add_graphql(doc, args.graphql_dir)
    add_conclusion(doc)
    doc.save(args.output)


if __name__ == "__main__":
    main()
