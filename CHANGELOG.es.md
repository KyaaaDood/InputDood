# Historial de cambios

[🇬🇧 English](CHANGELOG.md) | 🇲🇽 Español

## 0.2

### Corregido
- Al activar/desactivar el modo mouse (**Guide + Back**) con un juego a pantalla completa en primer plano (por ejemplo FIFA 17), el juego salía de pantalla completa y perdía el foco, porque el mensaje "Mouse Mode ON/OFF" es una ventana siempre visible (topmost).

### Cambiado
- InputDood ahora detecta cuándo la ventana activa está a pantalla completa (cubre todo el monitor y no tiene barra de título).
  - **Indicador de modo mouse:** en ese caso no se dibuja ninguna ventana; dos pitidos ascendentes = ON, dos descendentes = OFF.
  - **Teclado en pantalla (Y):** no se abre sobre una ventana a pantalla completa; suenan tres pitidos graves cortos. Si el teclado ya estaba abierto, se puede cerrar con normalidad.
- Nueva opción `FULLSCREEN_SAFE_MODE` (por defecto `true`) al inicio del `.ahk`; ponla en `false` para desactivar la detección de pantalla completa.
- README (EN/ES): nueva sección **Pantalla completa y anti-cheat** que documenta estas limitaciones, las soluciones alternas (optimizaciones de pantalla completa, ventana sin bordes) y los riesgos con anti-cheat y antivirus; lista de limitaciones actualizada.
- Versión subida a 0.2 (`APP_VERSION` y metadatos del exe).

## 0.1

- Primera versión: Guide + Start cierra/mata la ventana activa; modo mouse (Guide + Back) con indicador en pantalla y teclado en pantalla propio; menú de la bandeja; revisión de actualizaciones contra los releases de GitHub.
