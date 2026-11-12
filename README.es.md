# 🎮 InputDood — Cerrador de tareas con Guide + Start y modo mouse para controles XInput

[🇬🇧 English](README.md) | 🇲🇽 Español

App ultraligera de AutoHotkey v2 con una interfaz visual sencilla que corre en segundo plano y, por defecto, envía **WinClose + WinKill** cuando presionas **Guide** (Xbox/Home) **+ Start** al mismo tiempo en cualquier control compatible con XInput. ⚡

El objetivo principal de la app es usarse en una configuración HTPC desde el sillón, para cerrar juegos que por alguna razón no tienen opción de salir al escritorio, pero prácticamente puede cerrar cualquier programa que esté en primer plano.

Además, incluye un **modo completo de mouse + teclado** opcional (se activa con **Guide + Back**) para que controles toda tu PC desde el sillón sin tener que agarrar un mouse o teclado, incluyendo un teclado en pantalla integrado.

## ✨ Características

- 🎮 Detecta el combo **en cualquier control XInput** (Xbox 360, One, Series y la mayoría de los controles de terceros/clones), sin necesidad de mapear botones por dispositivo.
- 🪟 **Interfaz visual (nuevo en 0.3)** — ventana al estilo de SyncDood (barra lateral, tema claro/oscuro que sigue a Windows, botones planos) con estado del control en vivo, editor de atajos, ajustes del modo mouse y opciones. Se abre desde el ícono de la bandeja.
- ⌨️ **Atajos configurables (nuevo en 0.3)** — agrega, edita o quita cualquier atajo del control (botones sueltos o combinaciones, incluyendo gatillos y direcciones del stick derecho) y elige qué hace; presiona los botones en tu control para grabar la combinación.
- 👻 Se queda en segundo plano con un ícono en la bandeja; cuando Windows lo inicia ("Ejecutar al iniciar") no abre la ventana.
- 🪶 Uso de CPU muy bajo: sondeo optimizado cada 100 ms, con un caché de qué ranuras de control están conectadas para evitar llamadas innecesarias (0% de uso en mi Ryzen 5600X y solo 4 MB de RAM).
- 🖱️ **Modo completo de mouse y teclado** — mueve el cursor, haz clic, desplázate, controla medios/volumen e incluso escribe con un teclado en pantalla integrado, todo desde el control.
- 🟢 **Indicador en pantalla de "Mouse Mode ON/OFF"** — un mensaje grande, centrado y que se desvanece solo cada vez que activas o desactivas el modo mouse, para que siempre sepas su estado de un vistazo desde el sillón. No depende de las notificaciones de Windows (que no son confiables con scripts/exes sin firmar) porque lo dibuja el propio InputDood.
- ⌨️ **Teclado en pantalla propio** — se puede arrastrar, se posiciona arriba del cursor para no tapar el campo donde estás escribiendo, tiene distribuciones de letras y símbolos, una tecla Shift tipo bloqueo de mayúsculas, retroalimentación visual al presionar cada tecla y no depende del teclado en pantalla de Windows (que puede estar roto por herramientas de debloat o bloqueado por la elevación de UAC en algunos equipos).
- 🔄 **Actualizaciones automáticas** — revisa tus releases de GitHub en segundo plano al iniciar (en silencio, sin ventanas a menos que realmente haya algo nuevo) y te deja revisar manualmente desde el menú de la bandeja cuando quieras.
- 🖱️ Menú en el ícono de la bandeja (clic izquierdo o derecho).
- ⚠️ Muestra un aviso de requisitos la primera vez que se ejecuta.

## 🧠 Cómo funciona

XInput no expone el botón Guide a través de su API pública (`XInputGetState`); Windows lo reserva para su propia interfaz. Este script usa `XInputGetStateEx`, una función no documentada pero muy sólida y estable desde hace más de una década (también usada por herramientas como x360ce y DS4Windows), que sí incluye el bit del botón Guide en la máscara de botones.

En cada tick del temporizador consulta el estado de las 4 ranuras posibles de control (0-3) mediante `DllCall` a `xinput1_4.dll`, y si la máscara de botones coincide con `START | GUIDE`, envía `WinClose + WinKill` con `Send()`.

El sondeo se acelera automáticamente (de 100 ms a 16 ms) mientras el modo mouse está activo, para que el movimiento del cursor se sienta fluido, y vuelve a bajar cuando está apagado para mantener el uso de CPU al mínimo.

## 📋 Requisitos

- 🤖 **[AutoHotkey v2](https://www.autohotkey.com/)** — solo hace falta si ejecutas directamente el script `.ahk`. Si usas el `.exe` compilado de la página de Releases, el runtime de AutoHotkey ya viene incluido y no necesitas instalar nada más.
- 🪟 Windows 8 o posterior (usa `xinput1_4.dll`, incluida por defecto en el sistema).

Nota: *[SuperF4](https://github.com/stefansundin/superf4) instalado y en ejecución — solo se necesita si usas la variante `InputDood with Super F4.ahk` (la versión antigua basada en SuperF4).*

## 📦 Instalación

### Opción A: Ejecutable compilado
1. Descarga el `.exe` desde [Releases](../../releases) (o compílalo tú mismo, ve más abajo).
2. Ejecuta el programa. Aparecerá un ícono en la bandeja (una **I** roja). 🎮
3. *(Opcional)* Clic derecho en el ícono de la bandeja → "Ejecutar al iniciar" (o el interruptor de la página *Opciones*). 🚀

### Opción B: Desde el código fuente
1. Instala [AutoHotkey v2](https://www.autohotkey.com/).
2. Descarga `InputDood.ahk` de este repo (y la carpeta `icons` junto a él si quieres el ícono de la bandeja).
3. Ejecuta el script con doble clic, o compílalo tú mismo con Ahk2Exe (clic derecho en el `.ahk` → *Compile Script*; el ícono de `icons\InputDood.ico` se aplica automáticamente).

## ▶️ Uso

1. Ejecuta este script (o su `.exe`). Se abre la ventana; ciérrala y InputDood sigue corriendo en la bandeja. 🎮
2. Con la ventana que quieres cerrar en primer plano, presiona **Guide + Start** en tu control. 💥
3. Presiona **Guide + Back** para activar/desactivar el modo mouse y tomar el control completo de tu PC desde el sillón (consulta la tabla de abajo).
4. ¿Quieres otros botones? Abre la página **Atajos** y cámbialos (siguiente sección).

## 🪟 Ventana y atajos personalizados

Clic izquierdo en el ícono de la bandeja (o *Abrir InputDood*) para abrir la ventana. Páginas:

- **Estado** — si hay control detectado, estado del modo mouse, tus atajos principales y una *prueba del control* en vivo que muestra los botones que estás presionando.
- **Atajos** — la lista de todos los atajos. **Agregar**, **Editar** (o doble clic), **Quitar** o **Restaurar los predeterminados**.
- **Modo mouse** — velocidad del cursor, curva de respuesta, zona muerta, umbral de gatillos, cómo se muestra el aviso ON/OFF (ventana / pitidos / nada) y el interruptor de pantalla completa segura.
- **Opciones** — idioma, tema (auto / claro / oscuro), tiempo de gracia al cerrar, ejecutar al iniciar, buscar actualizaciones, abrir `config.ini`.
- **Acerca de** — versión, enlaces, búsqueda manual de actualizaciones.

### Editar un atajo

1. Presiona **Agregar** (o selecciona uno y presiona **Editar**).
2. Haz clic en **Presionar en el control** y mantén a la vez los botones que quieras; suéltalos y la combinación queda grabada. También puedes escribirla, por ejemplo `Guide+Start`.
3. Elige **cuándo** funciona: **Siempre**, o **Solo Modo mouse**.
4. Elige la **acción** (cerrar ventana, activar modo mouse, clics, scroll, Enter/Esc/Espacio/Tab/flechas, Alt+Tab, tecla Windows, multimedia/volumen, teclado en pantalla…). *Enviar una tecla o texto* y *Mantener una tecla* te dejan escribir tu propia tecla (sintaxis de AutoHotkey, por ejemplo `{F11}`, `^c` o `Space`).

Botones que puedes usar: Guide, LB, RB, LT, RT, Start, Back, L3, R3, A, B, X, Y, cruceta (4 direcciones) y direcciones del stick derecho (4).

Reglas: cuando dos combinaciones se traslapan, **gana la más larga** (con Guide + Start se ejecuta solo ese atajo, no Start solo). Los atajos *Siempre* responden a cualquier control conectado; los de *Solo en modo mouse* responden al primer control. Los atajos predeterminados reproducen exactamente lo que dice la tabla de abajo.

## 🖱️ Modo mouse

Se activa con **Guide + Back**. Mientras está activo, todos los botones del control hacen algo útil; no queda ninguno sin asignar:

| Botón | Acción | Notas |
|---|---|---|
| **Guide + Back** | Activa/desactiva el modo mouse | Funciona en cualquier momento, desde cualquier lugar |
| **Guide + Start** | Cierra/mata la ventana activa | Sigue funcionando con el modo mouse activo, como red de seguridad |
| Stick izquierdo | Mueve el cursor | Respuesta lineal por defecto, zona muerta y velocidad ajustables |
| Stick derecho (arriba/abajo) | Subir/bajar volumen | Se repite mientras lo mantengas inclinado |
| Stick derecho (izquierda/derecha) | Pista anterior/siguiente | Una vez por inclinación (hay que regresarlo al centro para que se active de nuevo) |
| RT (gatillo) | Clic izquierdo | Gatillo analógico, se mantiene mientras pase el umbral |
| LT (gatillo) | Clic derecho | Gatillo analógico, se mantiene mientras pase el umbral |
| RB | Desplazar hacia arriba | Un paso por presión |
| LB | Desplazar hacia abajo | Un paso por presión |
| A | Enter | Se mantiene presionado mientras sostengas el botón |
| B | Escape | Se mantiene presionado mientras sostengas el botón |
| X | Clic central | Se mantiene presionado mientras sostengas el botón |
| Y | Mostrar/ocultar teclado en pantalla | Teclado propio integrado, ve más abajo |
| Cruceta | Teclas de flecha | Se mantienen presionadas, admite la repetición de teclas del sistema |
| L3 (clic del stick izquierdo) | Alt+Tab | Un toque = un cambio |
| R3 (clic del stick derecho) | Reproducir/Pausar medios | Un toque |
| Start (solo, sin Guide) | Tecla Windows | Abre el menú Inicio |
| Back (solo, sin Guide) | Tab | Útil para recorrer los campos de la interfaz |

Al desactivar el modo mouse se sueltan automáticamente las teclas o clics que pudieran haberse quedado presionados, para que nada se "atore".

Cada vez que lo activas o desactivas, aparece un mensaje grande y centrado durante un par de segundos que se desvanece solo: **"Mouse Mode ON"** en verde al activarlo y **"Mouse Mode OFF"** en rojo al desactivarlo, así se nota de un vistazo desde lejos si el control está manejando el mouse o no.

> 🔊 **En juegos a pantalla completa** el mensaje no se dibuja (ver [Pantalla completa](#️-pantalla-completa-y-anti-cheat)); en su lugar suenan **dos pitidos ascendentes** al activar y **dos descendentes** al desactivar.

### ⌨️ Teclado en pantalla

Presiona **Y** en modo mouse para mostrar/ocultar un teclado en pantalla propio, construido por completo dentro de la app, sin depender de `osk.exe` de Windows ni del teclado táctil (`TabTip.exe`), que pueden fallar (problemas de elevación o servicios faltantes tras hacer debloat de Windows).

- Mueve el cursor con el stick izquierdo y presiona las teclas con **RT**, igual que cualquier otro botón en pantalla. Cada tecla se ilumina al presionarse, para que siempre tengas una respuesta visual clara.
- Cada vez que lo abres, aparece centrado arriba de donde esté el cursor en ese momento (o abajo del cursor si no hay espacio arriba), para no estorbar el campo de texto que vas a usar. Mientras está abierto, todavía puedes arrastrarlo a donde quieras por su barra superior.
- **⇧ Shift** funciona como interruptor (como el bloqueo de mayúsculas): tócalo para cambiar a mayúsculas y vuelve a tocarlo para regresar; las teclas de letras cambian de caso para que veas en qué modo estás.
- **⌫ Retroceso** se repite automáticamente si lo mantienes presionado, sin tener que pulsarlo una y otra vez.
- **?123 / ABC** alterna entre la distribución de letras y la de símbolos/puntuación (`< >`, `@#$%`, paréntesis, comillas, etc.).
- **✕** cierra el teclado desde su propia barra de título.
- 🔊 **No se abre sobre juegos a pantalla completa**: si presionas **Y** con un juego en fullscreen, suenan **tres pitidos graves cortos** y el teclado no aparece (para no sacarte del juego). Ve [Pantalla completa](#️-pantalla-completa-y-anti-cheat).

## 🗂️ Menú de la bandeja

- 🪟 **Abrir InputDood** — abre la ventana (también es el clic izquierdo).
- 🖱️ **Modo mouse** — actívalo sin usar el control.
- ℹ️ **About** — créditos del proyecto e instrucciones.
- 🔄 **Check for updates** (Buscar actualizaciones) — le pregunta a GitHub por la última versión al instante. Si ya tienes la más reciente, te lo avisa; si hay una actualización, te ofrece abrir la página de descarga.
- ☕ **Donations** — enlace a [Patreon](https://www.patreon.com/cw/KyaaaDood).
- 🚀 **Run at startup** — ejecutar al iniciar Windows.
- ❌ **Exit** — cierra el script.

El clic izquierdo abre la ventana; el derecho abre este menú.

Además de la revisión manual, InputDood también busca actualizaciones en silencio unos segundos después de iniciar: si no hay nada nuevo, no dice nada; si hay una versión más reciente, muestra el mismo aviso de "actualización disponible" que la revisión manual.

## 🖥️ Pantalla completa y anti-cheat

**Pantalla completa.** El aviso de "Mouse Mode" y el teclado en pantalla son ventanas normales de Windows que se dibujan *encima* de lo que tengas abierto. Los juegos en **pantalla completa exclusiva** (DirectX, por ejemplo FIFA 17) no toleran que aparezca otra ventana encima: Windows los minimiza, los saca de pantalla completa o les quita el foco. Por eso, desde la v0.2, InputDood detecta cuando la ventana activa está a pantalla completa y se comporta así:

| Situación | Aviso de modo mouse | Teclado en pantalla |
|---|---|---|
| Ventana normal / escritorio | Mensaje en pantalla | Funciona normal |
| Juego a pantalla completa | 2 pitidos ascendentes (ON) / 2 descendentes (OFF) | No se abre; 3 pitidos graves cortos |

El cursor, los clics, el scroll, el volumen y el resto de los botones del modo mouse **sí funcionan** en pantalla completa; lo que no se puede es *dibujar* cosas encima del juego.

Para poder usar el teclado en pantalla dentro de un juego tienes estas opciones:

1. **Optimizaciones de pantalla completa de Windows.** Clic derecho al `.exe` del juego → Propiedades → Compatibilidad, y desmarca *"Deshabilitar optimizaciones de pantalla completa"*. En muchos juegos DX11 Windows entonces los trata casi como ventana sin bordes. Si tras hacerlo el juego ya no pierde el foco, de para que InputDood vuelva a mostrar el aviso y el teclado ahí, pon desmarca *No dibujar ventanas sobre juegos en pantalla completa* al inicio del `.ahk` (ver [Configuración](#-configuración)).
2. **Ventana sin bordes (borderless).** Pon el juego en modo ventana a la resolución nativa y usa una herramienta como Borderless Gaming para quitarle el borde. Es el método más confiable.
3. **Overlays dentro del juego** (el teclado de Steam, por ejemplo) funcionan porque se inyectan en el juego. InputDood **no** hace esto y no lo hará: es justo el comportamiento que los anti-cheat marcan.

> ℹ️ Con desmarca *No dibujar ventanas sobre juegos en pantalla completa* se desactiva esta detección. Por defecto la detección considera "pantalla completa" a cualquier ventana sin barra de título que cubra todo el monitor, así que también aplica a juegos en modo sin bordes. En esos casos el aviso visual y el teclado también se reemplazan por pitidos.

**Anti-cheat.** InputDood está hecho con AutoHotkey y simula entradas de mouse/teclado (`MouseMove`, `Click`, `Send`) y puede cerrar procesos (`WinKill`). Algunos anti-cheat, sobre todo los de nivel kernel (Vanguard, EasyAntiCheat, BattlEye, etc.), detectan o restringen justo ese tipo de herramientas, por lo que:

- Podrías recibir una advertencia, que se bloquee el juego o, en el peor caso, un baneo. **No se garantiza compatibilidad con ningún juego en línea.**
- **No lo uses con juegos en línea competitivos protegidos por anti-cheat** a menos que aceptes el riesgo. Para juegos de un jugador/offline no suele haber problema.
- Si necesitas más seguridad, cierra InputDood (menú de la bandeja → Exit) antes de abrir el juego.
- InputDood no se inyecta en otros procesos, no lee memoria de otros programas ni se ejecuta elevado, pero eso no evita que un anti-cheat lo marque solo por usar AutoHotkey.
- Esto también aplica a la **detección de antivirus**: el `.exe` compilado puede dar falsos positivos por ser AutoHotkey.

## ⚠️ Limitaciones conocidas

- 🗝️ Tu antivirus puede bloquear esta aplicación, pero siempre puedes revisar el código fuente si tienes alguna sospecha.
- 🎮 Si tu control no es totalmente compatible con el driver XInput de Windows (por ejemplo, algunos controles solo DirectInput), puede que el botón Guide no se detecte.
- 🔒 InputDood corre sin elevación por diseño (es más seguro y tiene menos probabilidad de ser marcado por los anti-cheat). Esto significa que no puede enviar clics/teclas a ventanas que se ejecuten como Administrador; para eso tendrías que ejecutar InputDood elevado también, lo cual no se recomienda en juegos en línea con anti-cheat a nivel de kernel.
- 🖥️ No puede dibujar el aviso de modo mouse ni el teclado en pantalla sobre juegos a pantalla completa (ver [Pantalla completa y anti-cheat](#️-pantalla-completa-y-anti-cheat)); en esos casos usa pitidos.
- ❌ Es probable que algunos anti-cheat te adviertan por esta app porque usa AutoHotkey. **ÚSALA BAJO TU PROPIO RIESGO, TEN CUIDADO**.

## 🔧 Configuración

Desde la 0.3 todo se cambia desde la ventana y se guarda en **`%AppData%\InputDood\config.ini`** (la página *Opciones* tiene botones para abrir el archivo o su carpeta). También puedes editarlo a mano:

```ini
[general]
language=auto            ; auto | en | es
theme=auto               ; auto | light | dark
checkUpdates=1
fullscreenSafe=1
forceKillGraceSec=2

[mouse]
indicator=window         ; window | beep | none
cursorSpeed=32           ; 1-100
curve=linear             ; linear | precise | sensitive
deadzonePct=24           ; 5-40
triggerPct=39            ; 10-90

[bindings]
count=2
b1=always|Guide+Start|close_window
b2=always|Guide+Back|toggle_mouse
```

Cada atajo es `alcance|botones|acción` (`alcance` = `always` o `mouse`; las acciones personalizadas se escriben `custom_tap:{F11}` / `custom_hold:Space`). Si no existe `[bindings]` se usan los predeterminados.

Algunos valores avanzados siguen siendo constantes al inicio del `.ahk`: `APP_VERSION`, `GITHUB_REPO`, `POLL_INTERVAL_IDLE_MS` (100), `POLL_INTERVAL_MOUSE_MS` (16), `VOLUME_REPEAT_MS` (120), `MEDIA_TRACK_DEADZONE` (20000) y `MOUSE_INDICATOR_DURATION_MS` (2500).

## 📝 Historial de cambios

Consulta [CHANGELOG.es.md](CHANGELOG.es.md).

## 🔨 Compilar el `.exe`

Haz doble clic en **`Build.bat`** (Windows, sin permisos de administrador). La primera vez descarga AutoHotkey v2 y Ahk2Exe en `build\cache`, y luego compila todo en **`dist\InputDood.exe`**: un solo archivo con el runtime de AutoHotkey y el ícono incluidos. La versión del exe se toma de `APP_VERSION` en `InputDood.ahk`. Si tu red bloquea las descargas, coloca `AutoHotkey64.exe` (v2) y `Ahk2Exe.exe` en `build\cache` y vuelve a ejecutarlo.

## 📄 Licencia

InputDood es software libre bajo la **[GNU GPL v2](LICENSE)**. Puedes usarlo, estudiarlo, modificarlo y compartirlo; si lo distribuyes (o distribuyes una versión modificada), debe mantenerse con la misma licencia e ir acompañado de su código fuente.

El `InputDood.exe` compilado incluye [AutoHotkey v2](https://www.autohotkey.com) (GPLv2). Sus avisos y enlaces al código fuente están en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 💛 Créditos

Hecho por **KyaaaDood** con Claude AI. 🤖✨

Si quieres, puedes apoyarme en [Patreon](https://www.patreon.com/cw/KyaaaDood).

InputDood incluye [AutoHotkey v2](https://www.autohotkey.com) (GPLv2); consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
