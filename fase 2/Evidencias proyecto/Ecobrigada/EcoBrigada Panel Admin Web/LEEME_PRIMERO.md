# EcoBrigada Admin — Eliminar cuentas de usuario

Este paquete **actualiza el panel que ya funciona** en `http://localhost:8081`. No se instala dentro de Flutter y no necesitas poner una `service_role` en JavaScript ni en archivos de configuración.

## Qué hace «Eliminar»

- El administrador confirma el correo exacto y escribe `ELIMINAR`.
- Una Edge Function verifica el JWT y vuelve a verificar que la cuenta sea administradora desde `perfiles.role`.
- Impide eliminar la propia cuenta, al último administrador o a un usuario que todavía dirige brigadas (reasigna el jefe desde el panel antes de eliminarlo).
- Ejecuta `auth.admin.deleteUser(id, true)` con eliminación **lógica e irreversible** de Supabase Auth; no es un borrado físico de toda la información.
- Anonimiza el nombre del perfil, revoca su rol de administrador, intenta borrar sus datos personales en `perfil_datos_privados`, retira sus membresías y registra auditoría.
- **Mantiene incidencias, reportes, mensajes y estadísticas históricas**. No borra automáticamente imágenes de Storage ni el texto de mensajes. JWT ya emitidos pueden seguir siendo válidos hasta su expiración; las comprobaciones de permisos del backend deben realizarse en cada operación sensible.

## 1. Hacer copia de seguridad

Respalda el proyecto y la base Supabase antes de aplicar esta función de borrado. Prueba primero con una cuenta ficticia que no sea jefa de ninguna brigada.

## 2. Actualizar archivos web

Detén el servidor (`Ctrl+C`) y copia sobre tu carpeta actual `D:\Descargas\EcoBrigada_Panel_Admin_Web`:

- `src/app.js`
- `src/style.css`

Se conserva la corrección de tipo MIME: `INICIAR_PANEL.ps1` y `SERVIDOR_PANEL.py` deben quedarse juntos en la raíz del panel.

## 3. Aplicar migración SQL adicional

En Supabase > SQL Editor, ejecuta **todo el contenido** de:

`supabase/20261118_panel_eliminar_usuarios.sql`

Este SQL no elimina usuarios existentes: actualiza el listado y el conteo de cuentas para ignorar aquellas con `auth.users.deleted_at IS NOT NULL`.

## 4. Desplegar Edge Function desde Supabase Dashboard

1. Abre tu proyecto Supabase > **Edge Functions** > **Deploy a new function** / Editor.
2. Usa el nombre exacto `eco-admin-eliminar-usuario`.
3. Pega **todo** el archivo `supabase/functions/eco-admin-eliminar-usuario/index.ts` y despliega.
4. Configura la función con **Verify JWT habilitado** (`verify_jwt = true`), que es el valor predeterminado para funciones de usuario.
5. Supabase proporciona a las Edge Functions las credenciales privadas desde las variables de entorno de su plataforma. **No copies ni pegues claves secretas en el código del navegador ni en `src/config.js`.**
6. Si despliegas la web en otro dominio, configura `ECO_ADMIN_ALLOWED_ORIGINS` como lista de orígenes HTTPS separados por coma en las variables de entorno de la función. `localhost:8081` ya está permitido.

Alternativa CLI (sin instalar Docker para el despliegue por API):

```powershell
supabase login
supabase link --project-ref imcvutrsvudbmuzgnbyd
supabase functions deploy eco-admin-eliminar-usuario --use-api
```

El archivo de función debe conservar esta ruta dentro de tu panel:
`supabase/functions/eco-admin-eliminar-usuario/index.ts`.

**No usar** `--no-verify-jwt` ni `verify_jwt = false` para esta función.

## 5. Reiniciar el servidor

```powershell
powershell -ExecutionPolicy Bypass -File .\INICIAR_PANEL.ps1
```

Abre `http://localhost:8081`, presiona `Ctrl+F5`, entra con una cuenta admin y ve a **Usuarios > Eliminar**.

## 6. Si aparece un error

- `404` en la función: falta desplegarla con el nombre exacto.
- `401`: inicia sesión nuevamente. No desactives la verificación de JWT.
- `403`: la cuenta no es administradora o el origen no está permitido.
- `409`: debes reasignar una jefatura, se intentó eliminar al último administrador, o Auth bloqueó la eliminación; revisa las advertencias.
- Aviso de Storage: Supabase puede impedir una eliminación por archivos propiedad del usuario. Revisa Storage y sus dependencias antes de actuar. Nunca borres datos en masa para forzar la operación.
- El acceso viejo de un usuario puede continuar hasta la expiración de un JWT emitido; no equivale a cerrar sesiones instantáneamente.

## Seguridad

La operación se realiza en la infraestructura de Supabase y no desde el navegador. Nunca distribuyas una `service_role`, `sb_secret_`, credenciales JSON de usuarios de prueba ni secretos en este ZIP. La operación es irreversible: úsala solamente cuando estés seguro de qué usuario se eliminará.
