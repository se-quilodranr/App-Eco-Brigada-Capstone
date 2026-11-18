# Qué fue reutilizado de tu proyecto original

## Inspección del RAR

Tu archivo `ecobrigadasupabase.rar` contenía **dos proyectos Flutter anidados**. El proyecto con código realmente desarrollado estaba en la raíz `ecobrigadasupabase/`. El subdirectorio `ecobrigadasupabase/ecobrigada/` solo tenía un `main.dart` básico generado por Flutter y dependencias de ejemplo. La entrega usa el **proyecto principal**, no ese subdirectorio.

## Tablas originales conservadas (sin renombrar)

| Tabla | Uso tras integrar EcoBrigada 3.0 |
|---|---|
| `perfiles` | Cuentas existentes; se añaden `role` y `avatar_path` |
| `brigadas` | Misma tabla; se añaden `lider_uid`, coordenadas opcionales, disponibilidad y recuento de miembros |
| `brigada_miembros` | Integrantes aprobados; acceso al chat |
| `solicitudes` | Solicitudes de ingreso a brigadas o actividades |
| `mensajes` | Chat grupal en tiempo real; administrador global autorizado por RLS |
| `actividades` | Jornadas, fechas y lugares de las actividades antiguas y nuevas |
| `lugares` | Marcadores limpio/sucio en EcoMapa |
| `lugar_historial` | Análisis de ciclos limpio → sucio en EcoImpacto |
| `publicaciones`, `publicacion_pasos`, `publicacion_fotos`, `comentarios`, `publicacion_likes`, `reportes` | Comunidad/guías de reciclaje y moderación originales |

## Nuevas tablas, sin interferir en el contenido existente

- `incidencias`: reportes ambientales formales, independientes de `reportes` (denuncias de publicaciones).
- `historial_incidencias`: transición de estados.
- `fotos_incidencia`: rutas de evidencias en Storage privado.
- `validaciones_limpieza`: aprobaciones o devoluciones administrativas.
- `notificaciones`: avisos internos.
- `puntos_reciclaje`: puntos de reciclaje verificados, distintos de `lugares`.

## Permisos

- Los usuarios antiguos conservan su autenticación Supabase: **no se vuelven a registrar**.
- Las brigadas existentes conservan el creador, miembros y chats. El líder inicial coincide con el creador.
- Crear brigadas en 3.0 es exclusivo de `perfiles.role='admin'`. Las brigadas anteriores no desaparecen.
- La administración puede ver chats por `app.can_chat` aplicado mediante RLS; los integrantes de brigadas distintas siguen sin permiso.
- Sólo el administrador puede validar y cerrar incidencias, y se requiere evidencia posterior para la revisión.
- La clave pública es apta para Flutter; jamás copiar credenciales privilegiadas de Supabase al proyecto.

## Secuencia de actualización segura

1. Realiza un respaldo/backup de tu proyecto Supabase y del código anterior.
2. Ejecuta **únicamente** `supabase/migrations/202611170001_integracion_sin_perder_datos.sql` si la estructura original ya existe.
3. Comprueba las tablas y políticas en el panel de Supabase.
4. Registra o utiliza tu usuario actual y concede rol administrador desde SQL Editor, si corresponde.
5. Copia la URL y clave pública al archivo local de configuración.
6. Ejecuta `flutter analyze`, `flutter test` y pruebas con cuentas de ciudadanos, líderes y administradores.

## Datos de mapa

Las `brigadas` originales no incluían lat/lng en su definición. En la migración se agregan columnas **sin inventar valores**: dichas brigadas aparecen en listas pero no en el mapa de brigadas ni en las recomendaciones geográficas hasta registrar coordenadas verificadas. La capa de `lugares` sí utiliza los GPS originales existentes.
