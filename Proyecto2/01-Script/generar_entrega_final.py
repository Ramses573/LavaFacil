from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).parents[1]
SCRIPT_DIR = ROOT / "01-Script"
DATA_DIR = ROOT / "02-Datos-Carga"
OUTPUT = SCRIPT_DIR / "00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql"

FILES = (
    ("Clientes", DATA_DIR / "Rachel-BCP" / "01_Clientes.csv"),
    ("Empleados", DATA_DIR / "Ramses-SSMS" / "02_Empleados.csv"),
    ("Servicios", DATA_DIR / "Rachel-BCP" / "03_Servicios.csv"),
    ("Promociones", DATA_DIR / "Rachel-BCP" / "04_Promociones.csv"),
    ("Inventario", DATA_DIR / "Ramses-SSMS" / "05_Inventario.csv"),
    ("Usuarios", DATA_DIR / "Ramses-SSMS" / "06_Usuarios.csv"),
    ("Pedidos", DATA_DIR / "Rachel-BCP" / "07_Pedidos.csv"),
    ("Recolecciones", DATA_DIR / "Ramses-SSMS" / "08_Recolecciones.csv"),
    ("DetallePedido", DATA_DIR / "Ramses-SSMS" / "09_DetallePedido.csv"),
    ("Pagos", DATA_DIR / "Rachel-BCP" / "10_Pagos.csv"),
)

NUMERIC = {
    "IdCliente", "IdEmpleado", "IdServicio", "IdPromocion", "IdInventario", "IdUsuario",
    "IdPedido", "IdRecoleccion", "IdDetalle", "IdPago", "Activo", "Activa", "Cantidad",
    "CantidadMinima", "CantidadIncluida", "PrecioBase", "PrecioAdicional", "PorcentajeDescuento",
    "Total", "Monto", "MontoAdicional", "Subtotal",
}
PRIMARY_KEYS = {
    "Clientes": "IdCliente", "Empleados": "IdEmpleado", "Servicios": "IdServicio",
    "Promociones": "IdPromocion", "Inventario": "IdInventario", "Usuarios": "IdUsuario",
    "Pedidos": "IdPedido", "Recolecciones": "IdRecoleccion", "DetallePedido": "IdDetalle",
    "Pagos": "IdPago",
}


def literal(column: str, value: str) -> str:
    if value == "":
        return "NULL"
    if column in NUMERIC:
        return value
    return "N'" + value.replace("'", "''") + "'"


def block(table: str, path: Path) -> str:
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter=";"))
    columns = list(rows[0].keys())
    pk = PRIMARY_KEYS[table]
    lines = [
        f"PRINT N'Cargando datos del Proyecto 2 en dbo.{table}';",
        f"SET IDENTITY_INSERT dbo.[{table}] ON;",
    ]
    for row in rows:
        values = ", ".join(literal(column, row[column]) for column in columns)
        names = ", ".join(f"[{column}]" for column in columns)
        lines.extend(
            (
                f"IF NOT EXISTS (SELECT 1 FROM dbo.[{table}] WHERE [{pk}] = {row[pk]})",
                f"    INSERT dbo.[{table}] ({names}) VALUES ({values});",
            )
        )
    lines.extend((f"SET IDENTITY_INSERT dbo.[{table}] OFF;", "GO", ""))
    return "\n".join(lines)


header = """/*
    LavaFácil - Proyecto 2 - Script único de entrega
    Ejecutar directamente desde SQL Server Management Studio.

    Contenido:
      1. Estructura, restricciones, datos base, triggers y procedimientos almacenados.
      2. Mejoras del aplicativo.
      3. Treinta registros del Proyecto 2 provenientes de los diez archivos CSV.
      4. Roles y permisos de GraphQL.

    Las contraseñas de los logins SQL no se incluyen. Los logins deben crearse de forma privada.
*/
"""

verification = """
PRINT N'Proyecto 2 instalado y verificado.';
GO
"""

base = (SCRIPT_DIR / "01_LavaFacil_Estructura_Datos_SP_Triggers.sql").read_text(encoding="utf-8-sig")
base = base[base.index("USE [master]") :]
app = (SCRIPT_DIR / "02_Mejoras_Aplicativo.sql").read_text(encoding="utf-8-sig")
security = (SCRIPT_DIR / "03_Seguridad_GraphQL.sql").read_text(encoding="utf-8-sig")
checks = (SCRIPT_DIR / "04_Verificacion_Proyecto2.sql").read_text(encoding="utf-8-sig")

parts = (
    header,
    "\n/* Estructura, datos base, restricciones, triggers y procedimientos */\n",
    base,
    "\n/* Procedimientos complementarios del aplicativo */\n",
    app,
    "\nUSE [LavaFacil];\nGO\n",
    "\n/* Datos provenientes de los diez archivos CSV del Proyecto 2 */\n",
    "\n".join(block(table, path) for table, path in FILES),
    "\n/* Roles y permisos de GraphQL */\n",
    security,
    "\n/* Verificación final */\n",
    checks,
    verification,
)
OUTPUT.write_text("\n".join(parts), encoding="utf-8-sig")
