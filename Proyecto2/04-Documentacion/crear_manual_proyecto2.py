from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.section import WD_SECTION
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.style import WD_STYLE_TYPE
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "Manual_Proyecto2_LavaFacil.docx"
NAVY = "114B5F"
TEAL = "2E8B83"
PALE = "EAF4F3"
GRAY = "F3F5F6"
BORDER = "D9D9D9"

def shade(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)

def margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc.get_or_add_tcPr()
    mar = tc.first_child_found_in("w:tcMar")
    if mar is None:
        mar = OxmlElement("w:tcMar")
        tc.append(mar)
    for name, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = mar.find(qn(f"w:{name}"))
        if node is None:
            node = OxmlElement(f"w:{name}")
            mar.append(node)
        node.set(qn("w:w"), str(value)); node.set(qn("w:type"), "dxa")

def borders(table):
    tbl_pr = table._tbl.tblPr
    b = tbl_pr.find(qn("w:tblBorders"))
    if b is None:
        b = OxmlElement("w:tblBorders"); tbl_pr.append(b)
    for edge in ("top","left","bottom","right","insideH","insideV"):
        e = OxmlElement(f"w:{edge}"); e.set(qn("w:val"),"single"); e.set(qn("w:sz"),"4"); e.set(qn("w:color"),BORDER); b.append(e)

def set_font(run, name="Aptos", size=10.5, bold=False, color="000000"):
    run.font.name=name; run.font.size=Pt(size); run.bold=bold; run.font.color.rgb=RGBColor.from_string(color)
    run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:hAnsi"), name)

def add_heading(doc, text, level=1):
    p=doc.add_paragraph(style=f"Heading {level}"); p.paragraph_format.keep_with_next=True
    r=p.add_run(text); return p

def add_body(doc, text, bold_lead=None):
    p=doc.add_paragraph(style="Body Text")
    if bold_lead and text.startswith(bold_lead):
        set_font(p.add_run(bold_lead), bold=True); set_font(p.add_run(text[len(bold_lead):]))
    else: set_font(p.add_run(text))
    return p

def add_bullets(doc, items):
    for item in items:
        p=doc.add_paragraph(style="List Bullet"); set_font(p.add_run(item))

def add_table(doc, headers, rows, widths=None):
    table=doc.add_table(rows=1, cols=len(headers)); table.alignment=WD_TABLE_ALIGNMENT.CENTER; table.autofit=False
    borders(table)
    for i,h in enumerate(headers):
        c=table.rows[0].cells[i]; shade(c,NAVY); margins(c); c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p=c.paragraphs[0]; p.alignment=WD_ALIGN_PARAGRAPH.CENTER; set_font(p.add_run(h), size=9.5, bold=True, color="FFFFFF")
        if widths: c.width=Inches(widths[i])
    tr_pr = table.rows[0]._tr.get_or_add_trPr()
    repeat = OxmlElement("w:tblHeader"); repeat.set(qn("w:val"), "true"); tr_pr.append(repeat)
    for idx,row in enumerate(rows):
        cells=table.add_row().cells
        for i,value in enumerate(row):
            c=cells[i]; margins(c); c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if idx%2: shade(c,GRAY)
            p=c.paragraphs[0]; p.paragraph_format.space_after=Pt(0); set_font(p.add_run(str(value)), size=9)
            if widths: c.width=Inches(widths[i])
    doc.add_paragraph().paragraph_format.space_after=Pt(2)
    return table

doc=Document()
sec=doc.sections[0]; sec.top_margin=Inches(.75); sec.bottom_margin=Inches(.7); sec.left_margin=Inches(.85); sec.right_margin=Inches(.85)
styles=doc.styles
styles["Normal"].font.name="Aptos"; styles["Normal"].font.size=Pt(10.5); styles["Normal"].font.color.rgb=RGBColor(0,0,0)
styles["Title"].font.name="Aptos Display"; styles["Title"].font.size=Pt(30); styles["Title"].font.bold=True; styles["Title"].font.color.rgb=RGBColor(0,0,0)
title_ppr = styles["Title"]._element.get_or_add_pPr()
title_border = title_ppr.find(qn("w:pBdr"))
if title_border is not None: title_ppr.remove(title_border)
for level,size in ((1,18),(2,14),(3,11)):
    s=styles[f"Heading {level}"]; s.font.name="Aptos Display"; s.font.size=Pt(size); s.font.bold=True; s.font.color.rgb=RGBColor(0,0,0)
    s.paragraph_format.space_before=Pt(14 if level==1 else 10); s.paragraph_format.space_after=Pt(6)
styles["Body Text"].paragraph_format.space_after=Pt(6); styles["Body Text"].paragraph_format.line_spacing=1.08

# Cover
p=doc.add_paragraph(); p.paragraph_format.space_before=Pt(90); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
set_font(p.add_run("LavaFácil"), name="Aptos Display", size=36, bold=True, color=NAVY)
p=doc.add_paragraph(style="Title"); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.add_run("Manual de implementación del Proyecto 2")
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; set_font(p.add_run("Carga masiva y API GraphQL sobre SQL Server"), size=16, color=TEAL)
p=doc.add_paragraph(); p.paragraph_format.space_before=Pt(90); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
set_font(p.add_run("Bases de Datos Avanzadas\n"), size=12, bold=True)
set_font(p.add_run("Rachel Rosales Picado\nJosé Ramses Aguilar\n"), size=11)
set_font(p.add_run("Octubre de 2026"), size=11)
doc.add_page_break()

add_heading(doc,"Propósito y resultado esperado",1)
add_body(doc,"Este manual explica cómo cargar datos en las diez tablas de LavaFacil mediante BCP y el Asistente de importación de SQL Server Management Studio, y cómo ejecutar el backend GraphQL que consume exclusivamente procedimientos almacenados. El resultado esperado es una base sincronizada, cargas comprobables y una API con autenticación por rol y operaciones CRUD para cada tabla.")
add_heading(doc,"Contenido del paquete",2)
add_table(doc,["Carpeta","Contenido"],[
    ("01-Script","Estructura, datos, procedimientos, triggers, seguridad y verificación"),
    ("02-Datos-Carga","Diez archivos CSV con datos ficticios y relaciones válidas"),
    ("03-Backend-GraphQL","Código ASP.NET Core 9, Hot Chocolate y SqlClient"),
    ("04-Documentacion","Guías de instalación, pruebas y evidencias"),
    ("05-Capturas","Ubicaciones para guardar evidencia real")], [1.65,4.7])
add_heading(doc,"Arquitectura",2)
add_body(doc,"El cliente envía una consulta o mutación al endpoint /graphql. Hot Chocolate resuelve la operación, valida el token y selecciona una cadena de conexión según el rol. DbGateway abre la conexión SQL y ejecuta el procedimiento almacenado correspondiente. La cadena incluye Initial Catalog y Failover Partner para que una conexión nueva pueda alcanzar al servidor que tenga el rol principal.")
add_bullets(doc,["Invitado: login y consultas públicas de servicios y promociones.","Cliente: conexión independiente para futuras operaciones restringidas a su información.","Empleado o Administrador: consultas internas y mantenimiento CRUD."])

add_heading(doc,"Distribución del trabajo",1)
add_table(doc,["Responsable","Tablas","Método"],[
    ("Rachel","Clientes, Servicios, Promociones, Pedidos y Pagos","BCP"),
    ("Ramses","Empleados, Inventario, Usuarios, Recolecciones y DetallePedido","Asistente de SSMS")], [1.2,3.8,1.2])
add_body(doc,"La coordinación es obligatoria porque varias tablas dependen de registros cargados por la otra persona. Ambos deben trabajar contra el servidor que tenga el rol principal y confirmar que el mirroring vuelva a SYNCHRONIZED después de cada bloque de carga.")
doc.add_page_break()
add_heading(doc,"Orden de carga",2)
rows=[(1,"Clientes","Rachel"),(2,"Empleados","Ramses"),(3,"Servicios","Rachel"),(4,"Promociones","Rachel"),(5,"Inventario","Ramses"),(6,"Usuarios","Ramses"),(7,"Pedidos","Rachel"),(8,"Recolecciones","Ramses"),(9,"DetallePedido","Ramses"),(10,"Pagos","Rachel")]
add_table(doc,["Paso","Tabla","Responsable"],rows,[.7,3.2,2.2])

add_heading(doc,"Carga mediante BCP",1)
add_body(doc,"Rachel abre PowerShell en la carpeta Rachel-BCP y ejecuta cada comando cuando corresponda según el orden anterior. BCP solicita la contraseña si se utiliza -U sin escribir -P. Esto evita dejar credenciales visibles en el historial o el repositorio.")
add_body(doc,"Parámetros importantes. -F 2 omite el encabezado; -E conserva los valores identity; -C 65001 usa UTF-8; -t\";\" usa punto y coma como delimitador.","Parámetros importantes.")
add_bullets(doc,["Guardar una captura del archivo fuente.","Guardar una captura del comando y la cantidad de filas copiadas.","Ejecutar SELECT sobre los IDs 2001 a 2003 y capturar el resultado.","Documentar el mensaje exacto si ocurre un error y la solución aplicada."])
add_heading(doc,"Carga mediante el Asistente de SSMS",1)
for n,text in enumerate(["Clic derecho en LavaFacil y seleccionar Tareas e Importar datos.","Elegir Flat File Source, el CSV, codificación UTF-8 y delimitador punto y coma.","Seleccionar la instancia principal y la base LavaFacil como destino.","Mapear hacia la tabla existente y habilitar la conservación de identity.","En Usuarios, mapear los campos vacíos de las llaves opcionales como NULL.","Ejecutar, comprobar tres filas transferidas y consultar los IDs 2001 a 2003."],1):
    add_body(doc,f"{n}. {text}")

add_heading(doc,"Preparación de seguridad",1)
add_body(doc,"Las tres cuentas SQL se crean en ambas instancias con los mismos SID. Después se ejecuta 03_Seguridad_GraphQL.sql en LavaFacil. El script crea los roles gql_invitado, gql_cliente y gql_empleado, incorpora los usuarios existentes y concede EXECUTE únicamente sobre los procedimientos necesarios.")
add_body(doc,"No se deben incluir contraseñas, tokens, certificados privados ni archivos appsettings.Development.json en la entrega pública.","No se deben incluir")
add_heading(doc,"Configuración del backend",2)
add_bullets(doc,["Copiar appsettings.Development.example.json como appsettings.Development.json.","Completar las cadenas Invitado, Cliente y Empleado.","Conservar Initial Catalog=LavaFacil cuando se configure Failover Partner.","Ejecutar dotnet restore, dotnet build -c Release y dotnet run.","Abrir la URL indicada y agregar /graphql para entrar a Nitro."])

add_heading(doc,"Pruebas de GraphQL",1)
add_body(doc,"La API expone once consultas y treinta y una mutaciones: una de login y tres operaciones de mantenimiento para cada una de las diez tablas. El proyecto fue compilado sin errores ni advertencias y el endpoint respondió la consulta de estado durante la validación local.")
add_heading(doc,"Secuencia de demostración",2)
add_bullets(doc,["Ejecutar la consulta pública de servicios y promociones sin token.","Ejecutar login y mostrar el rol devuelto sin revelar el token completo.","Agregar Authorization: Bearer TOKEN en los encabezados de Nitro.","Consultar las diez tablas.","Insertar un registro de prueba mediante una mutación.","Consultar y actualizar ese registro.","Eliminar el registro y comprobar que ya no aparece.","Mostrar en SQL Server Profiler o en el código que el resolver llama un procedimiento almacenado."])
add_heading(doc,"Prueba de failover",2)
add_body(doc,"Antes de conmutar, ambos servidores deben estar encendidos, conectados por Tailscale y en estado SYNCHRONIZED. La persona conectada al principal ejecuta el failover coordinado. Después se espera el cambio de roles y se repite una consulta GraphQL. Una conexión nueva debe usar el Failover Partner. Si aparece Login failed, se verifican el login, el modo mixto, el SID y el usuario de base de datos en la nueva instancia principal.")

doc.add_page_break()
add_heading(doc,"Evidencias requeridas",1)
add_table(doc,["Área","Evidencia mínima"],[
    ("Base de datos","Tablas, procedimientos, triggers y conteos"),
    ("BCP","Cinco archivos, cinco ejecuciones y cinco consultas"),
    ("Asistente SSMS","Cinco mapeos, cinco resultados y cinco consultas"),
    ("GraphQL","Compilación, login, consultas y ciclo CRUD"),
    ("Seguridad","Roles y permisos sin mostrar secretos"),
    ("Alta disponibilidad","SYNCHRONIZED y consulta después del failover"),
    ("Errores","Mensaje real, causa, solución y resultado")], [1.7,4.6])
add_body(doc,"Las capturas se insertan después de ejecutar las pruebas reales. No deben inventarse resultados ni estados. Cada imagen debe tener un título, una explicación breve y datos suficientes para identificar la tabla u operación.")

add_heading(doc,"Verificación y entrega",1)
add_bullets(doc,["Ejecutar 04_Verificacion_Proyecto2.sql y revisar los conteos.","Confirmar que los CSV originales estén incluidos.","Confirmar que el backend compile desde una copia limpia del repositorio.","Regenerar en SSMS el script final con esquema y datos después de las cargas.","Eliminar del paquete cualquier contraseña, token, certificado privado o respaldo innecesario.","Entregar en Teams antes del miércoles 4 de noviembre de 2026 a las 9:00 a. m."])
add_heading(doc,"Referencias",1)
add_body(doc,"ChilliCream. Hot Chocolate documentation. Getting started with GraphQL in .NET Core. https://chillicream.com/docs/hotchocolate/get-started-with-graphql-in-net-core")
add_body(doc,"Microsoft. bcp utility documentation. https://learn.microsoft.com/sql/tools/bcp-utility")
add_body(doc,"Microsoft. Import and Export Wizard documentation. https://learn.microsoft.com/sql/integration-services/import-export-data/start-the-sql-server-import-and-export-wizard")

# Footer
for section in doc.sections:
    p=section.footer.paragraphs[0]; p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    set_font(p.add_run("LavaFácil  |  Proyecto 2  |  Bases de Datos Avanzadas"), size=8, color="666666")

doc.core_properties.title="Manual de implementación del Proyecto 2 LavaFácil"
doc.core_properties.subject="Carga masiva y API GraphQL"
doc.core_properties.author="Rachel Rosales Picado y José Ramses Aguilar"
doc.save(OUT)
print(OUT)
