"""Enviar FCM a dispositivos Android que aceptaron compartir última ubicación.

Uso (vista previa): python avisar_punto_fcm.py --project ecobrigada-40f80 --point-id ID
Envío real: python avisar_punto_fcm.py --project ecobrigada-40f80 --point-id ID --send

Ejecutar manualmente desde un equipo administrativo. Para automatizar al crear
un punto se requiere backend seguro/planificar tarea y revisar costos.
"""
import argparse
from datetime import datetime, timedelta, timezone
from hashlib import sha256
import math

R_KM = 6371.0088


def km(lat1, lon1, lat2, lon2):
    a, b, c, d = map(math.radians, [lat1, lon1, lat2, lon2])
    h = math.sin((c-a)/2)**2 + math.cos(a)*math.cos(c)*math.sin((d-b)/2)**2
    return 2 * R_KM * math.asin(min(1, math.sqrt(h)))


def main():
    arg = argparse.ArgumentParser()
    arg.add_argument('--project', required=True)
    arg.add_argument('--point-id', required=True)
    arg.add_argument('--send', action='store_true')
    args = arg.parse_args()
    import firebase_admin
    from firebase_admin import credentials, firestore, messaging
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.ApplicationDefault(), {'projectId': args.project})
    db = firestore.client()

    ref = db.collection('puntos_mapa').document(args.point_id)
    datos = ref.get().to_dict()
    if not datos or datos.get('tipo') not in ('brigada', 'sucio', 'reciclaje', 'limpiado'):
        raise SystemExit('Punto inexistente o categoria no soportada')
    ubicacion = datos.get('ubicacion')
    if ubicacion is None:
        raise SystemExit('Punto sin ubicación')

    candidatos = 0
    enviados = 0
    fallidos = 0
    for dispositivo in db.collection_group('dispositivos').stream():
        d = dispositivo.to_dict() or {}
        if d.get('plataforma') != 'android' or not d.get('token'):
            continue
        puntoUsuario = d.get('ubicacion')
        radio = d.get('radioKm')
        actualizado = d.get('actualizadoEn')
        if puntoUsuario is None or not isinstance(radio, (int, float)):
            continue
        # No usar ubicaciones antiguas por defecto. Exige consentimiento vigente.
        if actualizado is None or actualizado < datetime.now(timezone.utc) - timedelta(days=1):
            continue
        distancia = km(ubicacion.latitude, ubicacion.longitude,
                       puntoUsuario.latitude, puntoUsuario.longitude)
        if distancia > radio:
            continue
        candidatos += 1
        uid_ref = dispositivo.reference.parent.parent
        if uid_ref is None or uid_ref.id == datos.get('creadorUid'):
            continue
        clave = sha256(f"{args.point_id}:{dispositivo.id}".encode()).hexdigest()[:32]
        log = db.collection('avisos_enviados').document(clave)
        if log.get().exists:
            continue
        if not args.send:
            print(f'[PREVIEW] UID {uid_ref.id[:6]}... cerca: {distancia:.2f} km')
            continue
        try:
            messaging.send(messaging.Message(
                token=d['token'],
                notification=messaging.Notification(
                    title='EcoBrigada: punto cercano',
                    body=f"{str(datos.get('nombre','Punto ecológico'))[:60]} a {distancia:.1f} km",
                ),
                data={'puntoId': args.point_id},
            ))
            log.set({
                'puntoId': args.point_id,
                'destino': dispositivo.id,
                'enviadoEn': firestore.SERVER_TIMESTAMP,
            })
            enviados += 1
        except Exception as exc:
            fallidos += 1
            print('Error de envío (sin token expuesto):', type(exc).__name__)
    print(f'Candidatos: {candidatos} | enviados: {enviados} | errores: {fallidos}')
    if not args.send:
        print('Vista previa; no se enviaron notificaciones. Agrega --send.')


if __name__ == '__main__':
    main()
