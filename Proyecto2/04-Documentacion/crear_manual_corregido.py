from __future__ import annotations

import argparse
import re
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
    number = len(doc.inline_shapes) + 1
    caption = re.sub(r'^Figura \d+\.', f'Figura {number}.', caption)
    if doc.paragraphs and doc.paragraphs[-1].style.name != 'Caption':
        doc.paragraphs[-1].paragraph_format.keep_with_next = True
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
        borders = style.element.xpath('./w:pPr/w:pBdr')
        for border in borders:
            border.getparent().remove(border)
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
        (6, "Usuarios", "Ramsés — BCP en repetición verificada"),
        (7, "Pedidos", "Rachel — BCP"),
        (8, "Recolecciones", "Ramsés — BCP en repetición verificada"),
        (9, "DetallePedido", "Ramsés — BCP en repetición verificada"),
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
    doc.add_paragraph("Las siguientes pantallas proceden del programa real. Se conserva la evidencia original del asistente de Empleados y se agregan capturas directas de los CSV y consultas realizadas el 4 de noviembre de 2026 en la instancia local DESKTOP-EEOH9C5\\SQLEXPRESS. Las consultas documentan el estado de los datos; no reconstruyen el recorrido histórico de importación.")
    doc.add_heading("Empleados", level=2)
    doc.add_paragraph("Archivo de origen: 02_Empleados.csv. Método: Asistente de importación de SSMS.")
    add_picture(doc, evidence_dir / "01_Empleados_3_filas_transferidas.png", "Figura 25. Resultado exitoso del asistente: tres filas transferidas a Empleados.")
    real_dir = evidence_dir.parents[1] / "05-Capturas" / "Reales_20261104"
    figure = 26
    for heading, filename in (
        ("Inventario", "05_Inventario.csv"),
        ("Usuarios", "06_Usuarios.csv"),
        ("Recolecciones", "08_Recolecciones.csv"),
        ("DetallePedido", "09_DetallePedido.csv"),
    ):
        doc.add_heading(heading, level=2)
        doc.add_paragraph(f"Archivo de origen: {filename}. El archivo original se abrió en Bloc de notas y la consulta se ejecutó en SSMS contra dbo.{heading}. Ambos resultados se muestran sin reconstrucciones ni rótulos agregados a la imagen.").paragraph_format.keep_with_next = True
        add_picture(
            doc,
            real_dir / f"{heading}_Archivo_Original_Real.jpg",
            f"Figura {figure}. Archivo {filename} con tres registros preparados para dbo.{heading}.",
        )
        figure += 1
        add_picture(
            doc,
            real_dir / f"{heading}_02_Verificacion_SSMS_Real.jpg",
            f"Figura {figure}. Resultado de SSMS: dbo.{heading} contiene tres registros de la carga.",
        )
        figure += 1
        if heading in ("Usuarios", "Recolecciones", "DetallePedido"):
            doc.add_paragraph("Se repitió una carga real con BCP en la tabla auxiliar vacía EvidenciaSSMS20261104." + heading + ". La salida original del proceso se guardó mediante redirección de stdout y se abrió en Bloc de notas para la captura. No es una captura de la consola ni un resultado dibujado. La tabla dbo se conservó y se verificó por separado.")
            doc.add_paragraph(f'bcp LavaFacil.EvidenciaSSMS20261104.{heading} in "C:\\Users\\jm076\\Desktop\\LavaFacil\\Proyecto2\\02-Datos-Carga\\Ramses-SSMS\\{filename}" -S .\\SQLEXPRESS -T -c -C 65001 -t ";" -r 0x0a -F 2 -E -k -b 1000 -m 1')
            add_picture(doc, real_dir / f"{heading}_BCP_Salida_Real.jpg", f"Figura 1. Salida original de BCP de {heading}, con tres filas copiadas, abierta en Bloc de notas.")
    add_picture(doc, real_dir / "Verificacion_5_Tablas_Real.jpg", f"Figura {figure}. Consulta conjunta real de las cinco tablas asignadas a Ramsés.")
    add_picture(doc, real_dir / "BCP_Verificacion_SQLCMD_Real.jpg", "Figura 1. Salida original de SQLCMD verificando los IDs 2001 a 2003 y valores NULL de las tres tablas auxiliares cargadas con BCP.")
    doc.add_heading("Repetición del asistente con Inventario", level=2)
    doc.add_paragraph("Se repitió la importación en EvidenciaSSMS20261104.Inventario, una tabla auxiliar, para conservar los registros de dbo. El asistente transfirió tres filas. Las columnas Cantidad y CantidadMinima se recibieron como texto después del error de conversión y se validaron mediante TRY_CONVERT. El proveedor generó IDs auxiliares 1 a 3 y presentó una diferencia de codificación en un acento; esta repetición no se presenta como una recarga idéntica de dbo.Inventario.")
    for filename, text in (
        ("Inventario_01_Origen_UTF8_Real.jpg", "Origen real con UTF-8 y encabezados seleccionados."),
        ("Inventario_02_Columnas_Real.jpg", "Vista previa real y delimitador punto y coma."),
        ("Inventario_03_Mapeo_Identidad_Real.jpg", "Mapeo real hacia tabla auxiliar e inserción de identidad seleccionada."),
        ("Inventario_04_Asistente_3_Filas_Real.jpg", "Resultado real del asistente con tres filas transferidas y cero errores."),
        ("Inventario_05_Verificacion_Asistente_Real.jpg", "Verificación real de los decimales en la tabla auxiliar; se observan los IDs generados y la diferencia de codificación."),
    ):
        add_picture(doc, real_dir / filename, f"Figura 1. {text}")
    doc.add_page_break()
    doc.add_heading("Carga real mediante BULK INSERT", level=1)
    doc.add_paragraph("Se ejecutó BULK INSERT en SSMS para importar el CSV original de Inventario hacia #InventarioBulk, tabla temporal creada con la estructura de dbo.Inventario. Esta prueba demuestra el método sin duplicar los IDs existentes en la tabla del proyecto. Se usaron FIRSTROW=2, FIELDTERMINATOR punto y coma, ROWTERMINATOR 0x0a, CODEPAGE 65001, KEEPIDENTITY y KEEPNULLS.")
    for filename, text in (
        ("Bulk_01_Instruccion_Real.jpg", "Instrucción BULK INSERT real preparada en SSMS."),
        ("Bulk_02_Mensajes_Real.jpg", "Mensajes reales de ejecución de BULK INSERT."),
        ("Bulk_03_Resultados_Real.jpg", "Consulta real de las tres filas importadas por BULK INSERT."),
    ):
        add_picture(doc, real_dir / filename, f"Figura 1. {text}")
    doc.add_heading("Errores encontrados y tratamiento", level=1)
    doc.add_paragraph("El proveedor .NET rechazó inicialmente la conexión porque la propiedad ConnectionString no estaba inicializada. Se reingresó y confirmó la cadena completa con autenticación Windows e Initial Catalog=LavaFacil. Posteriormente el asistente falló al convertir Cantidad a decimal. Se conservó el dato en columnas de texto de una tabla auxiliar y se comprobó su conversión con TRY_CONVERT. Las capturas siguientes son los errores observados, no ejemplos recreados.")
    add_picture(doc, real_dir / "Error_ConnectionString_Asistente_Real.jpg", "Figura 1. Error real de ConnectionString del asistente.")
    add_picture(doc, real_dir / "Error_Decimal_Asistente_Real.jpg", "Figura 1. Error real de conversión de Cantidad.")


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
        if n > 35:
            doc.add_page_break()
        doc.add_heading(heading, level=2)
        doc.add_paragraph(description).paragraph_format.keep_with_next = True
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
