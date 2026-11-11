import unittest
from dbscan_zonas import demo, crear_zonas


class DbscanZonasTest(unittest.TestCase):
    def test_agrupa_y_descarta_ruido(self):
        zonas = crear_zonas(demo(), eps_m=250, min_reportes=3)
        self.assertEqual(len(zonas), 2)
        self.assertEqual(sorted(z['cantidadReportes'] for z in zonas), [3, 4])
        self.assertFalse(any('demo-aislado' in z['idsReportes'] for z in zonas))

    def test_no_hay_clusters_si_no_hay_muestras_suficientes(self):
        self.assertEqual(crear_zonas(demo()[:2], min_reportes=3), [])


if __name__ == '__main__':
    unittest.main()
