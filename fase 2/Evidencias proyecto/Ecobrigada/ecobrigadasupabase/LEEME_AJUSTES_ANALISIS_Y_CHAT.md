# EcoBrigada 3.1 — Ajustes de interfaz y EcoAnálisis

## Instalación desde el parche

1. Haz una copia de seguridad de tu carpeta `ecobrigadasupabase`.
2. Extrae el ZIP de parche y copia **la carpeta `lib`** sobre `lib` en la raíz del proyecto actual, aceptando reemplazar los archivos coincidentes.
3. Puedes copiar `test/etiquetas_presentacion_test.dart` si deseas ejecutar la prueba de etiquetas.
4. El SQL en `supabase/fixtures/` es **opcional y solo para nuevas instalaciones**: incluye la corrección de alias ambiguo `n`. **No vuelvas a ejecutar el SQL de carga integral** si ya se cargaron las 240 incidencias.
5. **No reemplaces ni compartas** `supabase_config.json` ni el archivo privado de contraseñas.
6. Ejecuta en PowerShell desde la raíz del proyecto:

   ```powershell
   flutter pub get
   flutter run -d web-server --web-port 8080 --dart-define-from-file=supabase_config.json
   ```

## Cambios

- Se quita en la interfaz el aviso redundante «Brigada de prueba ...».
- Se limpian las marcas `[FICTICIO]`, `[FICTICIO QA-31]` y `(ficticia)` en los modelos mostrados (incidencias, brigadas, jornadas, mensajes y reciclaje). Los registros y su procedencia permanecen en PostgreSQL.
- El chat consulta `public.perfiles.nombre` por identificador del emisor para incluir nombre y apellido, incluidos líderes y administradores. Si RLS impide ver el perfil se usan los nombres conocidos de miembros o un texto genérico.
- Se añadieron explicaciones a los indicadores generales y administrativos de EcoImpacto, y a las cuatro métricas de EcoAnálisis.
- EcoTendencias resume nuevas incidencias, cierres y semana de mayor volumen.
- EcoZonas muestra detalles desplegables por sector: índice, cantidad, gravedad, tipos y radio; las coordenadas y ejemplos de reportes se reservan a administración.
- EcoReincidencia ofrece tarjetas de contexto y una página **Ver todos** con filtros por distancia.
- EcoAlerta añade detalle de estado y prioridad y una página **Ver todas** con filtros por vencimiento/prioridad.
- Las nuevas páginas de resultados usan listas perezosas para evitar construir todas las tarjetas al mismo tiempo.
- Se corrigió en el archivo de *fixtures* el alias ambiguo `n`, para futuras instalaciones; no hay que ejecutar SQL de modificación del esquema.

## Advertencia sobre datos de demostración

Esta actualización cambia **solo la visualización** de las etiquetas repetitivas. No convierte los reportes de prueba en hechos reales. El panel EcoImpacto conserva un aviso general de que los análisis pueden incluir registros de demostración. No utilices cifras ni ubicaciones de prueba como reportes ambientales verificados.

## Comprobaciones sugeridas

- En un chat de brigada, enviar un mensaje como integrante, líder y administrador: comprobar el nombre visible.
- Abrir brigadas, incidencias, jornadas y EcoImpacto: verificar que no aparezcan marcas de carga sintética.
- Entrar como administrador a EcoImpacto, pulsar «Ver todos los resultados» en EcoReincidencia y «Ver todas las alertas» en EcoAlerta y cambiar los filtros.
- Entrar con usuario no administrador y comprobar que se respete el resumen sin exponer datos internos.
- Prueba adicional: `flutter test test/etiquetas_presentacion_test.dart`.

## Estado de validación

Los archivos se prepararon y se revisaron sus referencias estáticas; no se pudo ejecutar `flutter analyze` ni compilar Flutter en este entorno. Confirma la compilación en tu equipo y comparte cualquier error completo de PowerShell.
