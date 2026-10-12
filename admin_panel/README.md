# admin_panel (Flutter Web)

Panel de administración de CCTV CANAL 7, conectado al proyecto de Firebase
**canal7app**. La documentación general está en [../README.md](../README.md).

## Correr en local

```
flutter run -d chrome
```

Necesita que exista `tenantsPublic/canal7` (ver "Puesta en marcha" en el
README principal).

## Desplegar a producción

```
powershell -ExecutionPolicy Bypass -File deploy-hosting.ps1
```

(Windows bloquea correr `.ps1` por política de ejecución por defecto; el
flag de arriba lo salta solo para esta ejecución, sin cambiar la política
del sistema.)

Compila, copia el resultado a `../firebase/public` (Hosting no puede servir
desde fuera de la carpeta de `firebase.json`) y despliega a
**https://canal7app.web.app**.
