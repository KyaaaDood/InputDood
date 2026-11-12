# Historial de cambios

[🇬🇧 English](CHANGELOG.md) | 🇲🇽 Español

## 0.3

### Agregado
- **Interfaz visual** al estilo de SyncDood: barra lateral con las páginas *Estado*, *Atajos*, *Modo mouse*, *Opciones* y *Acerca de*, botones planos, tema claro/oscuro que sigue a Windows (o forzado), ventana redimensionable, inglés / español.
- **Atajos configurables**: agregar, editar, quitar y restaurar los predeterminados; grabar la combinación presionándola en el control; elegir *Siempre* o *Solo Modo mouse*; 27 acciones incluyendo tecla / texto personalizado. Botones disponibles: Guide, LB, RB, LT, RT, Start, Back, L3, R3, A, B, X, Y, cruceta y direcciones del stick derecho. Cuando las combinaciones se traslapan gana la más larga.
- *Prueba del control* en la página Estado: dibujo de un control estilo Xbox que ilumina cada botón que presionas y muestra en vivo los dos sticks y los gatillos.
- Los ajustes se guardan en `%AppData%\InputDood\config.ini` (velocidad del cursor, curva, zona muerta, umbral de gatillos, modo del aviso, idioma, tema, tiempo de gracia, atajos).
- Nuevo modo del aviso: ventana / pitidos / nada.
- **Los botones de scroll mantenidos siguen desplazando** (LB / RB por defecto): un paso al presionar y, tras una breve espera, se repite mientras se mantiene. Ambos tiempos se editan en la página *Modo mouse* (`scrollDelayMs`, `scrollRateMs`).

- **Modo administrador** (opcional): Windows no deja que un programa normal controle ventanas de administrador como el Administrador de tareas. *Opciones → Permitir controlar ventanas de administrador* crea (con una sola confirmación) tareas programadas para que el menú de la bandeja pueda **Reiniciar como administrador** y **Volver al modo normal** sin más avisos; opcionalmente InputDood puede iniciar elevado con Windows. Si **Guide + Start** no puede cerrar una ventana porque es de administrador, suenan dos pitidos graves y la página Estado te lo indica. El modo normal sigue siendo el predeterminado.

### Cambiado
- Los atajos predeterminados reproducen exactamente el comportamiento anterior.
- El clic izquierdo en el ícono de la bandeja abre la ventana. Cuando Windows inicia InputDood ("Ejecutar al iniciar") se queda en la bandeja sin abrirla (la entrada de inicio ahora lleva la bandera `/startup`; las antiguas se actualizan solas).
- Al cerrar la ventana se libera por completo (controles, imágenes, GDI+) y se devuelve la memoria sin usar a Windows, así que InputDood vuelve a unos pocos MB en la bandeja; la ventana se construye de nuevo al abrirla.
- La mayoría de las constantes que estaban al inicio del `.ahk` ahora son opciones de la ventana / `config.ini`.

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
