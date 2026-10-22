# Clientes de barbería YASSER

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
   values (true, 'UUID_DEL_BARBERO');
   ```

6. Realtime se añade a `public.messages` mediante el SQL. El barbero podrá ver la lista de perfiles de clientes y abrir sus conversaciones.

## Ejecutar en Windows

Instala Flutter estable, Android Studio (Android SDK) y un JDK 17. Abre PowerShell en esta carpeta:

```powershell
flutter create --platforms=android --project-name yasser_barber --org com.yasser .
python tool/prepare_android.py
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY --dart-define=BARBER_ID=UUID_DEL_BARBERO
```

Para compilar localmente:

```powershell
flutter build apk --debug --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY --dart-define=BARBER_ID=UUID_DEL_BARBERO
```

El APK queda en `build\app\outputs\flutter-apk\app-debug.apk`. Si no se proporcionan las tres opciones `--dart-define`, la app mostrará la pantalla de configuración faltante en lugar de fallar al iniciar.

## Compilar en GitHub

El workflow [android-debug.yml](./.github/workflows/android-debug.yml) genera los archivos nativos Android, analiza el código, ejecuta pruebas y construye el APK debug. Para activarlo:

1. Crea un repositorio nuevo y vacío en tu cuenta de GitHub (no uses el repositorio contable).
2. En Settings → Secrets and variables → Actions, crea los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY`, y la variable `BARBER_ID` con el UUID del barbero.
3. Desde esta carpeta, conecta el repositorio local ya inicializado y sube la rama `main` (cambia `TU_USUARIO` por tu cuenta):

   ```powershell
   git remote add origin https://github.com/TU_USUARIO/clientes-de-barberia.git
   git push -u origin main
   ```

4. En GitHub → Actions, abre el workflow “Android debug APK”. Al completarse correctamente, descarga `clientes-de-barberia-debug-apk` desde los artifacts de la ejecución.

En las ejecuciones de `push` y `workflow_dispatch`, el workflow falla intencionalmente si faltan los valores de Supabase, para no entregar un APK que parezca operativo pero no pueda comunicarse. En `pull_request` ejecuta análisis y pruebas, pero omite el APK para que las contribuciones externas no requieran acceso a secretos.

## Alcance de mensajes y notificaciones

El chat usa Supabase Realtime mientras el usuario está en línea y la app está abierta. Las notificaciones push de mensajes entrantes cuando la app está cerrada no están configuradas: requieren además registrar una aplicación Firebase/FCM y credenciales de servidor. El recordatorio de las 08:00 es una notificación **local** independiente. Android puede restringir alarmas exactas según permisos, ahorro de batería o fabricante; no es posible garantizar ejecución puntual en todos los teléfonos.

La alarma local se programa al entrar a la pantalla principal. El banner muestra ABIERTO desde 08:00 hasta antes de 20:00 según el reloj local. Las imágenes de galería son ejemplos y se deben reemplazar por fotografías autorizadas de la barbería.

## Archivos principales

- `lib/screens/`: autenticación, inicio cliente/barbero, chat, galería e historial.
- `lib/services/`: acceso a Supabase y recordatorio local.
- `lib/config/app_config.dart`: valida configuración inyectada al compilar.
- `supabase/schema.sql`: tablas, trigger de perfil y políticas de seguridad RLS.
- `tool/prepare_android.py`: incorpora permisos/receivers y desugaring requerido por notificaciones al proyecto Android generado por Flutter.
- `.github/workflows/android-debug.yml`: análisis, pruebas y compilación de APK en GitHub Actions.
