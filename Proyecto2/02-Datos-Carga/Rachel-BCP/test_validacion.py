"""Pruebas de regresión en copias temporales; nunca modifican los CSV originales."""
import contextlib
import io
import re
import shutil
import tempfile
import unittest
from pathlib import Path
from validar_csv import validate

ROOT = Path(__file__).resolve().parents[2]


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / '01-Script', self.root / '01-Script')
        shutil.copytree(ROOT / '02-Datos-Carga', self.root / '02-Datos-Carga')

    def errors(self, scope='rachel'):
        with contextlib.redirect_stdout(io.StringIO()):
            return validate(self.root, scope)

    def replace(self, file, old, new):
        path = self.root / '02-Datos-Carga/Rachel-BCP' / file
        path.write_text(path.read_text(encoding='utf-8').replace(old, new), encoding='utf-8')

    def test_todos_los_csv_son_compatibles(self):
        self.assertEqual(self.errors(), [])
        self.assertEqual(self.errors('todos'), [])

    def test_metodo_no_permitido(self):
        self.replace('10_Pagos.csv', ';SINPE Movil;', ';Tarjeta;')
        self.assertTrue(any('CK_Pagos_Metodo' in e for e in self.errors()))

    def test_fk_inexistente(self):
        self.replace('04_Promociones.csv', '2001;2001;', '2001;9999;')
        self.assertTrue(any('no existe' in e for e in self.errors()))

    def test_decimal_fuera_de_escala(self):
        self.replace('03_Servicios.csv', ';1800.00;', ';1800.001;')
        self.assertTrue(any('precisión/escala' in e for e in self.errors()))

    def test_clave_unica_duplicada(self):
        self.replace('01_Clientes.csv', 'DEMO-P2-C002', 'DEMO-P2-C001')
        self.assertTrue(any('clave única Cedula' in e for e in self.errors()))

    def test_trigger_sobrepago(self):
        self.replace('10_Pagos.csv', ';3600.00;', ';9999.00;')
        self.assertTrue(any('total/detalle/pagos' in e for e in self.errors()))

    def test_contratos_procedimientos_rachel(self):
        sql = (ROOT / '01-Script/01_LavaFacil_Estructura_Datos_SP_Triggers.sql').read_text(encoding='utf-8-sig')
        backend = ROOT / '03-Backend-GraphQL/LavaFacil.GraphQL'
        mutation = (backend / 'GraphQL/Mutation.cs').read_text(encoding='utf-8-sig')
        for singular in ['Cliente', 'Servicio', 'Promocion', 'Pedido', 'Pago']:
            for action in ['Insertar', 'Actualizar', 'Eliminar']:
                procedure = action + singular
                header = re.search(r'CREATE\s+PROCEDURE \[dbo\]\.\[' + procedure + r'\](.*?)\bAS\b', sql, re.S)[1]
                expected = set(re.findall(r'@(\w+)', header))
                line = next(line for line in mutation.splitlines() if ' ' + procedure + '(' in line)
                actual = set(re.findall(r'\("(\w+)"\s*,', line))
                actual.discard(procedure)
                if action == 'Eliminar':
                    actual = {'Id' + singular}
                self.assertEqual(actual, expected, procedure)
        for table, key in [('Clientes', 'IdCliente'), ('Servicios', 'IdServicio'), ('Promociones', 'IdPromocion'), ('Pedidos', 'IdPedido'), ('Pagos', 'IdPago')]:
            procedure = 'Consultar' + table
            body = re.search(r'CREATE\s+PROCEDURE \[dbo\]\.\[' + procedure + r'\](.*?)\nGO', sql, re.S)[1]
            self.assertIn('@TipoConsulta = 1', body)
            self.assertIn('@TipoConsulta = 2', body)
            self.assertIn('@' + key, body)


if __name__ == '__main__':
    unittest.main(verbosity=2)
