"""EcoBrigada · DBSCAN espacial de reportes de puntos sucios.

DEMO (sin Firebase): python dbscan_zonas.py --demo
REAL (solo lectura): python dbscan_zonas.py --project ecobrigada-40f80
PUBLICAR: python dbscan_zonas.py --project ecobrigada-40f80 --publish

No es un modelo de prediccion futura. Agrupa reportes cercanos y calcula
una prioridad operativa basada en cantidad de reportes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from sklearn.cluster import DBSCAN

EARTH_RADIUS_KM = 6371.0088


@dataclass(frozen=True)
class Reporte:
    id: str
    lat: float
    lon: float


def distancia_m(a_lat: float, a_lon: float, b_lat: float, b_lon: float) -> float:
    a, b, c, d = map(math.radians, [a_lat, a_lon, b_lat, b_lon])
    h = math.sin((c - a) / 2) ** 2 + math.cos(a) * math.cos(c) * math.sin((d - b) / 2) ** 2
    return 2 * EARTH_RADIUS_KM * 1000 * math.asin(min(1, math.sqrt(h)))


def crear_zonas(reportes: list[Reporte], eps_m: int = 250, min_reportes: int = 3) -> list[dict]:
    """DBSCAN métrica haversine; eps en radianes. Retorna zonas serializables."""
    if len(reportes) < min_reportes:
        return []
    coords = np.radians(np.array([[p.lat, p.lon] for p in reportes], dtype=float))
    etiquetas = DBSCAN(
        eps=eps_m / (EARTH_RADIUS_KM * 1000),
        min_samples=min_reportes,
        metric='haversine',
        algorithm='ball_tree',
    ).fit_predict(coords)
    zonas = []
    for etiqueta in sorted(set(etiquetas)):
        if etiqueta == -1:
            continue  # ruido / casos aislados
        grupo = [p for p, cl in zip(reportes, etiquetas) if int(cl) == int(etiqueta)]
        centro_lat = sum(p.lat for p in grupo) / len(grupo)
        centro_lon = sum(p.lon for p in grupo) / len(grupo)
        radio_m = max(distancia_m(centro_lat, centro_lon, p.lat, p.lon) for p in grupo) + 30
        # Identificador estable mientras la composición exacta del grupo no cambie.
        miembros = sorted(p.id for p in grupo)
        zid = hashlib.sha256('|'.join(miembros).encode('utf-8')).hexdigest()[:20]
        n = len(grupo)
        zonas.append({
            'id': zid,
            'centroLat': round(centro_lat, 7),
            'centroLon': round(centro_lon, 7),
            'radioMetros': round(radio_m),
            'cantidadReportes': n,
            'prioridad': 'alta' if n >= 8 else 'media' if n >= 5 else 'inicial',
            'idsReportes': miembros,
            'algoritmo': 'DBSCAN-haversine',
        })
    return sorted(zonas, key=lambda z: (-z['cantidadReportes'], z['id']))


def demo() -> list[Reporte]:
    # Datos 100% SINTETICOS: no representan puntos reales de basura.
    return [
        Reporte('demo-a1', -36.8260, -73.0490), Reporte('demo-a2', -36.8263, -73.0496),
        Reporte('demo-a3', -36.8256, -73.0492), Reporte('demo-a4', -36.8262, -73.0487),
        Reporte('demo-b1', -36.8350, -73.0580), Reporte('demo-b2', -36.8355, -73.0584),
        Reporte('demo-b3', -36.8348, -73.0578), Reporte('demo-aislado', -36.8990, -73.1000),
    ]


def obtener_reportes(db, max_documentos: int = 10000) -> list[Reporte]:
    reportes = []
    # Solo reportes sucios; no se requieren perfiles ni datos personales.
    docs = db.collection('puntos_mapa').where('tipo', '==', 'sucio').limit(max_documentos).stream()
    for d in docs:
        datos = d.to_dict() or {}
        gps = datos.get('ubicacion')
        if gps is None:
            continue
        lat, lon = float(gps.latitude), float(gps.longitude)
        if -90 <= lat <= 90 and -180 <= lon <= 180:
            reportes.append(Reporte(d.id, lat, lon))
    return reportes


def publicar_zonas(db, zonas: list[dict]) -> tuple[int, int]:
    """Crea/actualiza zonas calculadas; retira zonas anteriores del mismo algoritmo.

    La publicacion se hace desde entorno privilegiado, NUNCA desde Flutter.
    """
    from firebase_admin import firestore

    coleccion = db.collection('zonas_criticas')
    antiguas = [d for d in coleccion.where('fuente', '==', 'dbscan-v1').stream()]
    nuevos_ids = {z['id'] for z in zonas}
    batch = db.batch()
    operaciones = 0
    removidos = 0

    def confirmar_si_lleno():
        nonlocal batch, operaciones
        if operaciones >= 400:
            batch.commit()
            batch = db.batch()
            operaciones = 0

    for z in zonas:
        ref = coleccion.document(z['id'])
        datos = {
            'centro': firestore.GeoPoint(z['centroLat'], z['centroLon']),
            'radioMetros': int(z['radioMetros']),
            'cantidadReportes': int(z['cantidadReportes']),
            'prioridad': z['prioridad'],
            'idsReportes': z['idsReportes'],
            'algoritmo': z['algoritmo'],
            'fuente': 'dbscan-v1',
            'actualizadoEn': firestore.SERVER_TIMESTAMP,
        }
        batch.set(ref, datos)
        operaciones += 1
        confirmar_si_lleno()
    for doc in antiguas:
        if doc.id not in nuevos_ids:
            batch.delete(doc.reference)
            operaciones += 1
            removidos += 1
            confirmar_si_lleno()
    if operaciones:
        batch.commit()
    return len(zonas), removidos


def main():
    parser = argparse.ArgumentParser(description='EcoBrigada: agrupacion espacial DBSCAN')
    parser.add_argument('--demo', action='store_true', help='Usar reportes sinteticos sin Firebase')
    parser.add_argument('--project', help='ID del proyecto Firebase')
    parser.add_argument('--publish', action='store_true', help='Escribir zonas en Firestore')
    parser.add_argument('--eps-m', type=int, default=250, help='Vecindad maxima entre reportes, metros')
    parser.add_argument('--min-samples', type=int, default=3, help='Minimo de reportes por cluster')
    parser.add_argument('--output', default='zonas_preview.json', help='Archivo de resultados local')
    args = parser.parse_args()
    if args.eps_m < 20 or args.min_samples < 2:
        parser.error('eps-m debe ser >=20 y min-samples >=2')
    if args.demo and args.publish:
        parser.error('La demo no se puede publicar como datos reales')
    if not args.demo and not args.project:
        parser.error('Usa --demo o proporciona --project')

    db = None
    if args.demo:
        reportes = demo()
    else:
        import firebase_admin
        from firebase_admin import credentials, firestore
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.ApplicationDefault(), {'projectId': args.project})
        db = firestore.client()
        reportes = obtener_reportes(db)

    zonas = crear_zonas(reportes, args.eps_m, args.min_samples)
    Path(args.output).write_text(
        json.dumps({
            'demo': args.demo,
            'generadoEn': datetime.now(timezone.utc).isoformat(),
            'cantidadReportes': len(reportes),
            'epsMetros': args.eps_m,
            'minSamples': args.min_samples,
            'zonas': zonas,
        }, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Reportes: {len(reportes)} | zonas: {len(zonas)} | salida: {args.output}')
    for z in zonas:
        print(f"- {z['id']}: {z['cantidadReportes']} reportes, {z['prioridad']}, radio {z['radioMetros']}m")

    if args.publish:
        creadas, removidas = publicar_zonas(db, zonas)
        print(f'Firestore actualizado: {creadas} zonas; {removidas} antiguas retiradas.')
    else:
        print('Vista previa: NO se escribio nada en Firestore. Usa --publish para publicar.')


if __name__ == '__main__':
    main()
