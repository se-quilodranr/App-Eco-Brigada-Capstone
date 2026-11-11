"""Agrega geo.geopoint y geo.geohash a puntos_mapa existentes (Admin SDK).

Sin --publish solo informa. Requiere GOOGLE_APPLICATION_CREDENTIALS.
"""
import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', required=True)
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()

    import firebase_admin
    from firebase_admin import credentials, firestore
    import geohash2
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.ApplicationDefault(), {'projectId': args.project})
    db = firestore.client()
    pendientes = []
    for doc in db.collection('puntos_mapa').stream():
        info = doc.to_dict() or {}
        p = info.get('ubicacion')
        if p is None or ('geo' in info):
            continue
        pendientes.append((doc.reference, p))
    print(f'Puntos antiguos sin geohash: {len(pendientes)}')
    if not args.publish:
        print('Vista previa; no se modifico Firestore. Agrega --publish para guardar.')
        return
    batch = db.batch()
    count = 0
    for ref, p in pendientes:
        # Coincide con el geohash Base32 estándar de GeoFlutterFire.
        data = {'geo': {
            'geopoint': p,
            'geohash': geohash2.encode(p.latitude, p.longitude, precision=10),
        }}
        batch.update(ref, data)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    if count % 400:
        batch.commit()
    print(f'Migrados: {count}. Verifica antes de habilitar las geoqueries en Flutter.')


if __name__ == '__main__':
    main()
