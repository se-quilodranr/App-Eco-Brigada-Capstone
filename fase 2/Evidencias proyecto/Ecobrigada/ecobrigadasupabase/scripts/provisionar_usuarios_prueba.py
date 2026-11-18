#!/usr/bin/env python3
"""EcoBrigada 3.1 | Crea 20 jefes y 6 ciudadanos ficticios en Supabase Auth.

- Envia nombre, apellido, RUT de prueba con DV, comuna y direccion como user_metadata.
- Mantiene las cuentas ya existentes y nunca modifica sus contrasenas.
- Guarda las claves nuevas INMEDIATAMENTE tras cada alta, fuera del repositorio.
- No requiere paquetes externos. Solo admite clave JWT legacy service_role.
- Usar preferentemente en un proyecto de pruebas. Nunca incluir secrets en Flutter.
"""
from __future__ import annotations

import json
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

NOMBRES_JEFES = [
    'Aurora Campos', 'Benjamín Rojas', 'Camila Reyes', 'Daniel Fuentes',
    'Elisa Bravo', 'Felipe Sepúlveda', 'Gabriela León', 'Hugo Contreras',
    'Isidora Muñoz', 'Joaquín Álvarez', 'Karina Silva', 'Lucas Peñaloza',
    'Mariana Pizarro', 'Natalia Pinto', 'Omar Torres', 'Paula Soto',
    'Rafael Núñez', 'Sofía Navarro', 'Tomás Vega', 'Valentina Lagos',
]
NOMBRES_CIUDADANOS = [
    'Andrea Ibáñez', 'Cristóbal López', 'Débora Méndez',
    'Esteban Vásquez', 'Francisca Molina', 'Gonzalo Carrasco',
]
COMUNAS = [
    'Concepción', 'Talcahuano', 'San Pedro de la Paz',
    'Hualpén', 'Chiguayante', 'Penco', 'Coronel',
]
PERSONAS = [
    *((f'lider{i:02d}.ecobrigada@example.com', nombre, 'jefe')
      for i, nombre in enumerate(NOMBRES_JEFES, 1)),
    *((f'ciudadano{i:02d}.ecobrigada@example.com', nombre, 'ciudadano')
      for i, nombre in enumerate(NOMBRES_CIUDADANOS, 1)),
]

# Fuera del proyecto Git: solo el usuario del equipo deberia tener acceso.
CARPETA_PRIVADA = Path.home() / 'EcoBrigada_Credenciales'
RUTA_CREDENCIALES = CARPETA_PRIVADA / 'CREDENCIALES_LIDERES_SOLO_LOCAL.json'


def rut_ficticio(indice: int) -> str:
    """RUT sintacticamente valido; NO corresponde a identidad comprobada."""
    numero = 99_000_000 + indice
    factor = 2
    suma = 0
    for digito in reversed(str(numero)):
        suma += int(digito) * factor
        factor = 2 if factor == 7 else factor + 1
    resto = 11 - (suma % 11)
    dv = '0' if resto == 11 else 'K' if resto == 10 else str(resto)
    return f'{numero}-{dv}'


def datos_persona(indice: int, email: str, nombre_completo: str, tipo: str) -> dict:
    nombre, apellido = nombre_completo.split(' ', 1)
    return {
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'rut': rut_ficticio(indice),
        'comuna': COMUNAS[(indice - 1) % len(COMUNAS)],
        'direccion': f'Dirección ficticia {indice}, solo para pruebas',
        'tipo': tipo,
    }


def pedir(url: str, key: str, metodo: str, endpoint: str, cuerpo: dict | None = None):
    if not url.startswith('https://'):
        raise RuntimeError('La URL de Supabase debe empezar con https://')
    ruta = url.rstrip('/') + '/auth/v1/admin/users' + endpoint
    contenido = json.dumps(cuerpo, ensure_ascii=False).encode('utf-8') if cuerpo is not None else None
    headers = {
        'apikey': key,
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json',
        'User-Agent': 'EcoBrigada-Cuentas-Capstone/3.1',
    }
    req = urllib.request.Request(ruta, data=contenido, headers=headers, method=metodo)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            texto = response.read().decode('utf-8')
            return json.loads(texto) if texto else {}
    except urllib.error.HTTPError as exc:
        detalle = exc.read().decode('utf-8', errors='replace')[:900]
        raise RuntimeError(f'HTTP {exc.code} ({metodo} /auth/v1/admin/users): {detalle}') from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f'Error de conexión con Supabase: {exc.reason}') from None


def listar_usuarios(url: str, key: str) -> dict[str, str]:
    existentes: dict[str, str] = {}
    pagina = 1
    tamano = 100
    while True:
        qs = urllib.parse.urlencode({'page': pagina, 'per_page': tamano})
        respuesta = pedir(url, key, 'GET', '?' + qs)
        usuarios = respuesta.get('users', []) if isinstance(respuesta, dict) else respuesta
        if not isinstance(usuarios, list):
            raise RuntimeError('Respuesta inesperada de /auth/v1/admin/users')
        for usuario in usuarios:
            if usuario.get('email'):
                existentes[usuario['email'].lower()] = str(usuario['id'])
        if len(usuarios) < tamano:
            break
        pagina += 1
    return existentes


def cargar_credenciales() -> dict[str, dict]:
    if not RUTA_CREDENCIALES.exists():
        return {}
    try:
        data = json.loads(RUTA_CREDENCIALES.read_text(encoding='utf-8'))
        if not isinstance(data, list):
            raise ValueError('El archivo no contiene una lista')
        return {str(item['email']).lower(): item for item in data}
    except (OSError, ValueError, KeyError) as exc:
        raise RuntimeError(f'No se pudo leer el archivo local de credenciales: {exc}') from exc


def guardar_credenciales(registros: dict[str, dict]) -> None:
    CARPETA_PRIVADA.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporal = RUTA_CREDENCIALES.with_suffix('.tmp')
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    fd = os.open(str(temporal), flags, 0o600)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(list(registros.values()), f, indent=2, ensure_ascii=False)
        os.replace(temporal, RUTA_CREDENCIALES)
        try:
            os.chmod(RUTA_CREDENCIALES, 0o600)
        except OSError:
            pass
    finally:
        if temporal.exists():
            temporal.unlink()


def main() -> int:
    if '--listar' in sys.argv:
        for i, (email, nombre, tipo) in enumerate(PERSONAS, 1):
            datos = datos_persona(i, email, nombre, tipo)
            print(f"{tipo:9} | {nombre:23} | {datos['rut']:12} | {email}")
        return 0

    url = os.environ.get('SUPABASE_URL', '').strip().rstrip('/')
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
    if not url.startswith('https://') or not key:
        print('ERROR: configura SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en tu terminal.')
        return 2
    if not key.startswith('eyJ'):
        print('ERROR: este script usa una clave service_role JWT (eyJ...).')
        print('No pegues claves sb_secret_ en Authorization Bearer; usa la variante JWT.')
        return 2

    print('Se crearán como máximo 20 jefes + 6 ciudadanos ficticios en:', url)
    print('Los RUT y direcciones son sintéticos. Usa preferentemente una base de pruebas.')
    if input('Para continuar, escribe exactamente CREAR: ').strip() != 'CREAR':
        print('Operación cancelada.')
        return 1

    credenciales = cargar_credenciales()
    try:
        existentes = listar_usuarios(url, key)
    except RuntimeError as exc:
        print('ERROR consultando usuarios:', exc)
        return 2

    creados = 0
    conservados = 0
    for i, (email, nombre_completo, tipo) in enumerate(PERSONAS, 1):
        datos = datos_persona(i, email, nombre_completo, tipo)
        if email.lower() in existentes:
            conservados += 1
            print('Existe (sin cambiar contraseña):', email)
            if email.lower() in credenciales:
                credenciales[email.lower()]['id'] = existentes[email.lower()]
            else:
                credenciales[email.lower()] = {
                    **datos, 'id': existentes[email.lower()], 'password': None,
                    'estado': 'EXISTENTE: contraseña desconocida',
                }
            guardar_credenciales(credenciales)
            continue

        password = 'Eco-' + secrets.token_urlsafe(22)
        metadata = {
            'nombre': datos['nombre'],
            'apellido': datos['apellido'],
            'rut': datos['rut'],
            'comuna': datos['comuna'],
            'direccion': datos['direccion'],
            'cuenta_prueba': True,
            'tipo_prueba': tipo,
        }
        try:
            resultado = pedir(url, key, 'POST', '', {
                'email': email,
                'password': password,
                'email_confirm': True,
                'user_metadata': metadata,
            })
        except RuntimeError as exc:
            print(f'ERROR creando {email}: {exc}')
            print('Detenido sin borrar ni modificar cuentas anteriores.')
            print('Si aparece HTTP 500, consulta los Postgres Logs y los triggers de auth.users.')
            print('Archivo de claves nuevas creadas antes del fallo:', RUTA_CREDENCIALES)
            return 3

        uid = resultado.get('id')
        if not uid:
            print('ERROR: Supabase no devolvió ID para', email)
            print('Comprueba Auth > Users antes de ejecutar otra vez.')
            return 3
        # Persistir tras CADA creación. Un error posterior no pierde claves anteriores.
        credenciales[email.lower()] = {
            **datos, 'id': uid, 'password': password,
            'estado': 'CREADA',
        }
        guardar_credenciales(credenciales)
        existentes[email.lower()] = uid
        creados += 1
        print(f'Creada ({creados} nuevas): {email}')

    print(f'\nFinalizado. Creadas: {creados}; existentes conservadas: {conservados}.')
    print('Credenciales privadas:', RUTA_CREDENCIALES)
    print('NO compartas el archivo ni lo añadas a Git, Flutter o el ZIP del proyecto.')
    print('Ahora puedes ejecutar el SQL de datos_capstone_integrales en Supabase SQL Editor.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
