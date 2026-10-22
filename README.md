# yasser-clientes

## App de comunicación para la barbería YASSER

App Android Flutter para conversar por UUID con los clientes de la barbería. Incluye registro por correo y contraseña, lista de clientes para el barbero, chat en tiempo real mientras la app está conectada, galería, historial de cortes, banner de horario y recordatorio local diario. No solicita teléfonos.

## Importante: servicio externo que debes crear

La app necesita un proyecto Supabase para guardar cuentas y mensajes. No se puede habilitar la comunicación real hasta configurar un proyecto propio y sus valores. No compartas la clave `service_role`: nunca va en la app. La clave `anon`/publishable está diseñada para la aplicación cliente; la seguridad depende de las políticas RLS.

Supabase Auth acepta correo y contraseña; `username` es el nombre visible del perfil, no una credencial para iniciar sesión.

## Preparar Supabase

1. Crea un proyecto en Supabase y guarda su URL y su anon/publishable key.
2. Ejecuta una sola vez [`supabase/schema.sql`](./supabase/schema.sql) en el SQL Editor.
3. Registra la cuenta del barbero con correo y contraseña desde la app. Confirma el correo si Supabase lo solicita.
4. En Supabase → Authentication → Users, copia el UUID del barbero.
5. En el SQL Editor, reemplaza el UUID en esta consulta y ejecútala:

   ```sql
   update public.profiles set role = 'barber' where id = 'UUID_DEL_BARBERO';
   insert into public.barber_settings (singleton, barber_id)
   values (true, 'UUID_DEL_BARBERO')
   on conflict (singleton) do update set barber_id = excluded.barber_id;
   ```

6. Realtime se añade a `public.profiles` y `public.messages` mediante el SQL. La lista del barbero se actualiza al registrarse nuevos clientes.

Si el registro/login funciona pero no aparecen clientes o no se pueden enviar mensajes, ejecuta [`supabase/diagnostics.sql`](./supabase/diagnostics.sql) en SQL Editor y verifica que `barber_profiles`, `barber_setting_rows` y `valid_barber_settings` sean `1`, y que `messages_realtime_enabled` y `profiles_realtime_enabled` sean `true`. `client_profiles` debe ser mayor que cero cuando ya se hayan registrado clientes. La consulta no devuelve correos, claves ni UUIDs.

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
2. En Settings → Secrets and variables → Actions, crea los secretos `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`, y la variable `BARBER_ID` con el UUID del barbero. Usa la clave Publishable (antes llamada anon) del proyecto Supabase, nunca una Secret key.
3. Desde esta carpeta, conecta el repositorio local ya inicializado y sube la rama `main`:

   ```powershell
   git remote add origin https://github.com/arnolds2014-cmd/yasser-clientes.git
   git push -u origin main
   ```

4. En GitHub → Actions, abre el workflow “Android debug APK”. Al completarse correctamente, descarga `clientes-de-barberia-debug-apk` desde los artifacts de la ejecución.

En cada `push`, el workflow ejecuta análisis, pruebas y compila un APK. Con los valores de Supabase configurados, el artifact se llama `clientes-de-barberia-debug-apk` y queda conectado al backend. Si faltan, genera `clientes-de-barberia-debug-apk-sin-supabase`; ese APK sirve para probar la interfaz, pero mostrará que falta configuración y no podrá comunicarse con clientes. `pull_request` solo ejecuta análisis y pruebas para no exponer secretos a contribuciones externas.

## Alcance de mensajes y notificaciones

El chat usa Supabase Realtime mientras el usuario está en línea y la app está abierta. El barbero puede seleccionar clientes, abrir un chat y guardar las especificaciones de sus cortes; cada cliente consulta solo su propio historial. Las notificaciones push de mensajes entrantes cuando la app está cerrada no están configuradas: requieren además registrar una aplicación Firebase/FCM y credenciales de servidor. El recordatorio de las 08:00 es una notificación **local** independiente. Android puede restringir alarmas exactas según permisos, ahorro de batería o fabricante; no es posible garantizar ejecución puntual en todos los teléfonos.

La alarma local se programa al entrar a la pantalla principal. El banner muestra ABIERTO desde 08:00 hasta antes de 20:00 según el reloj local. Las imágenes de galería son ejemplos y se deben reemplazar por fotografías autorizadas de la barbería.

## Archivos principales

- `lib/screens/`: autenticación, inicio cliente/barbero, chat, galería e historial.
- `lib/services/`: acceso a Supabase y recordatorio local.
- `lib/config/app_config.dart`: valida configuración inyectada al compilar.
- `supabase/schema.sql`: tablas, trigger de perfil y políticas de seguridad RLS.
- `tool/prepare_android.py`: incorpora permisos/receivers y desugaring requerido por notificaciones al proyecto Android generado por Flutter.
- `.github/workflows/android-debug.yml`: análisis, pruebas y compilación de APK en GitHub Actions.
