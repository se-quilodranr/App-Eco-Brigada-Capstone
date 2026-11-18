# EcoBrigada 3.0 — Integración sobre el proyecto Supabase existente

> **Base utilizada:** el proyecto Flutter principal (`ecobrigadasupabase/lib`) del RAR que compartiste. Se conserva **la misma base de datos Supabase y los mismos IDs**. No se necesita migrar de Supabase a otra instancia para este paso.

## Qué cambia

- Inicio nuevo, diseño Material 3 verde, adaptable a móvil y escritorio.
- 5 pestañas: **Inicio, EcoMapa, Incidencias, Brigadas, EcoImpacto**.
- **EcoMapa unificado**: incidencias del nuevo flujo, brigadas, reciclaje verificado y lugares antiguos con sus estados `limpio`/`sucio`.
- Nuevo ciclo de incidencia: pendiente → validada → asignada → en proceso → en revisión → cerrada, con historial y evidencias fotográficas privadas antes/después.
- **EcoRadar** (duplicados), **EcoMatch** (recomendación de brigadas), **EcoZonas**, **EcoReincidencia**, **EcoTendencias** y **EcoAlerta**.
- **EcoReincidencia de lugares originales**: además lee `lugar_historial` y mide días entre un estado `limpio` y la siguiente anotación de `sucio`.
- Chat de la tabla **original `mensajes`**, solicitudes de `solicitudes`, membresías de `brigada_miembros` y jornadas de `actividades`, sin crear comunidades duplicadas.
- Fotografías en bucket privado `eco-evidencias`, perfil, validación de limpieza, notificaciones internas, exportación PDF/CSV y cola local de reportes pendientes sin conexión.
- Se mantienen las **publicaciones y guías de reciclaje originales**, con su bucket `publicaciones`, sus likes y comentarios. En Inicio hay un acceso directo; también están en el menú de cuenta.
- Se conservan las páginas originales de brigadas y lugares como vistas de consulta adicionales, en `lib/original/`.
- No se utiliza Firebase, QR, ni modo demostración. No se cargan datos ficticios automáticamente.

## Paso 1 — Base de datos Supabase: IMPORTANTE

**Si ya ejecutaste el SQL de tu proyecto anterior (`supabase/01_esquema.sql`) en Supabase:** NO vuelvas a ejecutarlo y **NO** ejecutes el SQL completo del ZIP de EcoBrigada 3.0 anterior. Ejecuta solo:

`supabase/migrations/202611170001_integracion_sin_perder_datos.sql`

Desde Supabase Dashboard → **SQL Editor**. Haz antes un respaldo. Este archivo añade columnas a `perfiles` y `brigadas`, nuevas tablas de incidencias/evidencias/avisos, políticas RLS, y reglas para chat y validación. **No borra las tablas originales**.

**Si trabajas en un proyecto Supabase completamente vacío:** ejecuta primero `supabase/base_original/01_esquema.sql`, y después la migración nueva anterior, en ese orden.

**Rol administrador:** los roles reales se guardan en `perfiles.role`, no en la interfaz Flutter. Registra tu usuario primero, obtén el `id` de `perfiles` y ejecuta en SQL Editor usando su UUID real:

```sql
update public.perfiles set role='admin' where id='UUID_DEL_USUARIO';
```

Cierra sesión y vuelve a entrar. Jamás concedas este rol desde una clave pública o código cliente.

**Coordenadas de brigadas anteriores:** si originalmente no tenían latitud/longitud, no se inventan en el mapa. Las brigadas siguen visibles en listas y chat; para ubicarlas en el mapa y usar EcoMatch debes registrar **coordenadas reales** en las columnas `lat` y `lng` desde SQL Editor (y verificar que pertenecen a esa brigada).

## Paso 2 — Variables públicas

Copia `supabase_config.example.json` a `supabase_config.json` y rellena la URL y **clave pública publishable** de **tu proyecto existente**:

```json
{
  "SUPABASE_URL": "https://TU_PROYECTO.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_TU_CLAVE_PUBLICA"
}
```

Nunca uses la clave `service_role` o una secret key en Flutter. No publiques `supabase_config.json` en repositorios públicos.

## Paso 3 — Ejecutar en Windows con Flutter

Abre PowerShell en la raíz del proyecto:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d web-server --web-port 8080 --dart-define-from-file=supabase_config.json
```

Abre Opera/Edge en http://localhost:8080. Alternativamente ejecuta `scripts/iniciar_supabase.ps1`.

**Android:** desde la misma carpeta puedes usar `flutter run -d <ID_DISPOSITIVO> --dart-define-from-file=supabase_config.json` con el dispositivo conectado. Se incluye el AndroidManifest original con permisos de internet y GPS.

## Estructura principal

```
lib/
  main.dart                   Shell con cinco pestañas y menú Comunidad
  core/                      Modelos, algoritmos, store y análisis de historial original
  pages/                     Pantallas nuevas de EcoBrigada 3.0
  original/                  Páginas heredadas para publicaciones, lugares y brigadas
  services/                  API heredada, fotos, cola offline e informe PDF
supabase/
  base_original/01_esquema.sql
  migrations/202611170001_integracion_sin_perder_datos.sql
  tests/esquema.test.sql
```

## Alcance y limitaciones

- Esta entrega integra **código** y migración SQL, pero no puede crear usuarios reales, cargar fotografías ni ejecutar SQL en tu cuenta sin autorización y conexión.
- No se ejecutó `flutter analyze` ni `flutter test` en este entorno, ya que aquí no está instalado el SDK Flutter. Debes validar compilación y pruebas en tu equipo.
- Se conserva el historial original; **`public.reportes` del proyecto antiguo corresponde a denuncias de publicaciones**, mientras que las incidencias ambientales nuevas viven en `public.incidencias`.
- Los puntos de reciclaje nuevos solo aparecen como verificados cuando existen datos reales en `puntos_reciclaje`; los lugares antiguos siguen apareciendo diferenciados.
- Las notificaciones son internas; no se implementaron notificaciones push ni QR.
- Los cambios de estado `limpio` → `sucio` permiten calcular un intervalo **hasta la anotación del nuevo problema**, no la fecha exacta en que el lugar volvió a contaminarse.
- La cola sin conexión conserva un conjunto limitado de reportes hasta recuperar la red; se debe probar su comportamiento en Android y Web.
- Antes de pasar a producción hay que realizar pruebas de reglas RLS, storage, permisos, escalabilidad y respaldo.

Ver `docs/MIGRACION_DESDE_TU_RAR.md` y `docs/PRUEBAS_Y_PERMISOS.md`.
