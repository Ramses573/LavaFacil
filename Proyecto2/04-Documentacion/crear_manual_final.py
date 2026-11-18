from pathlib import Path
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT = Path(r"C:\Users\jm076\Desktop\LavaFacil")
P2 = ROOT / "Proyecto2"
CAP = P2 / "05-Capturas"
FINAL = CAP / "Finales_20261117"
REAL = CAP / "Reales_20261104"
GQL = CAP / "GraphQL"
DOC_DIR = P2 / "04-Documentacion"
OUT = DOC_DIR / "Manual_Proyecto2_LavaFacil_COMPLETO.docx"

NAVY = "123047"
TEAL = "159A9C"
MINT = "DFF4EF"
LIGHT = "F4F7FA"
GRAY = "52606D"
RED = "B42318"


def shade(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def set_cell_text(cell, text, bold=False, color="000000", size=9):
    cell.text = ""
    p = cell.paragraphs[0]
    r = p.add_run(text)
    r.bold = bold
    r.font.name = "Aptos"
    r.font.size = Pt(size)
    r.font.color.rgb = RGBColor.from_string(color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_header_footer(section):
    header = section.header.paragraphs[0]
    header.text = "LavaFácil  |  Proyecto 2 · Bases de Datos Avanzadas"
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    header.runs[0].font.size = Pt(8)
    header.runs[0].font.color.rgb = RGBColor.from_string(GRAY)
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("Universidad Latina de Costa Rica  ·  Noviembre 2026")
    run.font.size = Pt(8)
    run.font.color.rgb = RGBColor.from_string(GRAY)


def add_title(doc, text, subtitle=None):
    p = doc.add_paragraph()
    p.style = doc.styles["Title"]
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r = p.add_run(text)
    r.font.name = "Aptos Display"
    r.font.size = Pt(28)
    r.font.bold = True
    r.font.color.rgb = RGBColor.from_string(NAVY)
    if subtitle:
        s = doc.add_paragraph(subtitle)
        s.style = doc.styles["Subtitle"]
        s.runs[0].font.color.rgb = RGBColor.from_string(TEAL)


def add_h1(doc, text):
    p = doc.add_paragraph(style="Heading 1")
    r = p.add_run(text)
    r.font.color.rgb = RGBColor.from_string(NAVY)
    return p


def add_h2(doc, text):
    p = doc.add_paragraph(style="Heading 2")
    r = p.add_run(text)
    r.font.color.rgb = RGBColor.from_string(TEAL)
    return p


def add_body(doc, text, bold_prefix=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    if bold_prefix and text.startswith(bold_prefix):
        p.add_run(bold_prefix).bold = True
        p.add_run(text[len(bold_prefix):])
    else:
        p.add_run(text)
    return p


def add_bullet(doc, text):
    p = doc.add_paragraph(style="List Bullet")
    p.add_run(text)
    return p


def add_callout(doc, title, text, fill=MINT):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = table.cell(0, 0)
    shade(cell, fill)
    p = cell.paragraphs[0]
    r = p.add_run(title + "\n")
    r.bold = True
    r.font.color.rgb = RGBColor.from_string(NAVY)
    p.add_run(text)
    doc.add_paragraph()


def add_image(doc, path, caption, width=6.65):
    path = Path(path)
    if not path.exists():
        add_callout(doc, "Evidencia pendiente", f"No se encontró el archivo: {path.name}", "FDECEC")
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(path), width=Inches(width))
    cap = doc.add_paragraph(caption)
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.runs[0].italic = True
    cap.runs[0].font.size = Pt(8)
    cap.runs[0].font.color.rgb = RGBColor.from_string(GRAY)


def page_break(doc):
    doc.add_page_break()


doc = Document()
sec = doc.sections[0]
sec.top_margin = Inches(0.65)
sec.bottom_margin = Inches(0.65)
sec.left_margin = Inches(0.75)
sec.right_margin = Inches(0.75)
add_header_footer(sec)

styles = doc.styles
styles["Normal"].font.name = "Aptos"
styles["Normal"].font.size = Pt(10)
styles["Normal"].paragraph_format.line_spacing = 1.08
for name, size in (("Heading 1", 20), ("Heading 2", 14), ("Heading 3", 11)):
    styles[name].font.name = "Aptos Display"
    styles[name].font.size = Pt(size)
    styles[name].font.bold = True

# Portada
doc.add_paragraph("\n\n")
add_title(doc, "LavaFácil", "Proyecto 2 · Carga masiva y API GraphQL")
doc.add_paragraph("\n")
add_callout(
    doc,
    "Manual técnico y evidencias reales",
    "Documento consolidado de cargas mediante BCP y Asistente de importación de SSMS, verificación de datos, seguridad y operaciones GraphQL. No se emplean imágenes generadas por IA como evidencia.",
)
for line in [
    "Curso: Bases de Datos Avanzadas",
    "Integrantes: José Ramsés Aguilar y Rachel Rosales Picado",
    "Base de datos: LavaFacil",
    "Motor: Microsoft SQL Server 2022",
    "Fecha: noviembre de 2026",
]:
    p = doc.add_paragraph(line)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.runs[0].font.size = Pt(12)
page_break(doc)

# Índice
add_h1(doc, "Contenido")
items = [
    "1. Alcance y criterio de evidencia",
    "2. Distribución de métodos de carga",
    "3. Cargas BCP — Rachel (cinco tablas)",
    "4. Asistente SSMS — Ramsés (cinco tablas)",
    "5. Verificación de registros",
    "6. API GraphQL, seguridad y CRUD",
    "7. Pruebas, incidencias y soluciones",
    "8. Entregables y conclusión",
]
for item in items:
    add_bullet(doc, item)
add_callout(doc, "Convención", "Cada captura se identifica por el método real que muestra. No se usan pantallas de Bloc de notas como prueba de BCP ni del Asistente.")

page_break(doc)
add_h1(doc, "1. Alcance y criterio de evidencia")
add_body(doc, "El proyecto implementa carga masiva sobre diez tablas de LavaFacil y una API GraphQL con autenticación, autorización por roles, consultas y mutaciones CRUD respaldadas por procedimientos almacenados.")
add_body(doc, "Para que una captura sea válida debe mostrar directamente la herramienta utilizada: PowerShell con bcp.exe, el Asistente para importación y exportación de SQL Server, SSMS con resultados o Nitro con la operación GraphQL y su respuesta.")
add_callout(doc, "Criterio aplicado", "Se retiraron las imágenes de archivos abiertos en Bloc de notas porque solo muestran el contenido del CSV y no demuestran el método de carga.")

add_h1(doc, "2. Distribución de métodos de carga")
table = doc.add_table(rows=1, cols=4)
table.alignment = WD_TABLE_ALIGNMENT.CENTER
table.style = "Table Grid"
headers = ["Responsable", "Método", "Tablas", "Origen"]
for i, h in enumerate(headers):
    shade(table.rows[0].cells[i], NAVY)
    set_cell_text(table.rows[0].cells[i], h, True, "FFFFFF", 9)
rows = [
    ("Rachel", "BCP", "Clientes, Servicios, Promociones, Pedidos, Pagos", "CSV delimitado por ;"),
    ("Ramsés", "Asistente SSMS", "Empleados, Inventario, Usuarios, Recolecciones, DetallePedido", "CSV UTF-8 delimitado por ;"),
]
for row in rows:
    cells = table.add_row().cells
    for i, value in enumerate(row):
        set_cell_text(cells[i], value)
        if len(table.rows) % 2 == 0:
            shade(cells[i], LIGHT)

page_break(doc)
add_h1(doc, "3. Cargas BCP — Rachel")
add_body(doc, "Las cinco tablas asignadas a Rachel se cargaron con bcp.exe desde PowerShell contra una copia controlada del esquema. Cada ejecución muestra el comando, el archivo CSV, el mensaje real ‘3 rows copied’ y una comprobación posterior con sqlcmd.")
add_callout(doc, "Parámetros comunes", "Servidor .\\SQLEXPRESS · Base LavaFacil · autenticación integrada · separador ; · primera fila omitida con -F 2 · UTF-8 con -C 65001.")

bcp_items = [
    ("Clientes", "01_Clientes.csv", "BCP_Clientes_Terminal_Real.png"),
    ("Servicios", "03_Servicios.csv", "BCP_Servicios_Terminal_Real.png"),
    ("Promociones", "07_Promociones.csv", "BCP_Promociones_Terminal_Real.png"),
    ("Pedidos", "04_Pedidos.csv", "BCP_Pedidos_Terminal_Real.png"),
    ("Pagos", "10_Pagos.csv", "BCP_Pagos_Terminal_Real.png"),
]
for idx, (table_name, csv_name, image_name) in enumerate(bcp_items, 1):
    if idx > 1:
        page_break(doc)
    add_h2(doc, f"3.{idx} {table_name}")
    add_body(doc, f"Archivo de origen: {csv_name}. Método: BCP ejecutado desde PowerShell.")
    add_image(doc, FINAL / image_name, f"Evidencia BCP real de {table_name}: comando, tres filas copiadas y conteo verificado.")

page_break(doc)
add_h1(doc, "4. Asistente de importación de SSMS — Ramsés")
add_body(doc, "Las tablas de Ramsés se trabajaron con el Asistente para importación y exportación de SQL Server. La configuración común utiliza Flat File Source, UTF-8 (65001), punto y coma, nombres de columna en la primera fila y mapeo hacia tablas existentes.")
add_callout(doc, "Importante", "Las imágenes siguientes corresponden a pantallas reales del asistente y resultados reales de SSMS. No se presenta Bloc de notas como evidencia del método.")

add_h2(doc, "4.1 Empleados")
add_body(doc, "Archivo: 02_Empleados.csv. La pantalla general muestra el origen, la página de códigos UTF-8 y la primera fila como encabezado.")
add_image(doc, FINAL / "Asistente_Empleados_01_Origen.png", "Asistente SSMS: origen real de Empleados, UTF-8 y encabezados.")
page_break(doc)
add_h2(doc, "4.1 Empleados — delimitador y vista previa")
add_image(doc, FINAL / "Asistente_Empleados_02_VistaPrevia.png", "Asistente SSMS: delimitador punto y coma y vista previa de tres filas.")
page_break(doc)
add_h2(doc, "4.1 Empleados — resultado")
add_image(doc, DOC_DIR / "Evidencias-Ramses" / "01_Empleados_3_filas_transferidas.png", "Resultado real del asistente: tres filas transferidas a Empleados.")

page_break(doc)
add_h2(doc, "4.2 Inventario")
add_body(doc, "Archivo: 05_Inventario.csv. Se documentó el flujo completo: origen, columnas, mapeo con inserción de identidad, resultado y verificación.")
for path, cap in [
    (REAL / "Inventario_01_Origen_UTF8_Real.jpg", "Origen real de Inventario configurado en UTF-8."),
    (REAL / "Inventario_02_Columnas_Real.jpg", "Vista previa y delimitador de columnas de Inventario."),
    (REAL / "Inventario_03_Mapeo_Identidad_Real.jpg", "Mapeo hacia tabla existente con Enable identity insert."),
    (REAL / "Inventario_04_Asistente_3_Filas_Real.jpg", "Resultado real: tres filas transferidas por el asistente."),
    (REAL / "Inventario_05_Verificacion_Asistente_Real.jpg", "Verificación en SSMS de los registros importados."),
]:
    add_image(doc, path, cap)

for num, name, csv_name, verify in [
    (3, "Usuarios", "06_Usuarios.csv", "Usuarios_02_Verificacion_SSMS_Real.jpg"),
    (4, "Recolecciones", "08_Recolecciones.csv", "Recolecciones_02_Verificacion_SSMS_Real.jpg"),
    (5, "DetallePedido", "09_DetallePedido.csv", "DetallePedido_02_Verificacion_SSMS_Real.jpg"),
]:
    page_break(doc)
    add_h2(doc, f"4.{num} {name}")
    add_body(doc, f"Archivo: {csv_name}. Se aplicó la misma configuración documentada: UTF-8, delimitador punto y coma, encabezados en la primera fila y destino en la tabla existente de LavaFacil.")
    add_body(doc, "La evidencia conservada muestra el resultado en SQL Server después de la carga. Los valores vacíos de relaciones opcionales se interpretaron como NULL cuando correspondía.")
    add_image(doc, REAL / verify, f"Verificación real en SSMS de los tres registros cargados en {name}.")

page_break(doc)
add_h1(doc, "5. Verificación integral de datos")
add_body(doc, "La comprobación final confirma los identificadores 2001–2003 en las cinco tablas de Ramsés y tres registros en cada tabla BCP de Rachel. También se validaron las dependencias de llaves foráneas respetando el orden de carga.")
add_image(doc, REAL / "Verificacion_5_Tablas_Real.jpg", "Consulta real en SSMS para las cinco tablas de Ramsés.")
add_image(doc, REAL / "BCP_Verificacion_Terminal_Real.png", "Verificación real por terminal de las cargas BCP.")

page_break(doc)
add_h1(doc, "6. API GraphQL, seguridad y CRUD")
add_body(doc, "El backend GraphQL se ejecuta con ASP.NET Core y Hot Chocolate. Las operaciones protegidas requieren iniciar sesión y enviar el token en el encabezado Authorization. La capa de datos usa conexiones privadas fuera del repositorio y procedimientos almacenados para consultar y modificar registros.")

gql_items = [
    ("6.1 Inicio de sesión", "01_Login_Administrador.png", "Login real de administrador y emisión del token."),
    ("6.2 Consultas protegidas", "02_Consultas_Protegidas_10_Tablas.png", "Consulta real de las diez tablas con autorización."),
    ("6.3 Inserción", "03_CRUD_Insertar_Servicio.png", "Mutación real para insertar un servicio."),
    ("6.4 Actualización", "04_CRUD_Actualizar_Servicio.png", "Mutación real para actualizar el servicio."),
    ("6.5 Eliminación", "05_CRUD_Eliminar_Servicio.png", "Mutación real para eliminar el registro de prueba."),
]
for idx, (title, image_name, caption) in enumerate(gql_items):
    if idx:
        page_break(doc)
    add_h2(doc, title)
    add_image(doc, GQL / image_name, caption)

page_break(doc)
add_h1(doc, "7. Pruebas, incidencias y soluciones")
table = doc.add_table(rows=1, cols=3)
table.style = "Table Grid"
table.alignment = WD_TABLE_ALIGNMENT.CENTER
for i, h in enumerate(("Incidencia", "Causa", "Solución aplicada")):
    shade(table.rows[0].cells[i], NAVY)
    set_cell_text(table.rows[0].cells[i], h, True, "FFFFFF")
issues = [
    ("ConnectionString rechazada", "Proveedor o formato incompatible", "Se usó una cadena SQL Server válida y configuración privada por entorno."),
    ("Conversión decimal", "Separador o tipo inferido por el asistente", "Se revisó el mapeo y se ajustaron tipos antes de ejecutar."),
    ("Error de llave foránea", "Carga fuera del orden de dependencias", "Se cargaron primero tablas padre y luego Pedidos, Recolecciones y DetallePedido."),
    ("Acceso GraphQL denegado", "Token ausente o rol insuficiente", "Inicio de sesión, encabezado Bearer y prueba con rol Administrador/Empleado."),
    ("Certificado del proveedor local", "Cifrado obligatorio con certificado de desarrollo", "TrustServerCertificate para el entorno académico local; no se expone contraseña en el repositorio."),
]
for issue in issues:
    cells = table.add_row().cells
    for i, value in enumerate(issue):
        set_cell_text(cells[i], value)

page_break(doc)
add_h1(doc, "8. Entregables y conclusión")
for text in [
    "Script SQL completo con estructura, datos, procedimientos y seguridad.",
    "Archivos CSV originales usados en la carga masiva.",
    "Código fuente del backend GraphQL y colección de operaciones.",
    "Manual técnico DOCX y PDF con evidencias reales.",
    "Carpeta de capturas organizada por método y herramienta.",
]:
    add_bullet(doc, text)
add_callout(doc, "Conclusión", "LavaFacil cumple el objetivo de integrar carga masiva mediante BCP y el Asistente de SSMS con una API GraphQL protegida por roles. Las capturas incluidas corresponden a ejecuciones reales y permiten reproducir el proceso.")
add_h2(doc, "Referencia del enunciado")
add_body(doc, "Tarea programada 2.pdf, suministrada por la profesora del curso Bases de Datos Avanzadas. Consultada para verificar los requisitos de carga masiva, documentación, seguridad y GraphQL.")

doc.save(OUT)
print(OUT)
