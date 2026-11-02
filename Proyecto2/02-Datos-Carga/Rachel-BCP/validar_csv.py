"""Validación local: no importa drivers SQL, no ejecuta BCP ni modifica archivos."""
import csv
import re
import argparse
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path


RACHEL = {'Clientes', 'Servicios', 'Promociones', 'Pedidos', 'Pagos'}


def validate(root, scope='todos'):
    sql = (root / '01-Script/01_LavaFacil_Estructura_Datos_SP_Triggers.sql').read_text(encoding='utf-8-sig')
    errors, tables = [], {}
    for path in sorted((root / '02-Datos-Carga').glob('*/*.csv')):
        table = path.stem.split('_', 1)[1]
        with path.open(encoding='utf-8-sig', newline='') as source:
            reader = csv.DictReader(source, delimiter=';')
            rows = list(reader)
            header = reader.fieldnames
        schema = re.search(r'CREATE TABLE \[dbo\]\.\[' + table + r'\]\((.*?)CONSTRAINT', sql, re.S)
        if not schema:
            errors.append(f'{table}: tabla ausente en el script')
            continue
        columns = re.findall(r'^\s*\[(\w+)\] \[', schema[1], re.M)
        definitions = re.findall(r'^\s*\[(\w+)\] \[(\w+)\](\([^\n]*?\))? (?:IDENTITY\([^)]*\) )?(NOT NULL|NULL)', schema[1], re.M)
        if header != columns:
            errors.append(f'{table}: encabezado/orden diferente del esquema')
        if len(rows) != 3:
            errors.append(f'{table}: se esperaban 3 filas, hay {len(rows)}')
        ids = [r.get(columns[0]) for r in rows]
        if set(ids) != {'2001', '2002', '2003'} or len(ids) != len(set(ids)):
            errors.append(f'{table}: IDs diferentes de 2001–2003 o duplicados')
        for number, row in enumerate(rows, 2):
            if None in row or any(value is None for value in row.values()):
                errors.append(f'{table}:{number}: cantidad incorrecta de columnas')
                continue
            for column, kind, size, nullable in definitions:
                value = row.get(column)
                if value is None:
                    continue
                try:
                    if value == '':
                        if nullable == 'NOT NULL':
                            raise ValueError('valor requerido')
                    elif kind == 'int':
                        if not -(2**31) <= int(value) < 2**31:
                            raise ValueError('fuera del rango int')
                    elif kind == 'bit':
                        if value not in ('0', '1'):
                            raise ValueError('bit diferente de 0/1')
                    elif kind in ('date', 'datetime'):
                        datetime.strptime(value, '%Y-%m-%d' if kind == 'date' else '%Y-%m-%d %H:%M:%S')
                    elif kind == 'decimal':
                        precision, scale = map(int, re.findall(r'\d+', size))
                        amount = Decimal(value)
                        if not amount.is_finite() or abs(amount) >= Decimal(10) ** (precision - scale) or amount != amount.quantize(Decimal(10) ** -scale):
                            raise ValueError('decimal fuera de precisión/escala')
                    elif kind == 'varchar' and len(value) > int(size[1:-1]):
                        raise ValueError('texto demasiado largo')
                except (ValueError, InvalidOperation) as error:
                    errors.append(f'{table}:{number}: {column}: {error}')
        tables[table] = rows
        if scope == 'todos' or table in RACHEL:
            print(f'{table}: {len(rows)} filas revisadas')

    for table, column in re.findall(
        r'ALTER TABLE \[dbo\]\.\[(\w+)\] ADD  CONSTRAINT \[UQ_\w+\] UNIQUE NONCLUSTERED\s*\(\s*\[(\w+)\]', sql):
        values = [r.get(column, '').casefold() for r in tables.get(table, [])]
        if len(values) != len(set(values)):
            errors.append(f'{table}: valores duplicados en clave única {column}')

    # Extrae del esquema los CHECK que son listas de valores permitidos.
    for table, name, expression in re.findall(
        r'ALTER TABLE \[dbo\]\.\[(\w+)\].*?CONSTRAINT \[(CK_\w+)\] CHECK  \(\((.*?)\)\)', sql):
        pairs = re.findall(r"\[(\w+)\]='([^']*)'", expression)
        if not pairs or len({p[0] for p in pairs}) != 1 or ' AND ' in expression.upper():
            continue
        column, allowed = pairs[0][0], {p[1] for p in pairs}
        for row in tables.get(table, []):
            if row[column] not in allowed:
                errors.append(f'{table} ID {next(iter(row.values()))}: {column}={row[column]!r} incumple {name}; permitidos: {sorted(allowed)}')

    for child, column, parent, key in re.findall(
        r'ALTER TABLE \[dbo\]\.\[(\w+)\].*?FOREIGN KEY\(\[(\w+)\]\)\s*REFERENCES \[dbo\]\.\[(\w+)\] \(\[(\w+)\]\)', sql):
        available = {r[key] for r in tables.get(parent, [])}
        for row in tables.get(child, []):
            if row[column] and row[column] not in available:
                errors.append(f'{child}.{column}={row[column]} no existe en CSV {parent}')
    # CHECK numéricos y de fechas de las cinco tablas de Rachel.
    for table, rows in tables.items():
        for row in rows:
            checks = []
            try:
                if table == 'Servicios':
                    checks = [Decimal(row['PrecioBase']) >= 0, Decimal(row['CantidadIncluida']) > 0,
                              not row['PrecioAdicional'] or Decimal(row['PrecioAdicional']) >= 0]
                elif table == 'Promociones':
                    checks = [0 < Decimal(row['PorcentajeDescuento']) <= 100, row['FechaFin'] >= row['FechaInicio']]
                elif table == 'Pedidos':
                    checks = [Decimal(row['Total']) >= 0]
                elif table == 'Pagos':
                    checks = [Decimal(row['Monto']) > 0]
                if not all(checks):
                    errors.append(f'{table} ID {next(iter(row.values()))}: CHECK numérico/fechas incumplido')
            except (KeyError, InvalidOperation):
                errors.append(f'{table}: no se pudieron evaluar CHECK numéricos/fechas')

    # Verificación local de las relaciones monetarias que usarán los triggers.
    for order in tables.get('Pedidos', []):
        try:
            details = [r for r in tables.get('DetallePedido', []) if r['IdPedido'] == order['IdPedido']]
            total = sum((Decimal(r['Subtotal']) for r in details), Decimal(0))
            paid = sum((Decimal(r['Monto']) for r in tables.get('Pagos', [])
                        if r['IdPedido'] == order['IdPedido'] and r['EstadoPago'] == 'Pagado'), Decimal(0))
            if total != Decimal(order['Total']) or paid > total:
                errors.append(f"Pedidos ID {order['IdPedido']}: total/detalle/pagos incompatibles")
        except (KeyError, InvalidOperation):
            errors.append('Pedidos: no se pudieron comprobar importes relacionados')
    return errors if scope == 'todos' else [e for e in errors if e.split(':')[0].split()[0].split('.')[0] in RACHEL]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--alcance', choices=['todos', 'rachel'], default='todos')
    args = parser.parse_args()
    issues = validate(Path(__file__).resolve().parents[2], args.alcance)
    for issue in issues:
        print('ERROR:', issue)
    print(f'{len(issues)} incompatibilidades. No se comprobó la base real ni se ejecutó una carga.')
    raise SystemExit(1 if issues else 0)
