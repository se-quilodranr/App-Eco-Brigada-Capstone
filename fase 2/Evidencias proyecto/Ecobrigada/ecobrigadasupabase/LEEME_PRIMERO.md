# EcoBrigada 3.1 - Cinco mejoras solicitadas

Esta actualización modifica únicamente Flutter y las dependencias.
**NO hace falta ejecutar SQL ni volver a crear usuarios en Supabase.**

## Cambios
1. Inicio de sesión: mensaje «Correo o contraseña incorrectos» cuando Supabase
   devuelve `invalid_credentials`.
2. Cuatro tarjetas de Inicio navegables:
   - Activas -> Incidencias (filtro Activos).
   - Resueltas -> Incidencias (filtro cerrado).
   - Brigadas disponibles -> Brigadas (filtro Disponibles).
   - Jornadas -> Brigadas (vista Jornadas).
3. Perfil: Mis reportes, Brigadas que lidero y Brigadas a las que pertenezco,
   con enlaces a los detalles.
4. Nuevo reporte: seleccionando el punto en el mapa se consulta una dirección
   aproximada y se rellenan comuna y sector (se pueden editar). El mapa muestra
   hasta 70 incidencias próximas con opción de abrir el detalle.
5. EcoMapa: se elimina la capa antigua de lugares comunitarios, y también su
   acceso de menú y análisis histórico. Se reutiliza icono de basurero para
   incidencias en proceso y visto bueno para validadas/cerradas.

## Instalación segura en Windows
1. Cierra la ejecución Flutter (Ctrl+C).
2. Copia tu proyecto completo a otra carpeta como respaldo.
3. Descomprime `Parche_EcoBrigada_3_1_5_Mejoras.zip`.
4. Copia `lib/` y `pubspec.yaml` de la carpeta extraída a la RAÍZ de tu
   proyecto `ecobrigadasupabase/`, aceptando reemplazar los archivos con
   igual nombre. Los archivos nuevos (`mi_actividad_page.dart` y
   `reverse_geocoding.dart`) también deben quedar copiados.
5. NO reemplaces ni borres `supabase_config.json` (no se incluye en el ZIP).
6. Ejecuta los siguientes comandos desde tu carpeta `ecobrigadasupabase`:

```powershell
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define-from-file=supabase_config.json
```

## Comprobaciones manuales
- Intentar contraseña errónea de una cuenta válida -> mensaje solicitado.
- Hacer clic en las cuatro tarjetas de la página Inicio.
- Abrir Perfil: probar las tres tarjetas y entrar en un reporte o brigada.
- Crear reporte y tocar el mapa: aparecen marcadores de incidencias y se
  completan comuna/sector si el proveedor geográfico devuelve datos.
- En EcoMapa comprobar los nuevos iconos y ausencia de lugares comunitarios.

## Geocodificación
Para prototipo, se utiliza el servicio público de Nominatim/OpenStreetMap.
La consulta se realiza **solo al marcar una ubicación**, tras una espera
corta; se reutilizan resultados en caché, y se separan las consultas por
al menos 1,1 s por cliente. Requiere internet y la dirección puede ser
aproximada o no estar disponible. El usuario puede editar ambos campos.
Cada coordenada elegida se envía al proveedor de geocodificación.

**Antes de uso público**: sustituir el endpoint gratuito por un proveedor
contratado o un proxy/backend propio con límites agregados y aviso de privacidad;
el máximo de 1 petición/s de Nominatim es para toda la aplicación, no solo
para un dispositivo. Consultar
https://operations.osmfoundation.org/policies/nominatim/

## Datos existentes
No se borran registros ni se ejecutan migraciones. La tabla SQL antigua
`lugares` permanece intacta para evitar pérdida accidental de información;
solo se oculta su funcionalidad antigua y ya no se consulta en la carga usual.

## Validación
Se comprobó estáticamente la estructura de delimitadores Dart y rutas
entre archivos. No fue posible ejecutar `flutter analyze` o `flutter run` en
este contenedor porque Flutter/Dart SDK no está instalado. Prueba en tu PC y
comparte cualquier mensaje de compilación si aparece.
