# Roadmap

## Versión actual — CLI estable

- [x] Captura de cámara y dos pantallas.
- [x] Micrófono configurable mediante `AUDIO_DEVICE`.
- [x] Codificación H.264 acelerada por hardware y audio AAC.
- [x] Listado de dispositivos disponibles.
- [x] Validación de pistas y detección básica de silencio.
- [x] Documentación de permisos, uso y recuperación de fallos comunes.

## Próximo — experiencia confiable

- [ ] Detectar dispositivos por nombre para evitar índices cambiantes.
- [ ] Añadir una prueba guiada de cinco segundos antes de sesiones importantes.
- [ ] Comprobar espacio libre antes de grabar.
- [ ] Manejar `SIGINT`/`SIGTERM` y asegurar el cierre limpio del MP4.
- [ ] Permitir calidad, FPS y carpeta de salida mediante opciones claras.

## Después — audio y operación

- [ ] Perfil documentado para audio interno con BlackHole.
- [ ] Mezcla opcional de micrófono y audio del sistema.
- [ ] Indicador visible de grabación y duración.
- [ ] Pausar/reanudar o documentar una alternativa segura.
- [ ] Rotación automática en segmentos para sesiones largas.

## Futuro — aplicación macOS

- [x] Ventana nativa con iniciar/detener y temporizador.
- [x] Selector de pantalla, aplicación y fuentes de audio.
- [x] Acceso a grabaciones y reproducción de la última captura.
- [x] Detección dinámica de pantallas por nombre y resolución.
- [x] Captura aislada de aplicaciones con ventanas visibles.
- [x] Audio del sistema y micrófono configurables por separado.
- [ ] Interfaz opcional en la barra de menús.
- [ ] Vista previa y medidor de nivel del micrófono.
- [ ] Atajo global configurable.
- [ ] Flujo guiado de permisos dentro de la aplicación.
- [x] Empaquetado reproducible en DMG con acceso a Applications.
- [ ] Firma Developer ID y notarización para distribución pública.
- [ ] Automatización de GitHub Release al publicar una etiqueta de versión.

## Criterio para declarar una versión estable

Una versión se considera lista cuando una prueba real genera un MP4 reproducible,
con duración correcta, al menos una pista de video, una pista de audio con señal,
y cierre limpio al detener la grabación.
