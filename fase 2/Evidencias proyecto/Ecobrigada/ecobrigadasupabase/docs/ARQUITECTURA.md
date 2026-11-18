# Arquitectura de EcoBrigada 3.0 integrada

La aplicación es Flutter Web + Android con backend único Supabase. Se trabaja con **la instancia del usuario ya creada**, sin instalar Firebase y sin duplicar las brigadas existentes.

## Presentación
- `lib/main.dart`: autenticación y navegación Material 3 con cinco pestañas.
- `lib/pages/`: Inicio, EcoMapa, incidencias, brigadas, chat, EcoImpacto, perfil y avisos.
- `lib/original/`: vistas conservadas de publicaciones, mapa de lugares comunitarios y actividades originales.

## Aplicación y estado
- `lib/core/store.dart`: `EcoStore` (ChangeNotifier) y consultas de Supabase. Adapta campos entre el esquema original y el nuevo UI. Coordina cola offline, fotografías y cambios de estado.
- `lib/services/api_original.dart`: funciones que ya estaban implementadas en el RAR para publicaciones, lugares y brigadas.

## Dominio y análisis
- `models.dart`: entidades de incidencias, brigadas y jornadas.
- `algorithms.dart`: prioridad, duplicados y recomendación de brigadas.
- `eco_analisis.dart`: EcoZonas, EcoReincidencia, EcoTendencias y EcoAlerta.
- `reincidencia_lugares.dart`: historia original de estados limpio → sucio.

## Persistencia
- PostgreSQL: `perfiles`, `brigadas`, `brigada_miembros`, `solicitudes`, `mensajes`, `actividades`, `lugares`, `lugar_historial`, `publicaciones`, etc., conservadas del RAR.
- PostgreSQL: `incidencias`, `historial_incidencias`, `fotos_incidencia`, `validaciones_limpieza`, `puntos_reciclaje` y `notificaciones`, añadidas.
- Storage: `publicaciones` (original, público bajo reglas antiguas) y `eco-evidencias` (nuevo, privado).
- Auth: Supabase Auth con el mismo usuario e ID originales.
- Realtime: chat original y avisos nuevos, con RLS.
- `shared_preferences`: únicamente cola local de incidencias pendientes de envío, NO otra base de datos de producción.

## Autorización
- El rol de administrador es `perfiles.role='admin'` establecido por un operador autorizado en SQL Editor.
- El líder de una brigada es `brigadas.lider_uid` (inicialmente creador de la brigada), y los miembros aprobados se registran en `brigada_miembros`.
- Los permisos reales están en PostgreSQL RLS y funciones SQL; ocultar botones en Flutter no equivale a seguridad.
