# yasser-clientes

## App de comunicación para la barbería YASSER

App Android Flutter para conversar por UUID con los clientes de la barbería. Incluye registro por correo y contraseña, lista de clientes para el barbero, chat en tiempo real, galería administrable, banner de horario compartido y recordatorio local a la hora de apertura. No solicita teléfonos.

## Reinicio seguro del chat

La revisión inicial encontró un ciclo entre las políticas RLS de `profiles` y `messages`. Para rehacer la capa de chat sin borrar ni modificar esas tablas/datos anteriores, la nueva versión usa tablas aisladas con prefijo `yasser_`: `yasser_profiles`, `yasser_messages`, `yasser_haircut_history` y `yasser_barber_settings`. Sus políticas no se consultan recursivamente entre sí. Los usuarios actuales se copian a `yasser_profiles` con sus mismos UUID mediante el backfill del esquema.

No ejecutes ni vuelvas a ejecutar las antiguas políticas o `fix_message_policy_recursion.sql`. El esquema actual [`supabase/schema.sql`](./supabase/schema.sql) es la nueva instalación aditiva: crea las tablas `yasser_*` y no elimina tablas ni mensajes existentes.

## Importante: servicio externo que debes crear

La app necesita un proyecto Supabase para guardar cuentas y mensajes. No se puede habilitar la comunicación real hasta configurar un proyecto propio y sus valores. No compartas la clave `service_role`: nunca va en la app. La clave `anon`/publishable está diseñada para la aplicación cliente; la seguridad depende de las políticas RLS.

Supabase Auth acepta correo y contraseña; `username` es el nombre visible del perfil, no una credencial para iniciar sesión.

## Preparar o reiniciar Supabase sin borrar datos

1. Usa el proyecto Supabase que ya tienes y conserva su URL y clave Publishable.
2. Ejecuta el esquema actualizado [`supabase/schema.sql`](./supabase/schema.sql) en Supabase → SQL Editor. Es aditivo y no borra las tablas o mensajes de la versión anterior.
3. La consulta de backfill crea perfiles `yasser_profiles` para cuentas de Auth existentes, conservando su UUID. Regístrate otra vez en los dos APK solo si las cuentas no aparecen en la tabla nueva.
4. En Supabase → Authentication → Users, copia el UUID de la cuenta del barbero.
5. En SQL Editor, reemplaza el UUID en esta consulta y ejecútala (el mismo UUID debe configurar la variable `BARBER_ID` usada al compilar):

   ```sql
   insert into public.yasser_barber_settings (singleton, barber_id)
   values (true, 'UUID_DEL_BARBERO')
   on conflict (singleton) do update set barber_id = excluded.barber_id;
   ```

6. Realtime se añade a `yasser_profiles` y `yasser_messages`. La identidad de barbero en la app se determina comparando `auth.uid()` con `BARBER_ID`, no por un campo `role` editable.
7. Desinstala de los dos teléfonos el APK de prueba anterior, descarga el APK del último workflow y vuelve a instalarlo. APK debug de compilaciones distintas puede llevar certificados de firma distintos, y Android no permite actualizar sobre una firma diferente.

Para verificar el estado de la capa nueva, sustituye `UUID_DEL_BARBERO` en [`supabase/diagnostics.sql`](./supabase/diagnostics.sql) y ejecútalo. Debe mostrar `matching_barber_setting = 1`; los dos indicadores Realtime deben ser `true`.

## Ejecutar en Windows

Instala Flutter estable, Android Studio (Android SDK) y un JDK 17. Abre PowerShell en esta carpeta:

```powershell
flutter create --platforms=android --project-name yasser_barber --org com.yasser .
python tool/prepare_android.py
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLISHABLE --dart-define=BARBER_ID=UUID_DEL_BARBERO
```

Para compilar localmente:

```powershell
flutter build apk --debug --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLISHABLE --dart-define=BARBER_ID=UUID_DEL_BARBERO
```

El APK queda en `build\app\outputs\flutter-apk\app-debug.apk`. Si no se proporcionan las tres opciones `--dart-define`, la app mostrará la pantalla de configuración faltante en lugar de fallar al iniciar.

## Compilar en GitHub

El workflow [android-debug.yml](./.github/workflows/android-debug.yml) genera los archivos nativos Android, analiza el código, ejecuta pruebas y construye el APK debug. Para activarlo:

1. Usa el repositorio nuevo [`arnolds2014-cmd/yasser-clientes`](https://github.com/arnolds2014-cmd/yasser-clientes), no el repositorio contable. El repositorio nuevo está público; el código no debe incluir contraseñas, `service_role` ni claves privadas. Si prefieres que el código no sea público, cambia su visibilidad a privado en GitHub Settings.
2. En Settings → Secrets and variables → Actions, crea los secretos `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` y `FIREBASE_CONFIG_JSON`, y la variable `BARBER_ID` con el UUID del barbero. Guarda el contenido completo del `google-services.json` en `FIREBASE_CONFIG_JSON`. Usa la clave Publishable (antes llamada anon) del proyecto Supabase, nunca una Secret key. No subas archivos de claves de servidor a GitHub.
3. Desde esta carpeta, conecta el repositorio local ya inicializado y sube la rama `main`:

   ```powershell
   git remote add origin https://github.com/arnolds2014-cmd/yasser-clientes.git
   git push -u origin main
   ```

4. En GitHub → Actions, abre el workflow “Android debug APK”. Al completarse correctamente, descarga `clientes-de-barberia-debug-apk` desde los artifacts de la ejecución.

En cada `push`, el workflow ejecuta análisis, pruebas y compila un APK. Con Supabase y Firebase configurados, el artifact se llama `clientes-de-barberia-debug-apk` y queda conectado al backend. Si falta alguno, genera `clientes-de-barberia-debug-apk-sin-supabase`; ese APK no está listo para mensajería conectada. `pull_request` solo ejecuta análisis y pruebas para no exponer secretos a contribuciones externas.

## Alcance de mensajes y notificaciones

El chat usa Supabase Realtime mientras el usuario está en línea y la app está abierta. El barbero puede seleccionar clientes, abrir un chat y guardar las especificaciones de sus cortes; cada cliente consulta solo su propio historial. FCM entrega avisos de mensajes entrantes con la app en segundo plano o cerrada. Para habilitarlo, además de configurar `FIREBASE_CONFIG_JSON` en GitHub:

1. Ejecuta [`supabase/push_notifications.sql`](./supabase/push_notifications.sql) en Supabase → SQL Editor. Esta migración crea una tabla nueva de tokens con RLS y no modifica ni borra los mensajes.
2. En Firebase Console, genera una clave de cuenta de servicio para el proyecto de mensajería y confirma que la API Firebase Cloud Messaging (HTTP v1) esté habilitada. Si la cuenta no tiene permiso para enviar FCM, asígnale el rol `Firebase Cloud Messaging API Admin` en Google Cloud IAM. La clave privada es confidencial: no la pongas en el APK, en GitHub ni en el repositorio.
3. Despliega la Edge Function: `supabase functions deploy send-message-push --no-verify-jwt`.
4. En Supabase → Edge Functions → Secrets, configura `FIREBASE_SERVICE_ACCOUNT` con el JSON completo de la cuenta de servicio y `YASSER_WEBHOOK_SECRET` con un secreto aleatorio largo. No compartas esos valores.
5. En Supabase → Database → Webhooks, crea un webhook para `public.yasser_messages`, evento `INSERT`, que invoque la función `send-message-push`. Añade el encabezado `x-yasser-webhook-secret` con el mismo valor de `YASSER_WEBHOOK_SECRET`.
6. Sube el cambio al repositorio para que GitHub Actions cree el nuevo APK; instala esa versión en ambos teléfonos y acepta el permiso de notificaciones.

La función solo envía un aviso genérico, no incluye el contenido privado del mensaje. La tabla `yasser_push_tokens` guarda los tokens por UUID y cada usuario solo puede administrar el suyo. El aviso diario de apertura es una notificación **local** independiente de los push de chat. Android puede restringir alarmas exactas según permisos, ahorro de batería o fabricante; no es posible garantizar ejecución puntual en todos los teléfonos.

La alarma local se programa al entrar a la pantalla principal usando el horario guardado.

## Horario, galería y recursos visuales editables

Antes de usar el horario editable y la galería administrada desde la app, ejecuta una vez [`supabase/management_features.sql`](./supabase/management_features.sql) en SQL Editor. La migración agrega horarios al registro existente del barbero, permite que cada usuario cambie únicamente su nombre visible, crea una galería de lectura para clientes y restringe subir/quitar fotos al UUID del barbero. También crea el bucket público `yasser-gallery` para fotos de cortes; no contiene ni borra los mensajes existentes.

En la app, el barbero abre **Editar horario** para cambiar apertura y cierre; el banner del cliente escucha esos cambios con Realtime. Al tener la app abierta, los teléfonos también actualizan el recordatorio local diario a la nueva hora de apertura. Si el cliente tiene la app cerrada justo cuando el horario se modifica, la alarma local se actualiza cuando vuelva a abrirla; para avisos remotos con la app cerrada hace falta que FCM/webhook esté completamente desplegado.

El barbero administra las fotografías en **Administrar galería**. Los clientes solo consultan la galería y envían una referencia por chat. El perfil permite cambiar el nombre visible propio. Las imágenes que se pueden reemplazar son:

- `assets/images/home_background.jpg`: fondo de inicio.
- `assets/images/chat_background.jpg`: fondo del chat (se dejó con la misma imagen como base reemplazable).
- `assets/images/yasser_logo.png`: fuente del icono de la app.

El workflow ejecuta `tool/prepare_android.py` tras generar Android; el script repone los iconos de launcher en `tool/android_icons/mipmap-*` para que Flutter no los sobrescriba con el icono predeterminado al compilar.

## Archivos principales

- `lib/screens/`: autenticación, inicio cliente/barbero, chat, galería e historial.
- `lib/services/`: acceso a Supabase y recordatorio local.
- `lib/config/app_config.dart`: valida configuración inyectada al compilar.
- `supabase/schema.sql`: tablas, trigger de perfil y políticas de seguridad RLS.
- `tool/prepare_android.py`: incorpora permisos/receivers y desugaring requerido por notificaciones al proyecto Android generado por Flutter.
- `.github/workflows/android-debug.yml`: análisis, pruebas y compilación de APK en GitHub Actions.
