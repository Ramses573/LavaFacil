import json
import re
import unicodedata
from pathlib import Path

BASE = Path(__file__).parent
COLLECTION = BASE / "LavaFacil_GraphQL.postman_collection.json"
OUTPUT = BASE / "LavaFacil_Operaciones_GraphQL.graphql"


def identifier(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    words = re.findall(r"[A-Za-z0-9]+", normalized)
    value = "".join(word[:1].upper() + word[1:] for word in words)
    if not value or value[0].isdigit():
        value = "Operacion" + value
    return value


def walk(items, folders=()):
    for item in items:
        if item.get("item"):
            yield from walk(item["item"], folders + (item["name"],))
        else:
            yield folders, item


def make_standalone(query: str, operation_name: str) -> str:
    base_values = {
        "idClienteBase": "2001",
        "idEmpleadoBase": "2001",
        "idServicioBase": "2001",
        "idPedidoBase": "2001",
    }
    for key, value in base_values.items():
        query = query.replace("{{" + key + "}}", value)

    variables = sorted(set(re.findall(r"\{\{(id[A-Za-z]+Demo)\}\}", query)))
    for variable in variables:
        query = query.replace("{{" + variable + "}}", "$" + variable)

    if re.match(r"^\s*(query|mutation)\s*\{", query):
        kind = re.match(r"^\s*(query|mutation)", query).group(1)
        declaration = ""
        if variables:
            declaration = "(" + ", ".join(f"${name}: Int!" for name in variables) + ")"
        query = re.sub(
            r"^\s*(query|mutation)\s*\{",
            f"{kind} {operation_name}{declaration} {{",
            query,
            count=1,
        )
    return query.strip()


data = json.loads(COLLECTION.read_text(encoding="utf-8"))
parts = [
    "# LavaFacil - catálogo completo de operaciones GraphQL",
    "# Generado desde la colección Postman del Proyecto 2.",
    "# Los IDs base 2001 corresponden a los registros de prueba cargados.",
    "# Para actualizar o eliminar, ejecute primero la consulta que localiza el registro insertado",
    "# y suministre el ID solicitado en el panel Variables de Nitro.",
    "",
]

count = 0
for folders, item in walk(data["item"]):
    query = item.get("request", {}).get("body", {}).get("graphql", {}).get("query")
    if not query:
        continue
    count += 1
    label = " / ".join((*folders, item["name"]))
    op_name = identifier(label)
    parts.append("# " + label)
    parts.append(make_standalone(query, op_name))
    parts.append("")

OUTPUT.write_text("\n".join(parts), encoding="utf-8")
print(f"{OUTPUT}\nOperaciones: {count}")
