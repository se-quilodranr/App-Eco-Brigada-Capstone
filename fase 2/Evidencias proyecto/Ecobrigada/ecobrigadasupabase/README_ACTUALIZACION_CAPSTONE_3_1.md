# EcoBrigada 3.1 — Entrega de datos, jefaturas y pruebas de Capstone

**Base de origen:** `ecobrigadasupabase(3).rar`, enviada el 18 de noviembre de 2026. El Home, las cinco pestañas, publicaciones, puntos, reportería y Supabase original se conservaron.

## Incluye

- **240 incidencias sintéticas adicionales** distribuidas en 12 sectores cercanos, con casos pendientes, validados, asignados, en ejecución, revisión, cerrados y descartados. Hay casos antiguos de alta prioridad para demostrar vencimientos, y pares de incidentes cerrados/abiertos cercanos para EcoReincidencia.
- **9 brigadas sintéticas nuevas**, además de asignación de **7 jefes ficticios diferentes** a las brigadas antiguas de prueba si están en la base. No reasigna brigadas reales. 20 cuentas de jefes en el aprovisionamiento (16 utilizadas cuando existen las 7 antiguas) y 6 ciudadanos de prueba.
- **36 jornadas**: finalizadas, en curso y futuras, más 18 mensajes de chat de bienvenida, 6 solicitudes pendientes y 6 miembros ya aprobados para ensayar la autorización.
- **12 lugares comunitarios** y **12 puntos de reciclaje NO verificados** para comprobar EcoMapa. Nunca se presentan como instalaciones reales.
- **Ciudadano:** puede crear reportes y brigadas nuevas; quien crea su brigada pasa a ser jefe. Puede solicitar acceso a otras brigadas; chats solo con pertenencia real.
- **Jefe:** puede admitir o rechazar miembros de su brigada, programar jornadas, subir evidencia posterior y remitir informe final con texto y participantes. El backend exige fotografía y valida su identidad.
- **Administrador `seba@gmail.com`:** el archivo SQL de promoción le otorga acceso global, exclusivamente si esa cuenta ya existe en Supabase Auth. Puede validar, asignar, cerrar y supervisar; no puede suplantar al jefe en el envío final.
- Se mejora la carga de datos para que un fallo en una tabla no vacíe las otras listas.
- Pruebas unitarias adicionales, scripts de diagnóstico y documentación de casos de prueba.

## Instalación, en orden

1. **Haz respaldo de Supabase** y confirma que tu esquema base y migraciones `202611170001_integracion_sin_perder_datos.sql` y `202611170002_registro_personal_seguro.sql` ya están instalados. Si antes te apareció un error de SQL, resuélvelo primero; no ejecutes el esquema original sobre tablas existentes.
2. Ejecuta en SQL Editor: `supabase/migrations/202611180001_roles_jefes_informes.sql`.
3. Ejecuta en SQL Editor, como propietario: `supabase/admin/202611180002_promover_seba_admin.sql`.
4. Crea las **cuentas de prueba reales en Supabase Auth** usando `scripts/provisionar_usuarios_prueba.py` y la clave `service_role` **solo en tu computador**, nunca desde Flutter ni en Git. Las identidades y contraseñas son ficticias y se guardan en un archivo local privado. Ver instrucciones de seguridad y pruebas en `docs/PRUEBAS_ROLES_E_INCIDENCIAS.md`.
5. Opcional: ejecuta `supabase/fixtures/202611180003_datos_capstone_integrales.sql`, idealmente sobre una copia de la base. **No elimina registros, no simula fotografías**, y sus IDs están preparados para evitar duplicados al ejecutarlo de nuevo.
6. Comprueba con `supabase/tests/202611180004_diagnostico_roles_datos.sql`.
7. En VS Code: `flutter pub get`, `flutter analyze`, `flutter test` y ejecuta con `flutter run -d web-server --web-port 8080`. Si usas variables, agrega `--dart-define-from-file=supabase_config.json`.

> La URL y publishable key públicas de Supabase permanecen en `lib/main.dart` porque estaban configuradas en tu RAR. **Nunca pegues claves secretas ni service_role en lib/**. Puedes sustituirlas por variables de entorno si planeas publicar el repositorio.

## Prueba más importante durante la defensa

Ciudadano registra una incidencia → administrador valida y asigna → jefe inicia trabajo, toma evidencia posterior y **envía informe final** → administrador revisa y cierra/deuelve con observación → EcoImpacto actualiza indicadores.

El informe final se exige **en el backend SQL**, no solo en la interfaz. Por tanto, no es posible cerrar una incidencia sin informe final y fotografía posterior mediante la nueva función de cierre.

## Límites honestos

- El ZIP contiene los archivos implementados, pero **no ejecuté Flutter ni migraciones en la base real**. Hay que validar los flujos y las políticas RLS antes de Capstone.
- Datos sintéticos son solo para demostrar análisis de software, no evidencian contaminación real de Gran Concepción.
- Algunas incidencias sintéticas antiguas con estado `cerrado` no tienen informe ni fotos: son registros ficticios de analítica, no cierre realizado en la app.
- La carga de jefaturas se aplica solo a brigadas ficticias, por seguridad y para no modificar propietarios de brigadas auténticas.
- Para crear cuentas de prueba y asignar el administrador se requiere acceso del **propietario del proyecto Supabase**. El archivo ZIP por sí solo no cambia usuarios remotos.
