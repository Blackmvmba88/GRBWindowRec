# GRB Window Rec

Grabador ligero de cámara o pantalla para macOS, basado en FFmpeg y la
aceleración de video de Apple. No necesita mantener abierta una aplicación
Electron.

## Estado

Funcional y validado el 15 de agosto de 2026 en este equipo:

- video H.264 mediante `h264_videotoolbox`;
- audio AAC, 48 kHz;
- captura de cámara, pantalla principal o segunda pantalla;
- cursor y clics visibles al grabar la pantalla;
- salida MP4 optimizada para reproducción web (`faststart`).

La prueba real produjo una pista H.264 y una pista AAC mono. La señal del
micrófono no estaba vacía: nivel promedio de -26.9 dB y pico de -8.3 dB.

## Requisitos

- macOS con permisos de **Grabación de pantalla**, **Cámara** y **Micrófono**
  para Terminal (o para la aplicación desde la que se ejecute el script).
- FFmpeg instalado en `/opt/homebrew/bin/ffmpeg`.

## Uso

```sh
cd /Users/blackmamba/GRBWindowRec
./capturar.sh pantalla
```

Modos disponibles:

```sh
./capturar.sh camara
./capturar.sh pantalla
./capturar.sh pantalla2
./capturar.sh dispositivos
```

Presiona `q` para detener y cerrar correctamente el MP4. Las grabaciones se
guardan en `~/Movies/GRBWindowRec/` con fecha y hora en el nombre.

Para revisar dependencias, arquitectura, espacio libre y permisos:

```sh
./diagnostico.sh
```

## Aplicación macOS

Para construir la miniapp nativa:

```sh
./construir-app.sh
open "GRB Window Rec.app"
```

La ventana detecta dinámicamente las pantallas por su nombre real y las
aplicaciones que tienen ventanas visibles. Puedes grabar una pantalla completa
o aislar las ventanas de una aplicación concreta mediante ScreenCaptureKit.
También permite incluir por separado audio del sistema y micrófono, muestra el
tiempo transcurrido, abre la carpeta de resultados y reproduce la última
grabación. La barra espaciadora inicia o detiene.

El botón de actualización vuelve a consultar las fuentes cuando conectas una
pantalla o abres una aplicación nueva. GRB Window Rec se excluye a sí misma de
la captura de pantalla completa.

## Crear el instalador DMG

```sh
./crear-dmg.sh
```

El resultado queda en `dist/Light-Capture-VERSION.dmg`. Al abrirlo, arrastra
**GRB Window Rec** al acceso de **Applications**.

La versión se controla desde el archivo `VERSION`. El script compila la app,
incorpora el icono, aplica una firma local, crea el DMG comprimido y muestra su
checksum SHA-256.

### Distribución pública

La firma local permite probar y mover el DMG, pero una release pública sin
advertencias de Gatekeeper requiere:

1. certificado Apple Developer ID Application;
2. firma con hardened runtime;
3. envío a notarización con `notarytool`;
4. `stapler` sobre la app y el DMG.

No publiques claves, contraseñas específicas de aplicación ni perfiles de
notarización en el repositorio.

## Audio

El script graba el micrófono: en este equipo el dispositivo de audio `0` es
`Micrófono de Studio Display`. El dispositivo `1` es `BlackHole 2ch`.

Para elegir una fuente distinta:

```sh
AUDIO_DEVICE=1 ./capturar.sh pantalla
```

Los índices pueden cambiar cuando conectas o desconectas hardware. Confírmalos
antes de una sesión importante:

```sh
./capturar.sh dispositivos
```

Nota: BlackHole sólo captura audio si macOS o una configuración multidispositivo
está enviando sonido hacia él.

## Validar una grabación

El validador confirma que el archivo contiene pistas de video y audio y muestra
los niveles de la señal:

```sh
./validar.sh ~/Movies/GRBWindowRec/pantalla_FECHA_HORA.mp4
```

Tener una pista de audio no garantiza que se oyera algo durante toda la sesión.
Un valor `mean_volume: -inf dB` indica silencio digital.

## Solución de problemas

- **No aparece la pantalla o el micrófono:** revisa Ajustes del Sistema >
  Privacidad y seguridad y vuelve a abrir Terminal después de conceder permisos.
- **El archivo no abre:** detén siempre con `q`; cerrar la ventana o matar FFmpeg
  puede impedir que el contenedor MP4 se finalice.
- **Se grabó la fuente equivocada:** ejecuta `./capturar.sh dispositivos` y usa
  `AUDIO_DEVICE=N` para seleccionar el índice correcto.
- **No se oye el audio del sistema:** el modo predeterminado graba el micrófono,
  no el audio interno. Para audio interno usa BlackHole y enruta la salida hacia
  ese dispositivo.

## Archivos del proyecto

- `capturar.sh`: grabación y listado de dispositivos.
- `validar.sh`: inspección de pistas y nivel de audio.
- `diagnostico.sh`: comprobación rápida del entorno antes de grabar.
- `construir-app.sh`: compila y firma localmente la aplicación nativa.
- `crear-dmg.sh`: genera el instalador portable y su checksum SHA-256.
- `VERSION`: versión usada por la app, el DMG y las releases.
- `Sources/LightCaptureApp/`: interfaz SwiftUI y captura precisa con
  ScreenCaptureKit.
- `Assets/AppIcon.icns`: icono de la aplicación en resoluciones nativas de macOS.
- `ROADMAP.md`: mejoras previstas y criterios de avance.
- `~/Movies/GRBWindowRec/`: archivos generados; se crea automáticamente.

## Seguridad y privacidad

La captura ocurre localmente. El proyecto no sube archivos ni inicia grabaciones
en segundo plano. La pantalla y el micrófono sólo se capturan mientras FFmpeg
está ejecutándose.
