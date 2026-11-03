# CalorieGraph

App Flutter de uso personal para registrar peso, calorías, agua y medidas, ver
gráficas de evolución y mantener objetivos y recordatorios.

## Ejecutar en Android

1. Instala Flutter y configura el SDK de Android.
2. Configura Firebase para tu proyecto Android y coloca tu `google-services.json`
   en `android/app/`.
3. Desde esta carpeta, ejecuta `flutter pub get` y `flutter run`.

Las reglas de Firestore están en `firestore.rules`. Para desplegarlas con Firebase
CLI, ejecuta `firebase deploy --only firestore:rules` después de seleccionar tu
proyecto.
