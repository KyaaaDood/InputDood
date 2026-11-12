; Estas directivas las lee Ahk2Exe automáticamente al compilar y graba
; los metadatos dentro del .exe (los que ves en Propiedades > Detalles
; de un ejecutable en Windows). Un exe sin nombre de compañía, versión
; ni descripción se ve más "genérico/sospechoso" para varios motores
; heurísticos que uno con esta información — y de paso, se ve más
; profesional. No requiere que hagas nada extra al compilar, solo que
; el .ahk tenga estas líneas (súbele el número de versión en cada release).
;@Ahk2Exe-SetName InputDood
;@Ahk2Exe-SetDescription InputDood - Gamepad shortcuts and mouse mode
;@Ahk2Exe-SetVersion 0.3.0.0
;@Ahk2Exe-SetProductVersion 0.3.0.0
;@Ahk2Exe-SetMainIcon icons\InputDood.ico
;@Ahk2Exe-SetProductName InputDood
;@Ahk2Exe-SetCompanyName KyaaaDood
;@Ahk2Exe-SetCopyright Copyright (c) 2026 KyaaaDood


#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Current version and GitHub repo, used by the auto-updater and the About page.
; Bump APP_VERSION with every release you make (and the ;@Ahk2Exe-Set... lines above).
APP_VERSION := "0.3"
GITHUB_REPO := "kyaaadood/InputDood"
APP_AUTHOR  := "KyaaaDood"
GITHUB_URL  := "https://github.com/kyaaadood"
PATREON_URL := "https://www.patreon.com/cw/KyaaaDood"

RUN_KEY := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
RUN_VALUE_NAME := "InputDood"

; ---- Paths. Settings live in %AppData%\InputDood\config.ini (editable from the window) ----
AppDir   := A_AppData . "\InputDood"
IniFile  := AppDir . "\config.ini"
LogoFile := AppDir . "\logo.png"

; ==================== Settings (defaults; LoadSettings() overrides them from config.ini) ====================
LANG_PREF := "auto"              ; auto | en | es
THEME_PREF := "auto"             ; auto | light | dark
UI_LANG := "en"
CHECK_UPDATES := true

; How long to wait (in seconds) after the "polite" close (WinClose) before force-killing
; the process if the window is still open.
FORCE_KILL_GRACE_SEC := 2

; When true, InputDood never draws windows (Mouse Mode message, on-screen keyboard) over a
; fullscreen window and uses beeps instead, because that makes fullscreen games lose focus.
FULLSCREEN_SAFE_MODE := true

INDICATOR_MODE := "window"       ; window | beep | none  (how "Mouse Mode ON/OFF" is shown)

; Cursor speed (pixels per tick at full stick tilt, timer at POLL_INTERVAL_MOUSE_MS = 16 ms)
CURSOR_MAX_SPEED := 32
; Exponent of the stick's response curve: 1.0 = linear, >1 = finer control near the center,
; <1 = more sensitive near the center.
CURVE_NAME := "linear"           ; linear | precise | sensitive
CURSOR_CURVE_EXPONENT := 1.0
STICK_DEADZONE_PCT := 24
TRIGGER_PCT := 39
LEFT_STICK_DEADZONE := 7849
RIGHT_STICK_DEADZONE := 8689
TRIGGER_THRESHOLD := 100         ; 0-255. RT/LT pass this threshold to count as "pressed".

MEDIA_TRACK_DEADZONE := 20000    ; right stick left/right needs a bigger tilt (avoids accidental track changes)
WHEEL_REPEAT_DELAY_MS := 350       ; holding a scroll button: wait this long, then keep scrolling...
WHEEL_REPEAT_MS := 60            ; ...one step every this many ms
VOLUME_REPEAT_MS := 120          ; repeat rate of "repeat" actions (volume) while held

POLL_INTERVAL_IDLE_MS  := 100
POLL_INTERVAL_MOUSE_MS := 16

; Administrator mode: scheduled tasks that start InputDood elevated / back to normal (see the Admin section)
TASK_ELEV := "InputDood Elevated"
TASK_ELEV_STARTUP := "InputDood Elevated Startup"
TASK_NORMAL := "InputDood Normal"
ADMIN_MODE := false              ; the tasks exist: "Restart as administrator" is available
ADMIN_STARTUP := false           ; InputDood starts elevated with Windows
adminBlocked := false            ; an elevated window just blocked an action (shown on the Status page)

; ==================== XInput button bits ====================
; Bits from XInputGetStateEx (undocumented, ordinal 100). The "virtual" ones (triggers, right stick
; directions) are added by InputDood so they can be used in shortcuts like any other button.
XI_DPAD_UP    := 0x0001
XI_DPAD_DOWN  := 0x0002
XI_DPAD_LEFT  := 0x0004
XI_DPAD_RIGHT := 0x0008
XI_START      := 0x0010
XI_BACK       := 0x0020
XI_L3         := 0x0040  ; left stick click
XI_R3         := 0x0080  ; right stick click
XI_LB         := 0x0100
XI_RB         := 0x0200
XI_GUIDE      := 0x0400  ; only visible via GetStateEx, not in the public API
XI_A          := 0x1000
XI_B          := 0x2000
XI_X          := 0x4000
XI_Y          := 0x8000
XI_LT         := 0x10000     ; virtual: left trigger pulled past the threshold
XI_RT         := 0x20000     ; virtual: right trigger pulled past the threshold
XI_RS_UP      := 0x40000     ; virtual: right stick up / down / left / right
XI_RS_DOWN    := 0x80000
XI_RS_LEFT    := 0x100000
XI_RS_RIGHT   := 0x200000

; [name written in config.ini, bit, label shown in the window]
BTN_TABLE := [
    ["Guide", XI_GUIDE, "Guide"],
    ["LB", XI_LB, "LB"],
    ["RB", XI_RB, "RB"],
    ["LT", XI_LT, "LT"],
    ["RT", XI_RT, "RT"],
    ["Start", XI_START, "Start"],
    ["Back", XI_BACK, "Back"],
    ["L3", XI_L3, "L3"],
    ["R3", XI_R3, "R3"],
    ["A", XI_A, "A"],
    ["B", XI_B, "B"],
    ["X", XI_X, "X"],
    ["Y", XI_Y, "Y"],
    ["DPad_Up", XI_DPAD_UP, "D-pad ↑"],
    ["DPad_Down", XI_DPAD_DOWN, "D-pad ↓"],
    ["DPad_Left", XI_DPAD_LEFT, "D-pad ←"],
    ["DPad_Right", XI_DPAD_RIGHT, "D-pad →"],
    ["RS_Up", XI_RS_UP, "R-stick ↑"],
    ["RS_Down", XI_RS_DOWN, "R-stick ↓"],
    ["RS_Left", XI_RS_LEFT, "R-stick ←"],
    ["RS_Right", XI_RS_RIGHT, "R-stick →"]
]

; Every action a shortcut can run. The order here is the order of the action list in the editor.
; "custom_tap" sends the text you type (AutoHotkey Send syntax, e.g. {F11} or ^c);
; "custom_hold" holds the key you type while the buttons are held (e.g. Space).
ACTION_IDS := ["close_window", "toggle_mouse", "toggle_osk",
    "left_click", "right_click", "middle_click", "wheel_up", "wheel_down",
    "key_enter", "key_escape", "key_space", "key_backspace", "key_tab",
    "key_up", "key_down", "key_left", "key_right",
    "alt_tab", "win_key", "play_pause", "media_next", "media_prev",
    "volume_up", "volume_down", "volume_mute",
    "custom_tap", "custom_hold"]

; Shortcuts that are on by default (these reproduce what InputDood always did):
; "<scope>|<buttons joined with +>|<action>"   scope: always = any time, mouse = only in Mouse Mode
DEFAULT_BINDING_LINES := [
    "always|Guide+Start|close_window",
    "always|Guide+Back|toggle_mouse",
    "mouse|RT|left_click",
    "mouse|LT|right_click",
    "mouse|X|middle_click",
    "mouse|A|key_enter",
    "mouse|B|key_escape",
    "mouse|DPad_Up|key_up",
    "mouse|DPad_Down|key_down",
    "mouse|DPad_Left|key_left",
    "mouse|DPad_Right|key_right",
    "mouse|LB|wheel_up",
    "mouse|RB|wheel_down",
    "mouse|L3|alt_tab",
    "mouse|R3|play_pause",
    "mouse|Start|win_key",
    "mouse|Back|key_tab",
    "mouse|Y|toggle_osk",
    "mouse|RS_Up|volume_up",
    "mouse|RS_Down|volume_down",
    "mouse|RS_Right|media_next",
    "mouse|RS_Left|media_prev"
]

; ==================== Runtime state ====================
Bindings := []                   ; list of Map(scope, mask, act, param, kind, on, last, sup)
mouseModeActive := false
modeEpoch := 0                   ; changes every time Mouse Mode is toggled (aborts the current evaluation)
captureActive := false           ; true while the editor waits for a button combination
captureDone := ""
captureLive := ""
capturePeak := 0
lastMaskAll := 0                 ; buttons held right now (all controllers), shown in the Status page
shownMask := ""                  ; signature of what is drawn on the Status page (buttons + sticks)
padLX := 0, padLY := 0, padRX := 0, padRY := 0, padLT := 0, padRT := 0   ; analog values of the first controller
ctrlCount := 0
prevCtrlCount := -1

pGetStateEx := 0
lastScan := 0
ScanIntervalMs := 3000
bufs := [Buffer(16, 0), Buffer(16, 0), Buffer(16, 0), Buffer(16, 0)]
connected := [false, false, false, false]
rsHoriz := [0, 0, 0, 0]          ; right stick left/right state per controller (with hysteresis)


; ==================== Localization ====================
; Defaults to English, and switches to Spanish when Windows' UI language is Spanish (any regional
; variant: all share the same primary language ID). It can be forced from Options (config.ini: language=en|es).
; GetUserDefaultUILanguage() asks Windows for the language it really displays its own menus in;
; A_Language isn't reliable here. The low byte of a LANGID is the primary language ID (0x0A = Spanish).
IsWindowsSpanishUI() {
    langId := DllCall("kernel32\GetUserDefaultUILanguage", "UShort")
    return (langId & 0xFF) = 0x0A
}

STRINGS := Map(
    "en", Map(
        "tray_open", "Open InputDood",
        "tray_mouse", "Mouse mode",
        "tray_about", "About",
        "tray_check_updates", "Check for updates",
        "tray_donations", "Donations",
        "tray_run_startup", "Run at startup",
        "tray_exit", "Exit",

        "tab_status", "Status",
        "tab_keys", "Shortcuts",
        "tab_mouse", "Mouse mode",
        "tab_options", "Options",
        "tab_about", "About",

        "st_ready", "Ready",
        "st_ready_sub", "{1} controller(s) connected.`nGuide + Start closes the active window; Guide + Back toggles Mouse Mode (you can change both in Shortcuts).",
        "st_nopad", "No controller detected",
        "st_nopad_sub", "Connect an Xbox-compatible (XInput) controller.`nInputDood looks for it every few seconds.",
        "st_mouse_on", "Mouse Mode is ON",
        "st_mouse_on_sub", "The left stick moves the cursor and the buttons act as set in Shortcuts.`nToggle it again with your shortcut or the button on the right.",
        "btn_mouse_on", "Turn Mouse Mode ON",
        "btn_mouse_off", "Turn Mouse Mode OFF",
        "btn_edit_keys", "Edit shortcuts",
        "st_quick", "Main shortcuts",
        "st_live_title", "Controller test",
        "st_live_hint", "Press buttons on your controller: they show up here.",
        "st_live_none", "—",
        "side_pads_none", "No controller",
        "side_pads_one", "1 controller",
        "side_pads_many", "{1} controllers",

        "k_intro", "Each shortcut is a button (or a combination) that runs an action. «Always» works any time; «Mouse Mode» only works while Mouse Mode is ON. Double-click a row to edit it.",
        "k_add", "Add",
        "k_edit", "Edit",
        "k_remove", "Remove",
        "k_reset", "Restore defaults",
        "k_col_when", "Works",
        "k_col_input", "Controller input",
        "k_col_action", "Action",
        "k_nosel", "Select a shortcut in the list first.",
        "k_reset_confirm", "Restore the default shortcuts? Your changes to the list will be lost.",
        "scope_always", "Always",
        "scope_mouse", "Mouse Mode only",
        "scope_mouse_short", "Mouse Mode",

        "ed_title_add", "Add shortcut",
        "ed_title_edit", "Edit shortcut",
        "ed_input", "Controller input",
        "ed_capture", "Press on controller",
        "ed_capturing", "Listening…",
        "ed_press", "Press the buttons now…",
        "ed_hint", "Hold the buttons together and release them. You can also type them, joined by +  (example: Guide+Start, LB+A, RT).",
        "ed_when", "When does it work?",
        "ed_action", "Action",
        "ed_param", "Key or text to send",
        "ed_param_hint", "Examples: {F11}   ^c   !{Tab}   Space",
        "ed_ok", "Save",
        "ed_cancel", "Cancel",
        "ed_bad_combo", "That input isn't valid. Use the names: Guide, Start, Back, A, B, X, Y, LB, RB, LT, RT, L3, R3, DPad_Up, DPad_Down, DPad_Left, DPad_Right, RS_Up, RS_Down, RS_Left, RS_Right (joined by +).",
        "ed_pick_action", "Choose an action from the list.",
        "ed_need_param", "This action needs a key or text to send.",
        "ed_dup", "There is already a shortcut with that input for the same mode. Replace it?",

        "act_close_window", "Close the active window",
        "act_toggle_mouse", "Turn Mouse Mode on/off",
        "act_toggle_osk", "Show/hide the on-screen keyboard",
        "act_left_click", "Left click (hold)",
        "act_right_click", "Right click (hold)",
        "act_middle_click", "Middle click (hold)",
        "act_wheel_up", "Scroll up",
        "act_wheel_down", "Scroll down",
        "act_key_enter", "Enter (hold)",
        "act_key_escape", "Escape (hold)",
        "act_key_space", "Space (hold)",
        "act_key_backspace", "Backspace (hold)",
        "act_key_tab", "Tab",
        "act_key_up", "Arrow up (hold)",
        "act_key_down", "Arrow down (hold)",
        "act_key_left", "Arrow left (hold)",
        "act_key_right", "Arrow right (hold)",
        "act_alt_tab", "Alt+Tab",
        "act_win_key", "Windows key",
        "act_play_pause", "Play / Pause",
        "act_media_next", "Next track",
        "act_media_prev", "Previous track",
        "act_volume_up", "Volume up (repeats)",
        "act_volume_down", "Volume down (repeats)",
        "act_volume_mute", "Mute",
        "act_custom_tap", "Send a key or text",
        "act_custom_hold", "Hold a key",

        "m_intro", "How the cursor behaves in Mouse Mode. The left stick always moves the cursor; the buttons are set in Shortcuts.",
        "m_speed", "Cursor speed (1 - 100)",
        "m_curve", "Stick response",
        "curve_linear", "Linear",
        "curve_precise", "Precise",
        "curve_sensitive", "Sensitive",
        "m_dead", "Stick dead zone % (5 - 40)",
        "m_trigger", "Trigger sensitivity % (10 - 90)",
        "m_scroll_delay", "Scroll: wait before repeating, ms (50 - 2000)",
        "m_scroll_rate", "Scroll: time between repeats while held, ms (10 - 500)",
        "m_indicator", "«Mouse Mode ON/OFF» notice",
        "ind_window", "Message",
        "ind_beep", "Beeps",
        "ind_none", "None",
        "m_fsafe", "Don't draw windows over fullscreen games (beeps instead). Recommended.",
        "m_save", "Save",
        "m_defaults", "Defaults",
        "m_invalid", "Check the values: speed 1-100, dead zone 5-40, trigger sensitivity 10-90, scroll delay 50-2000, scroll repeat 10-500.",
        "saved", "✓ Saved",

        "o_language", "Language",
        "o_theme", "Theme",
        "seg_auto", "Auto",
        "th_light", "Light",
        "th_dark", "Dark",
        "o_grace", "Seconds to wait before force-closing (0 - 30)",
        "o_startup", "Run at startup",
        "o_checkupd", "Check for updates at startup",
        "o_admin", "Allow controlling administrator windows (e.g. Task Manager)",
        "o_admin_startup", "Start InputDood as administrator with Windows",
        "o_admin_note", "Needs an administrator confirmation once. Don't use administrator mode with games protected by anti-cheat: go back to normal mode from the tray menu before playing.",
        "o_admin_failed", "Couldn't apply the administrator settings (was the confirmation cancelled?).",
        "tray_admin_on", "Restart as administrator",
        "tray_admin_off", "Back to normal mode",
        "adm_setup_ask", "To control administrator windows, InputDood needs to create a task that runs it with elevated permissions. Windows will ask for confirmation once. Continue?",
        "adm_launch_failed", "InputDood couldn't restart as administrator.",
        "adm_startup_tray", "Startup is set to administrator mode. Change it in Options.",
        "admin_tag", "Administrator",
        "st_admin_block", "A window with administrator permissions blocked the action",
        "st_admin_block_sub", "InputDood is in normal mode, so it can't control that window. Restart it as administrator and try again. Then go back to normal mode before playing.",
        "btn_restart_admin", "Restart as administrator",
        "o_save", "Save",
        "o_open_ini", "Open config.ini",
        "o_open_folder", "Open folder",
        "o_invalid", "Check the values: seconds must be between 0 and 30.",

        "ab_version", "Version {1}",
        "ab_desc", "Close any game or program with Guide + Start, and use your controller as a mouse and keyboard from the couch. No installation and no extra programs needed.",
        "ab_made", "Made by {1} with Claude AI. 🤖✨",
        "ab_patreon", "Support me on Patreon ☕",
        "ab_github", "Project on GitHub",
        "ab_libs", "Built with AutoHotkey v2 (included in the .exe).",
        "ab_check", "Check for updates",

        "update_check_failed", "Couldn't reach GitHub right now (code {v}). Try again later.",
        "update_up_to_date", "You already have the latest version ({v}).",
        "update_available_title", "InputDood - Update available",
        "update_available_body", "A new version is available: {v}`nYou have installed: {v2}",
        "update_open_page_question", "`n`nOpen the downloads page?",
        "update_self_question", "`n`nUpdate now? InputDood will close for a moment,`ndownload the new version, and reopen on its own.",
        "update_download_failed", "Couldn't download the update (code {v}).",
        "update_install_failed", "Couldn't install the update: {v}",
        "update_check_error", "Couldn't check for updates: {v}",
        "update_done_title", "Update complete",
        "update_done_body", "InputDood was updated to version {v}.",

        "firstrun_title", "Before you continue",
        "firstrun_body", "InputDood doesn't need any external program to work: "
            . "it closes the active window and, if it doesn't close within a few seconds, "
            . "force-kills the process automatically.`n`n"
            . "It also includes a mouse mode that lets you control the cursor and keyboard with the controller. "
            . "All the shortcuts can be changed in the Shortcuts page.",
        "firstrun_uncompiled_note", "`n`nSince you're running the .ahk uncompiled, you need AutoHotkey v2 installed.",
        "firstrun_compiled_note", "`n`n(AutoHotkey is already bundled into this .exe, no need to install it separately.)",

        "osk_drag_hint", "  ⠿  InputDood Keyboard   ·   drag here to move",
        "osk_space", "Space",
    ),
    "es", Map(
        "tray_open", "Abrir InputDood",
        "tray_mouse", "Modo mouse",
        "tray_about", "Acerca de",
        "tray_check_updates", "Buscar actualizaciones",
        "tray_donations", "Donaciones",
        "tray_run_startup", "Ejecutar al iniciar",
        "tray_exit", "Salir",

        "tab_status", "Estado",
        "tab_keys", "Atajos",
        "tab_mouse", "Modo mouse",
        "tab_options", "Opciones",
        "tab_about", "Acerca de",

        "st_ready", "Listo",
        "st_ready_sub", "{1} control(es) conectado(s).`nGuide + Start cierra la ventana activa; Guide + Back activa/desactiva el Modo mouse (puedes cambiar ambos en Atajos).",
        "st_nopad", "No se detecta ningún control",
        "st_nopad_sub", "Conecta un control compatible con Xbox (XInput).`nInputDood lo busca cada pocos segundos.",
        "st_mouse_on", "El Modo mouse está ACTIVADO",
        "st_mouse_on_sub", "El stick izquierdo mueve el cursor y los botones hacen lo que definiste en Atajos.`nVuelve a desactivarlo con tu atajo o con el botón de la derecha.",
        "btn_mouse_on", "Activar Modo mouse",
        "btn_mouse_off", "Desactivar Modo mouse",
        "btn_edit_keys", "Editar atajos",
        "st_quick", "Atajos principales",
        "st_live_title", "Prueba del control",
        "st_live_hint", "Presiona botones del control: aquí aparecen.",
        "st_live_none", "—",
        "side_pads_none", "Sin control",
        "side_pads_one", "1 control",
        "side_pads_many", "{1} controles",

        "k_intro", "Cada atajo es un botón (o una combinación) que ejecuta una acción. «Siempre» funciona en cualquier momento; «Solo Modo mouse» únicamente mientras el Modo mouse está activado. Haz doble clic en una fila para editarla.",
        "k_add", "Agregar",
        "k_edit", "Editar",
        "k_remove", "Quitar",
        "k_reset", "Restaurar originales",
        "k_col_when", "Funciona",
        "k_col_input", "Botones del control",
        "k_col_action", "Acción",
        "k_nosel", "Primero selecciona un atajo de la lista.",
        "k_reset_confirm", "¿Restaurar los atajos originales? Se perderán tus cambios en la lista.",
        "scope_always", "Siempre",
        "scope_mouse", "Solo Modo mouse",
        "scope_mouse_short", "Modo mouse",

        "ed_title_add", "Agregar atajo",
        "ed_title_edit", "Editar atajo",
        "ed_input", "Botones del control",
        "ed_capture", "Presionar en el control",
        "ed_capturing", "Escuchando…",
        "ed_press", "Presiona los botones ahora…",
        "ed_hint", "Mantén los botones juntos y suéltalos. También puedes escribirlos unidos con +  (ejemplo: Guide+Start, LB+A, RT).",
        "ed_when", "¿Cuándo funciona?",
        "ed_action", "Acción",
        "ed_param", "Tecla o texto que se envía",
        "ed_param_hint", "Ejemplos: {F11}   ^c   !{Tab}   Space",
        "ed_ok", "Guardar",
        "ed_cancel", "Cancelar",
        "ed_bad_combo", "Esa combinación no es válida. Usa estos nombres: Guide, Start, Back, A, B, X, Y, LB, RB, LT, RT, L3, R3, DPad_Up, DPad_Down, DPad_Left, DPad_Right, RS_Up, RS_Down, RS_Left, RS_Right (unidos con +).",
        "ed_pick_action", "Elige una acción de la lista.",
        "ed_need_param", "Esta acción necesita una tecla o un texto que enviar.",
        "ed_dup", "Ya existe un atajo con esos botones para el mismo modo. ¿Reemplazarlo?",

        "act_close_window", "Cerrar la ventana activa",
        "act_toggle_mouse", "Activar/desactivar el Modo mouse",
        "act_toggle_osk", "Mostrar/ocultar el teclado en pantalla",
        "act_left_click", "Clic izquierdo (mantenido)",
        "act_right_click", "Clic derecho (mantenido)",
        "act_middle_click", "Clic central (mantenido)",
        "act_wheel_up", "Scroll arriba",
        "act_wheel_down", "Scroll abajo",
        "act_key_enter", "Enter (mantenido)",
        "act_key_escape", "Escape (mantenido)",
        "act_key_space", "Espacio (mantenido)",
        "act_key_backspace", "Retroceso (mantenido)",
        "act_key_tab", "Tab",
        "act_key_up", "Flecha arriba (mantenido)",
        "act_key_down", "Flecha abajo (mantenido)",
        "act_key_left", "Flecha izquierda (mantenido)",
        "act_key_right", "Flecha derecha (mantenido)",
        "act_alt_tab", "Alt+Tab",
        "act_win_key", "Tecla Windows",
        "act_play_pause", "Play / Pausa",
        "act_media_next", "Pista siguiente",
        "act_media_prev", "Pista anterior",
        "act_volume_up", "Subir volumen (se repite)",
        "act_volume_down", "Bajar volumen (se repite)",
        "act_volume_mute", "Silenciar",
        "act_custom_tap", "Enviar una tecla o texto",
        "act_custom_hold", "Mantener una tecla",

        "m_intro", "Cómo se comporta el cursor en el Modo mouse. El stick izquierdo siempre mueve el cursor; los botones se definen en Atajos.",
        "m_speed", "Velocidad del cursor (1 - 100)",
        "m_curve", "Respuesta del stick",
        "curve_linear", "Lineal",
        "curve_precise", "Preciso",
        "curve_sensitive", "Sensible",
        "m_dead", "Zona muerta del stick % (5 - 40)",
        "m_trigger", "Sensibilidad de los gatillos % (10 - 90)",
        "m_scroll_delay", "Scroll: espera antes de repetir, ms (50 - 2000)",
        "m_scroll_rate", "Scroll: tiempo entre repeticiones al mantener, ms (10 - 500)",
        "m_indicator", "Aviso «Modo mouse ON/OFF»",
        "ind_window", "Mensaje",
        "ind_beep", "Pitidos",
        "ind_none", "Ninguno",
        "m_fsafe", "No dibujar ventanas sobre juegos en pantalla completa (usa pitidos). Recomendado.",
        "m_save", "Guardar",
        "m_defaults", "Valores originales",
        "m_invalid", "Revisa los valores: velocidad 1-100, zona muerta 5-40, sensibilidad de gatillos 10-90, espera del scroll 50-2000, repetición del scroll 10-500.",
        "saved", "✓ Guardado",

        "o_language", "Idioma",
        "o_theme", "Tema",
        "seg_auto", "Auto",
        "th_light", "Claro",
        "th_dark", "Oscuro",
        "o_grace", "Segundos de espera antes de forzar el cierre (0 - 30)",
        "o_startup", "Ejecutar al iniciar Windows",
        "o_checkupd", "Buscar actualizaciones al iniciar",
        "o_admin", "Permitir controlar ventanas de administrador (por ejemplo, el Administrador de tareas)",
        "o_admin_startup", "Iniciar InputDood como administrador con Windows",
        "o_admin_note", "Pide una confirmación de administrador una sola vez. No uses el modo administrador con juegos protegidos por anti-cheat: vuelve al modo normal desde el menú de la bandeja antes de jugar.",
        "o_admin_failed", "No se pudieron aplicar los ajustes de administrador (¿se canceló la confirmación?).",
        "tray_admin_on", "Reiniciar como administrador",
        "tray_admin_off", "Volver al modo normal",
        "adm_setup_ask", "Para controlar ventanas de administrador, InputDood necesita crear una tarea que lo ejecute con permisos elevados. Windows pedirá confirmación una sola vez. ¿Continuar?",
        "adm_launch_failed", "InputDood no pudo reiniciarse como administrador.",
        "adm_startup_tray", "El inicio está configurado en modo administrador. Cámbialo en Opciones.",
        "admin_tag", "Administrador",
        "st_admin_block", "Una ventana de administrador bloqueó la acción",
        "st_admin_block_sub", "InputDood está en modo normal, así que no puede controlar esa ventana. Reinícialo como administrador y vuelve a intentarlo. Luego vuelve al modo normal antes de jugar.",
        "btn_restart_admin", "Reiniciar como administrador",
        "o_save", "Guardar",
        "o_open_ini", "Abrir config.ini",
        "o_open_folder", "Abrir carpeta",
        "o_invalid", "Revisa los valores: los segundos deben estar entre 0 y 30.",

        "ab_version", "Versión {1}",
        "ab_desc", "Cierra cualquier juego o programa con Guide + Start y usa tu control como mouse y teclado desde el sillón. No necesita instalación ni programas extra.",
        "ab_made", "Hecho por {1} con Claude AI. 🤖✨",
        "ab_patreon", "Apóyame en Patreon ☕",
        "ab_github", "Proyecto en GitHub",
        "ab_libs", "Hecho con AutoHotkey v2 (incluido en el .exe).",
        "ab_check", "Buscar actualizaciones",

        "update_check_failed", "No se pudo consultar GitHub ahorita (código {v}). Intenta más tarde.",
        "update_up_to_date", "Ya tienes la última versión ({v}).",
        "update_available_title", "InputDood - Actualización disponible",
        "update_available_body", "Hay una nueva versión disponible: {v}`nTienes instalada: {v2}",
        "update_open_page_question", "`n`n¿Abrir la página de descargas?",
        "update_self_question", "`n`n¿Actualizar ahora? InputDood se va a cerrar un momento,`ndescargar la nueva versión y volver a abrirse solo.",
        "update_download_failed", "No se pudo descargar la actualización (código {v}).",
        "update_install_failed", "No se pudo instalar la actualización: {v}",
        "update_check_error", "No se pudo revisar actualizaciones: {v}",
        "update_done_title", "Actualización completada",
        "update_done_body", "InputDood se actualizó a la versión {v}.",

        "firstrun_title", "Antes de continuar",
        "firstrun_body", "InputDood no necesita ningún programa externo para funcionar: "
            . "cierra la ventana activa y, si no cierra en unos segundos, "
            . "mata el proceso a la fuerza automáticamente.`n`n"
            . "También incluye un modo mouse que te deja controlar el cursor y el teclado con el control. "
            . "Todos los atajos se pueden cambiar en la página Atajos.",
        "firstrun_uncompiled_note", "`n`nComo estás corriendo el .ahk sin compilar, necesitas AutoHotkey v2 instalado.",
        "firstrun_compiled_note", "`n`n(AutoHotkey ya viene incluido en este .exe, no necesitas instalarlo aparte.)",

        "osk_drag_hint", "  ⠿  Teclado InputDood   ·   arrástralo desde aquí para moverlo",
        "osk_space", "Espacio",
    ),
)

; Looks up STRINGS[UI_LANG][key], falling back to English if a key is missing from a non-English table.
Tr(key) {
    global STRINGS, UI_LANG
    if STRINGS[UI_LANG].Has(key)
        return STRINGS[UI_LANG][key]
    if STRINGS["en"].Has(key)
        return STRINGS["en"][key]
    return key
}

; {v} / {v2} placeholders (used by the update messages).
TrFmt(key, v := "", v2 := "") {
    s := Tr(key)
    s := StrReplace(s, "{v}", v)
    s := StrReplace(s, "{v2}", v2)
    return s
}

; T("key", args...) -> text with {1}, {2}... filled in. Without args the text is returned as is.
T(key, args*) {
    txt := Tr(key)
    return args.Length ? Format(txt, args*) : txt
}


; ============================================================================
;  Settings (config.ini)
; ============================================================================
ClampNum(v, lo, hi, def) {
    if !IsNumber(v)
        return def
    v := v + 0
    if (v < lo)
        return lo
    if (v > hi)
        return hi
    return v
}

LoadSettings() {
    global LANG_PREF, THEME_PREF, UI_LANG, CHECK_UPDATES, FULLSCREEN_SAFE_MODE, FORCE_KILL_GRACE_SEC
    global INDICATOR_MODE, CURSOR_MAX_SPEED, CURVE_NAME, CURSOR_CURVE_EXPONENT, STICK_DEADZONE_PCT, TRIGGER_PCT
    global LEFT_STICK_DEADZONE, RIGHT_STICK_DEADZONE, TRIGGER_THRESHOLD, ADMIN_MODE, ADMIN_STARTUP
    global WHEEL_REPEAT_DELAY_MS, WHEEL_REPEAT_MS

    LANG_PREF := StrLower(Trim(IniRead(IniFile, "general", "language", "auto")))
    if !(LANG_PREF = "en" || LANG_PREF = "es")
        LANG_PREF := "auto"
    THEME_PREF := StrLower(Trim(IniRead(IniFile, "general", "theme", "auto")))
    if !(THEME_PREF = "light" || THEME_PREF = "dark")
        THEME_PREF := "auto"
    if (LANG_PREF = "auto")
        UI_LANG := IsWindowsSpanishUI() ? "es" : "en"
    else
        UI_LANG := LANG_PREF

    CHECK_UPDATES := (IniRead(IniFile, "general", "checkUpdates", "1") = "1")
    ADMIN_MODE := (IniRead(IniFile, "general", "adminMode", "0") = "1")
    ADMIN_STARTUP := ADMIN_MODE && (IniRead(IniFile, "general", "adminStartup", "0") = "1")
    FULLSCREEN_SAFE_MODE := (IniRead(IniFile, "general", "fullscreenSafe", "1") = "1")
    FORCE_KILL_GRACE_SEC := Integer(ClampNum(IniRead(IniFile, "general", "forceKillGraceSec", "2"), 0, 30, 2))

    INDICATOR_MODE := StrLower(Trim(IniRead(IniFile, "mouse", "indicator", "window")))
    if !(INDICATOR_MODE = "beep" || INDICATOR_MODE = "none")
        INDICATOR_MODE := "window"
    CURSOR_MAX_SPEED := Integer(ClampNum(IniRead(IniFile, "mouse", "cursorSpeed", "32"), 1, 100, 32))
    CURVE_NAME := StrLower(Trim(IniRead(IniFile, "mouse", "curve", "linear")))
    if (CURVE_NAME = "precise")
        CURSOR_CURVE_EXPONENT := 1.6
    else if (CURVE_NAME = "sensitive")
        CURSOR_CURVE_EXPONENT := 0.7
    else {
        CURVE_NAME := "linear"
        CURSOR_CURVE_EXPONENT := 1.0
    }
    WHEEL_REPEAT_DELAY_MS := Integer(ClampNum(IniRead(IniFile, "mouse", "scrollDelayMs", "350"), 50, 2000, 350))
    WHEEL_REPEAT_MS := Integer(ClampNum(IniRead(IniFile, "mouse", "scrollRateMs", "60"), 10, 500, 60))
    STICK_DEADZONE_PCT := Integer(ClampNum(IniRead(IniFile, "mouse", "deadzonePct", "24"), 5, 40, 24))
    TRIGGER_PCT := Integer(ClampNum(IniRead(IniFile, "mouse", "triggerPct", "39"), 10, 90, 39))
    LEFT_STICK_DEADZONE := Round(STICK_DEADZONE_PCT * 327.67)
    RIGHT_STICK_DEADZONE := Round(LEFT_STICK_DEADZONE * 8689 / 7849)
    TRIGGER_THRESHOLD := Round(TRIGGER_PCT * 2.55)
}

; ============================================================================
;  Shortcuts (bindings)
; ============================================================================
; Converts "Guide+Start" into a bit mask. Returns 0 if any name is unknown or the text is empty.
TextToMask(txt) {
    mask := 0
    for part in StrSplit(txt, "+") {
        key := StrLower(Trim(part))
        if (key = "")
            continue
        found := false
        for row in BTN_TABLE {
            if (StrLower(row[1]) = key) {
                mask |= row[2]
                found := true
                break
            }
        }
        if !found
            return 0
    }
    return mask
}

; Bit mask -> "Guide+Start" (the names written in config.ini)
MaskToIni(mask) {
    out := ""
    for row in BTN_TABLE {
        if ((mask & row[2]) != 0)
            out .= (out = "" ? "" : "+") . row[1]
    }
    return out
}

; Bit mask -> "Guide + Start" (what the window shows)
MaskToLabel(mask) {
    out := ""
    for row in BTN_TABLE {
        if ((mask & row[2]) != 0)
            out .= (out = "" ? "" : " + ") . row[3]
    }
    return out
}

ActionKnown(id) {
    for a in ACTION_IDS {
        if (a = id)
            return true
    }
    return false
}

; "hold" = pressed while the buttons are held, "repeat" = fires again and again while held,
; "tap" = runs once when the buttons go down.
ActionKind(id) {
    holdList := "|left_click|right_click|middle_click|key_enter|key_escape|key_space|key_backspace|key_up|key_down|key_left|key_right|custom_hold|"
    if InStr(holdList, "|" . id . "|")
        return "hold"
    if (id = "volume_up" || id = "volume_down" || id = "wheel_up" || id = "wheel_down")
        return "repeat"
    return "tap"
}

; actStr is "id" or "id:parameter" (custom actions)
MakeBinding(scope, mask, actStr) {
    id := actStr
    param := ""
    p := InStr(actStr, ":")
    if (p > 0) {
        id := SubStr(actStr, 1, p - 1)
        param := SubStr(actStr, p + 1)
    }
    if !ActionKnown(id)
        return ""
    if ((id = "custom_tap" || id = "custom_hold") && param = "")
        return ""
    if !(id = "custom_tap" || id = "custom_hold")
        param := ""
    return Map("scope", scope, "mask", mask, "act", id, "param", param
        , "kind", ActionKind(id), "on", false, "last", 0, "n", 0, "sup", [])
}

ParseBinding(line) {
    parts := StrSplit(line, "|", "", 3)
    if (parts.Length < 3)
        return ""
    scope := StrLower(Trim(parts[1]))
    if !(scope = "always" || scope = "mouse")
        return ""
    mask := TextToMask(parts[2])
    if (mask = 0)
        return ""
    return MakeBinding(scope, mask, Trim(parts[3]))
}

ActString(b) {
    return (b["param"] != "") ? b["act"] . ":" . b["param"] : b["act"]
}

BindingToLine(b) {
    return b["scope"] . "|" . MaskToIni(b["mask"]) . "|" . ActString(b)
}

; For each shortcut, remembers which other shortcuts use a bigger combination that contains it.
; While the bigger one is held, the smaller one is ignored (so Guide+Start doesn't also press Start alone).
IndexBindings(list) {
    n := list.Length
    Loop n {
        i := A_Index
        mi := list[i]["mask"]
        sup := []
        Loop n {
            j := A_Index
            if (j = i)
                continue
            mj := list[j]["mask"]
            if (mj != mi && (mj & mi) = mi)
                sup.Push(j)
        }
        list[i]["sup"] := sup
    }
}

DefaultBindings() {
    list := []
    for line in DEFAULT_BINDING_LINES {
        b := ParseBinding(line)
        if IsObject(b)
            list.Push(b)
    }
    IndexBindings(list)
    return list
}

LoadBindings() {
    global Bindings
    cnt := IniRead(IniFile, "bindings", "count", "")
    if !IsInteger(cnt) {
        Bindings := DefaultBindings()
        return
    }
    list := []
    Loop Integer(cnt) {
        b := ParseBinding(IniRead(IniFile, "bindings", "b" . A_Index, ""))
        if IsObject(b)
            list.Push(b)
    }
    IndexBindings(list)
    Bindings := list
}

SaveBindings(list) {
    try IniDelete(IniFile, "bindings")
    IniWrite(list.Length, IniFile, "bindings", "count")
    for i, b in list
        IniWrite(BindingToLine(b), IniFile, "bindings", "b" . i)
}

; Replaces the active shortcuts (and saves them). Anything still held down is released first.
CommitBindings(list) {
    global Bindings
    ReleaseAllHeld()
    fresh := []
    for b in list
        fresh.Push(MakeBinding(b["scope"], b["mask"], ActString(b)))   ; new Map objects: the timer never sees a half-built list
    IndexBindings(fresh)
    Bindings := fresh
    SaveBindings(fresh)
}

; First shortcut that runs this action ("" if none)
BindingFor(id) {
    for b in Bindings {
        if (b["act"] = id)
            return b
    }
    return ""
}

ActionLabel(b) {
    txt := Tr("act_" . b["act"])
    if (b["param"] != "")
        txt .= "  " . b["param"]
    return txt
}

; ============================================================================
;  Polling: reads the controllers and runs the shortcuts
; ============================================================================
; Buttons held on one controller (real bits + the virtual trigger / right-stick ones)
MaskFromBuf(buf, idx) {
    global rsHoriz
    m := NumGet(buf, 4, "UShort")
    if (NumGet(buf, 6, "UChar") >= TRIGGER_THRESHOLD)
        m |= XI_LT
    if (NumGet(buf, 7, "UChar") >= TRIGGER_THRESHOLD)
        m |= XI_RT
    rx := NumGet(buf, 12, "Short")
    ry := NumGet(buf, 14, "Short")
    if (ry >= RIGHT_STICK_DEADZONE)
        m |= XI_RS_UP
    else if (ry <= -RIGHT_STICK_DEADZONE)
        m |= XI_RS_DOWN
    ; left / right needs a bigger tilt to turn on, and returns to the dead zone to turn off
    st := rsHoriz[idx]
    if (Abs(rx) < RIGHT_STICK_DEADZONE)
        st := 0
    else if (st = 0 && Abs(rx) >= MEDIA_TRACK_DEADZONE)
        st := (rx > 0) ? 1 : -1
    rsHoriz[idx] := st
    if (st = 1)
        m |= XI_RS_RIGHT
    else if (st = -1)
        m |= XI_RS_LEFT
    return m
}

ApplyPollInterval() {
    SetTimer(CheckCombo, mouseModeActive ? POLL_INTERVAL_MOUSE_MS : POLL_INTERVAL_IDLE_MS)
}

CheckCombo() {
    global bufs, connected, lastScan, lastMaskAll, ctrlCount, prevCtrlCount, shownMask
    global padLX, padLY, padRX, padRY, padLT, padRT

    maskAll := 0
    maskPrimary := 0
    primaryIndex := 0

    doFullScan := (A_TickCount - lastScan) >= ScanIntervalMs
    if doFullScan
        lastScan := A_TickCount

    Loop 4 {
        i := A_Index
        if (!connected[i] && !doFullScan)
            continue
        result := DllCall(pGetStateEx, "UInt", i - 1, "Ptr", bufs[i], "UInt")
        connected[i] := (result = 0)
        if connected[i] {
            m := MaskFromBuf(bufs[i], i)
            maskAll |= m
            if (primaryIndex = 0) {
                primaryIndex := i
                maskPrimary := m
            }
        }
    }

    n := 0
    for c in connected {
        if c
            n += 1
    }
    ctrlCount := n
    lastMaskAll := maskAll
    if (n != prevCtrlCount) {
        prevCtrlCount := n
        UpdateState()
    }
    ; analog values (first controller) for the controller test; redraw only when something visibly changed
    nlx := 0, nly := 0, nrx := 0, nry := 0, nlt := 0, nrt := 0
    if (primaryIndex > 0) {
        nlx := NumGet(bufs[primaryIndex], 8, "Short")
        nly := NumGet(bufs[primaryIndex], 10, "Short")
        nrx := NumGet(bufs[primaryIndex], 12, "Short")
        nry := NumGet(bufs[primaryIndex], 14, "Short")
        nlt := NumGet(bufs[primaryIndex], 6, "UChar")
        nrt := NumGet(bufs[primaryIndex], 7, "UChar")
    }
    padLX := nlx, padLY := nly, padRX := nrx, padRY := nry, padLT := nlt, padRT := nrt
    sig := maskAll . "|" . (nlx >> 11) . "|" . (nly >> 11) . "|" . (nrx >> 11) . "|" . (nry >> 11) . "|" . (nlt >> 4) . "|" . (nrt >> 4)
    if (sig != shownMask) {
        shownMask := sig
        UpdateLive(maskAll)
    }

    ; the shortcut editor is waiting for a combination: nothing else should react meanwhile
    if captureActive {
        CaptureTick(maskAll)
        return
    }

    EvalBindings(maskAll, maskPrimary)

    ; --- Mouse mode: the left stick moves the cursor (first detected controller only) ---
    if (mouseModeActive && primaryIndex > 0)
        MoveCursor(bufs[primaryIndex])
}

; Decides which shortcuts are active right now and runs the ones that just changed.
EvalBindings(maskAll, maskPrimary) {
    global modeEpoch
    list := Bindings
    epoch := modeEpoch
    n := list.Length
    if (n = 0)
        return

    elig := []
    Loop n {
        b := list[A_Index]
        ok := false
        bm := b["mask"]
        if (b["scope"] = "always")
            ok := (maskAll & bm) = bm
        else if mouseModeActive
            ok := (maskPrimary & bm) = bm
        elig.Push(ok)
    }

    Loop n {
        i := A_Index
        b := list[i]
        active := elig[i]
        if active {
            for j in b["sup"] {
                if elig[j] {
                    active := false
                    break
                }
            }
        }
        if (active && !b["on"]) {
            b["on"] := true
            b["last"] := A_TickCount
            b["n"] := 0
            if (b["kind"] = "hold")
                DoHold(b, true)
            else
                DoTap(b)
            if (modeEpoch != epoch)
                return          ; Mouse Mode was toggled: re-evaluate everything on the next tick
        } else if (!active && b["on"]) {
            b["on"] := false
            if (b["kind"] = "hold")
                DoHold(b, false)
        } else if (active && b["kind"] = "repeat" && (A_TickCount - b["last"]) >= RepeatInterval(b)) {
            b["last"] := A_TickCount
            b["n"] += 1
            DoTap(b)
        }
    }
}

; Time to wait before the next repeat of a "repeat" action while its buttons stay held
RepeatInterval(b) {
    if (b["act"] = "wheel_up" || b["act"] = "wheel_down")
        return (b["n"] = 0) ? WHEEL_REPEAT_DELAY_MS : WHEEL_REPEAT_MS
    return VOLUME_REPEAT_MS
}

; Releases whatever is held down by shortcuts (all of them, or only those of one scope)
ReleaseAllHeld(scopeFilter := "") {
    for b in Bindings {
        if !b["on"]
            continue
        if (scopeFilter != "" && b["scope"] != scopeFilter)
            continue
        b["on"] := false
        if (b["kind"] = "hold")
            DoHold(b, false)
    }
}

; ---- actions ----
HoldKeyName(b) {
    switch b["act"] {
        case "key_enter":
            return "Enter"
        case "key_escape":
            return "Escape"
        case "key_space":
            return "Space"
        case "key_backspace":
            return "Backspace"
        case "key_up":
            return "Up"
        case "key_down":
            return "Down"
        case "key_left":
            return "Left"
        case "key_right":
            return "Right"
        case "custom_hold":
            return b["param"]
    }
    return ""
}

DoHold(b, down) {
    switch b["act"] {
        case "left_click":
            Click(down ? "left down" : "left up")
        case "right_click":
            Click(down ? "right down" : "right up")
        case "middle_click":
            Click(down ? "middle down" : "middle up")
        default:
            k := HoldKeyName(b)
            if (k != "")
                Send("{" . k . (down ? " down}" : " up}"))
    }
}

DoTap(b) {
    switch b["act"] {
        case "close_window":
            CloseOrKillActiveWindow()
        case "toggle_mouse":
            ToggleMouseMode()
        case "toggle_osk":
            ToggleOnScreenKeyboard()
        case "wheel_up":
            Click("WheelUp")
        case "wheel_down":
            Click("WheelDown")
        case "key_tab":
            Send("{Tab}")
        case "alt_tab":
            Send("!{Tab}")
        case "win_key":
            Send("{LWin}")
        case "play_pause":
            Send("{Media_Play_Pause}")
        case "media_next":
            Send("{Media_Next}")
        case "media_prev":
            Send("{Media_Prev}")
        case "volume_up":
            Send("{Volume_Up}")
        case "volume_down":
            Send("{Volume_Down}")
        case "volume_mute":
            Send("{Volume_Mute}")
        case "custom_tap":
            try Send(b["param"])
    }
}

; Tries to politely close the active window. If it doesn't respond within
; FORCE_KILL_GRACE_SEC, force-kills the process.
CloseOrKillActiveWindow() {
    hwnd := WinExist("A")
    if !hwnd
        return
    target := "ahk_id " . hwnd

    try WinClose(target)

    if !WinWaitClose(target, , FORCE_KILL_GRACE_SEC)
        try WinKill(target)

    ; Still there and InputDood is not elevated: maybe it's an administrator window (Windows blocks the close)
    if (!A_IsAdmin && WinExist(target)) {
        Sleep(300)
        if (WinExist(target) && WindowIsElevated(hwnd))
            NotifyAdminBlocked()
    }
}

; ---- waiting for a combination (used by the shortcut editor) ----
CaptureStart(doneFn, liveFn) {
    global captureActive, captureDone, captureLive, capturePeak
    ReleaseAllHeld()
    captureDone := doneFn
    captureLive := liveFn
    capturePeak := 0
    captureActive := true
    SetTimer(CheckCombo, 30)
    SetTimer(CaptureTimeout, -20000)
}

CaptureCancel() {
    global captureActive, capturePeak
    SetTimer(CaptureTimeout, 0)
    capturePeak := 0
    if captureActive {
        captureActive := false
        ApplyPollInterval()
    }
}

CaptureTimeout() {
    if !captureActive
        return
    fn := captureDone
    CaptureCancel()
    try fn(0)
}

CaptureTick(mask) {
    global capturePeak
    if (mask != 0) {
        capturePeak |= mask
        try captureLive(capturePeak)
        return
    }
    if (capturePeak != 0) {
        peak := capturePeak
        fn := captureDone
        CaptureCancel()
        try fn(peak)
    }
}

; ============================================================================
;  Mouse mode
; ============================================================================
ToggleMouseMode() {
    global mouseModeActive, modeEpoch

    mouseModeActive := !mouseModeActive
    modeEpoch += 1

    if mouseModeActive {
        ApplyPollInterval()
    } else {
        ReleaseAllHeld("mouse")
        ApplyPollInterval()
    }

    ShowMouseModeIndicator(mouseModeActive)
    UpdateState()
}

; Left stick -> cursor
MoveCursor(buf) {
    lx := NumGet(buf, 8, "Short")
    ly := NumGet(buf, 10, "Short")
    normX := ApplyDeadzone(lx, LEFT_STICK_DEADZONE)
    normY := ApplyDeadzone(ly, LEFT_STICK_DEADZONE)
    if (normX != 0 || normY != 0) {
        curvedX := ApplyCurve(normX, CURSOR_CURVE_EXPONENT)
        curvedY := ApplyCurve(normY, CURSOR_CURVE_EXPONENT)
        dx := Round(curvedX * CURSOR_MAX_SPEED)
        dy := Round(-curvedY * CURSOR_MAX_SPEED)  ; stick up (Y+) = cursor up (screen Y-)
        if (dx != 0 || dy != 0)
            MouseMove(dx, dy, 0, "R")
    }
}


; ============================================================================
;  Start with Windows, tray menu, first run
; ============================================================================
; The "/startup" flag lets InputDood know it was launched by Windows (stay in the tray, don't open the window)
StartupCommand() {
    if A_IsCompiled
        return '"' . A_ScriptFullPath . '" /startup'
    return '"' . A_AhkPath . '" "' . A_ScriptFullPath . '" /startup'
}

IsStartupEnabled() {
    try {
        RegRead(RUN_KEY, RUN_VALUE_NAME)
        return true
    } catch {
        return false
    }
}

ToggleStartup(*) {
    if ADMIN_STARTUP {
        MsgBox(Tr("adm_startup_tray"), "InputDood", "Iconi")
        return
    }
    if IsStartupEnabled() {
        try RegDelete(RUN_KEY, RUN_VALUE_NAME)
    } else {
        RegWrite(StartupCommand(), "REG_SZ", RUN_KEY, RUN_VALUE_NAME)
    }
    RefreshStartupMenu()
}

RefreshStartupMenu() {
    try {
        if (IsStartupEnabled() || ADMIN_STARTUP)
            A_TrayMenu.Check(Tr("tray_run_startup"))
        else
            A_TrayMenu.Uncheck(Tr("tray_run_startup"))
    }
}

; Versions before 0.3 registered the startup entry without "/startup": add it, so Windows doesn't open the window at every boot.
FixStartupArg() {
    try {
        v := RegRead(RUN_KEY, RUN_VALUE_NAME)
        if !InStr(v, "/startup")
            RegWrite(StartupCommand(), "REG_SZ", RUN_KEY, RUN_VALUE_NAME)
    }
}

HasArg(prefix) {
    for arg in A_Args {
        if (InStr(arg, prefix) = 1)
            return true
    }
    return false
}

BuildTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add(Tr("tray_open"), (*) => ShowMain(0))
    A_TrayMenu.Default := Tr("tray_open")
    A_TrayMenu.ClickCount := 1
    A_TrayMenu.Add(Tr("tray_mouse"), (*) => ToggleMouseMode())
    A_TrayMenu.Add(A_IsAdmin ? Tr("tray_admin_off") : Tr("tray_admin_on"), (*) => (A_IsAdmin ? RestartNormal() : RestartElevated()))
    A_TrayMenu.Add()
    A_TrayMenu.Add(Tr("tray_check_updates"), (*) => CheckForUpdates(true))
    A_TrayMenu.Add(Tr("tray_about"), (*) => ShowMain(PG_ABOUT))
    A_TrayMenu.Add(Tr("tray_donations"), (*) => Run(PATREON_URL))
    A_TrayMenu.Add()
    A_TrayMenu.Add(Tr("tray_run_startup"), ToggleStartup)
    A_TrayMenu.Add()
    A_TrayMenu.Add(Tr("tray_exit"), (*) => ExitApp())
    ; Loose .ahk: use the icon from the icons folder (the compiled .exe already carries it).
    if (!A_IsCompiled && FileExist(A_ScriptDir . "\icons\InputDood.ico")) {
        try TraySetIcon(A_ScriptDir . "\icons\InputDood.ico")
    }
    RefreshStartupMenu()
    UpdateTray()
}

; Tray tooltip + check mark of the "Mouse mode" item
UpdateTray() {
    try {
        A_IconTip := "InputDood" . (A_IsAdmin ? " (" . Tr("admin_tag") . ")" : "") . (mouseModeActive ? "  ·  " . Tr("tray_mouse") . " ON" : "")
        if mouseModeActive
            A_TrayMenu.Check(Tr("tray_mouse"))
        else
            A_TrayMenu.Uncheck(Tr("tray_mouse"))
    }
}

; InputDood was called GSX before. Keeps the "Run at startup" choice (the old Run entry pointed to
; the old file name) and the "already shown the first-run notice" marker, so renaming doesn't undo the
; user's settings. Must run BEFORE the %AppData%\InputDood folder is created.
MigrateFromGSX() {
    try {
        RegRead(RUN_KEY, "GSX")
        try RegDelete(RUN_KEY, "GSX")
        RegWrite(StartupCommand(), "REG_SZ", RUN_KEY, RUN_VALUE_NAME)
    }
    oldDir := A_AppData . "\GSX"
    if (DirExist(oldDir) && !DirExist(AppDir)) {
        try DirMove(oldDir, AppDir)
    }
}

; Returns true if the notice was shown (first time InputDood runs on this PC)
ShowFirstRunWarning() {
    markerFile := AppDir . "\.firstrun"
    if FileExist(markerFile)
        return false

    msg := Tr("firstrun_body")
    msg .= A_IsCompiled ? Tr("firstrun_compiled_note") : Tr("firstrun_uncompiled_note")

    MsgBox(msg, Tr("firstrun_title"), "Iconi")

    try FileAppend("1", markerFile)
    return true
}

; ============================================================================
;  Administrator mode
; ============================================================================
; Windows doesn't let a normal program send keys / clicks to, or close, a window that runs as administrator
; (Task Manager, for example). The only way around it is for InputDood itself to run elevated. To avoid
; asking for confirmation every time, a scheduled task with "highest privileges" is created ONCE (one UAC
; prompt); after that "Restart as administrator" just starts that task. Normal mode stays the default.
XmlEsc(s) {
    s := StrReplace(s, "&", "&amp;")
    s := StrReplace(s, "<", "&lt;")
    return StrReplace(s, ">", "&gt;")
}

; Command that starts InputDood normally (compiled exe, or AutoHotkey + script)
PlainLaunch() {
    if A_IsCompiled
        return '"' . A_ScriptFullPath . '"'
    return '"' . A_AhkPath . '" "' . A_ScriptFullPath . '"'
}

; XML of one of the tasks: "elev" (on demand), "startup" (elevated, at logon) or "normal" (limited, relaunch)
TaskXml(kind) {
    user := EnvGet("USERDOMAIN") . "\" . A_UserName
    if (kind = "normal") {
        cmd := A_ComSpec
        args := '/c ping -n 3 127.0.0.1 >nul & start "" ' . PlainLaunch()
        level := "LeastPrivilege"
    } else {
        extra := (kind = "startup") ? " /elevated /startup" : " /elevated"
        if A_IsCompiled {
            cmd := A_ScriptFullPath
            args := Trim(extra)
        } else {
            cmd := A_AhkPath
            args := '"' . A_ScriptFullPath . '"' . extra
        }
        level := "HighestAvailable"
    }
    x := '<?xml version="1.0" encoding="UTF-16"?>`r`n'
    x .= '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">`r`n'
    if (kind = "startup")
        x .= '<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>' . XmlEsc(user) . '</UserId><Delay>PT5S</Delay></LogonTrigger></Triggers>`r`n'
    x .= '<Principals><Principal id="Author"><UserId>' . XmlEsc(user) . '</UserId><LogonType>InteractiveToken</LogonType><RunLevel>' . level . '</RunLevel></Principal></Principals>`r`n'
    x .= '<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><ExecutionTimeLimit>PT0S</ExecutionTimeLimit><AllowHardTerminate>true</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable></Settings>`r`n'
    x .= '<Actions Context="Author"><Exec><Command>' . XmlEsc(cmd) . '</Command><Arguments>' . XmlEsc(args) . '</Arguments></Exec></Actions>`r`n'
    x .= '</Task>`r`n'
    return x
}

TaskExists(name) {
    try {
        return (RunWait('schtasks.exe /Query /TN "' . name . '"', , "Hide") = 0)
    }
    return false
}

; Creates / deletes the tasks in a single elevated step (one UAC prompt). Returns true if the result is what was asked.
SetupAdminTasks(wantAdmin, wantElev) {
    dir := A_Temp . "\InputDood_admin"
    try DirDelete(dir, true)
    DirCreate(dir)
    bat := '@echo off`r`n'
    for item in [["elev", TASK_ELEV, wantAdmin], ["startup", TASK_ELEV_STARTUP, wantAdmin && wantElev], ["normal", TASK_NORMAL, wantAdmin]] {
        if item[3] {
            f := dir . "\" . item[1] . ".xml"
            FileAppend(TaskXml(item[1]), f, "UTF-16")
            bat .= 'schtasks /Create /TN "' . item[2] . '" /XML "' . f . '" /F`r`n'
        } else {
            bat .= 'schtasks /Delete /TN "' . item[2] . '" /F`r`n'
        }
    }
    bat .= 'exit /b 0`r`n'
    batFile := dir . "\apply.cmd"
    FileAppend(bat, batFile, "CP0")
    try {
        RunWait('*RunAs "' . batFile . '"', , "Hide")
    } catch {
        try DirDelete(dir, true)
        return false
    }
    try DirDelete(dir, true)
    return (TaskExists(TASK_ELEV) = wantAdmin) && (TaskExists(TASK_ELEV_STARTUP) = (wantAdmin && wantElev))
}

; Is the window's process running elevated? (only asked when an action on that window failed)
WindowIsElevated(hwnd) {
    pid := 0
    try pid := WinGetPID("ahk_id " . hwnd)
    if !pid
        return false
    hProc := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")    ; PROCESS_QUERY_LIMITED_INFORMATION
    if !hProc
        return false
    elev := false
    tok := 0
    if DllCall("advapi32\OpenProcessToken", "Ptr", hProc, "UInt", 0x8, "Ptr*", &tok, "Int") {
        buf := Buffer(4, 0)
        ret := 0
        if DllCall("advapi32\GetTokenInformation", "Ptr", tok, "Int", 20, "Ptr", buf, "UInt", 4, "UInt*", &ret, "Int")    ; TokenElevation
            elev := (NumGet(buf, 0, "UInt") != 0)
        DllCall("CloseHandle", "Ptr", tok)
    } else {
        elev := true        ; we can see the process but not its token: it has a higher integrity level
    }
    DllCall("CloseHandle", "Ptr", hProc)
    return elev
}

; An administrator window blocked an action: two low beeps + a message on the Status page for a minute
NotifyAdminBlocked() {
    global adminBlocked
    adminBlocked := true
    SoundBeep(500, 110)
    SoundBeep(500, 110)
    UpdateState()
    SetTimer(ClearAdminBlocked, -60000)
}

ClearAdminBlocked() {
    global adminBlocked
    adminBlocked := false
    UpdateState()
}

; Normal -> administrator. The elevated copy replaces this one (SingleInstance Force).
RestartElevated() {
    if A_IsAdmin
        return
    if !TaskExists(TASK_ELEV) {
        if (MsgBox(Tr("adm_setup_ask"), "InputDood", "YesNo Icon?") != "Yes")
            return
        if !SetupAdminTasks(true, ADMIN_STARTUP) {
            MsgBox(Tr("o_admin_failed"), "InputDood", "Iconx")
            return
        }
        IniWrite("1", IniFile, "general", "adminMode")
        LoadSettings()
    }
    RememberOpenWindow()
    try Run('schtasks.exe /Run /TN "' . TASK_ELEV . '"', , "Hide")
    SetTimer(AdminLaunchFailed, -7000)       ; if we are still alive after a few seconds, it didn't start
}

AdminLaunchFailed() {
    MsgBox(Tr("adm_launch_failed"), "InputDood", "Iconx")
}

; Administrator -> normal. A limited task waits 2 seconds (so this copy is gone) and starts InputDood normally.
RestartNormal() {
    if !A_IsAdmin
        return
    if !TaskExists(TASK_NORMAL) {
        MsgBox(Tr("adm_launch_failed"), "InputDood", "Iconx")
        return
    }
    RememberOpenWindow()
    ReleaseAllHeld()
    try Run('schtasks.exe /Run /TN "' . TASK_NORMAL . '"', , "Hide")
    ExitApp()
}

; If the window is open, the new copy opens it again on the same page
RememberOpenWindow() {
    try {
        if (IsObject(MainGui) && MainBuilt && DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd))
            IniWrite(CurPage, IniFile, "general", "reopenUI")
    }
}

; Compares two versions like "1.2.3" field by field, numerically (not as
; text: "0.3.10" > "0.3.2" even though "10" < "2" as a string). Returns 1
; if a > b, -1 if a < b, 0 if equal. Missing fields are treated as 0 (so
; "1.2" = "1.2.0").
CompareVersions(a, b) {
    partsA := StrSplit(a, ".")
    partsB := StrSplit(b, ".")
    maxLen := Max(partsA.Length, partsB.Length)
    Loop maxLen {
        na := (A_Index <= partsA.Length) ? Integer(partsA[A_Index]) : 0
        nb := (A_Index <= partsB.Length) ? Integer(partsB[A_Index]) : 0
        if (na > nb)
            return 1
        if (na < nb)
            return -1
    }
    return 0
}

; Checks the latest published GitHub release and warns if there's a
; newer version than the current one. manual=true means the user asked
; for this from the tray menu, so we also tell them when they're ALREADY
; on the latest version (the silent background check doesn't bother with
; that). Any network error is silently ignored, so as not to be annoying
; when there's no internet.
;
; If the release has a downloadable asset of the same type we're
; currently running (.exe if compiled, .ahk if running the loose
; script), a self-update is offered. If that asset isn't found (for
; example, only a source-code zip is attached), it falls back to opening
; the downloads page like before.
CheckForUpdates(manual) {
    global APP_VERSION, GITHUB_REPO
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/" . GITHUB_REPO . "/releases/latest", true)
        whr.SetRequestHeader("User-Agent", "InputDood-Updater")
        whr.Send()
        whr.WaitForResponse(10)  ; up to 10 seconds, never hangs

        if (whr.Status != 200) {
            if manual
                MsgBox(TrFmt("update_check_failed", whr.Status), "InputDood", "Iconi")
            return
        }

        json := whr.ResponseText

        if !RegExMatch(json, '"tag_name"\s*:\s*"v?([^"]+)"', &m)
            return

        latest := m[1]
        cmp := CompareVersions(latest, APP_VERSION)
        if (cmp <= 0) {
            ; latest = APP_VERSION, or even older (e.g. you're testing a
            ; dev build that's newer than the latest published release):
            ; nothing to offer.
            if manual
                MsgBox(TrFmt("update_up_to_date", APP_VERSION), "InputDood", "Iconi")
            return
        }

        wantedExt := A_IsCompiled ? ".exe" : ".ahk"
        downloadUrl := ""
        pos := 1
        while RegExMatch(json, '"browser_download_url"\s*:\s*"([^"]+)"', &am, pos) {
            url := StrReplace(am[1], "\/", "/")
            if (SubStr(url, -StrLen(wantedExt)) = wantedExt) {
                downloadUrl := url
                break
            }
            pos := am.Pos + am.Len
        }

        msg := TrFmt("update_available_body", latest, APP_VERSION)

        if (downloadUrl = "") {
            result := MsgBox(msg . Tr("update_open_page_question"),
                Tr("update_available_title"), "YesNo Iconi")
            if (result = "Yes")
                Run("https://github.com/" . GITHUB_REPO . "/releases/latest")
            return
        }

        result := MsgBox(
            msg . Tr("update_self_question"),
            Tr("update_available_title"),
            "YesNo Iconi"
        )
        if (result = "Yes")
            DoSelfUpdate(downloadUrl, latest)

    } catch as e {
        if manual
            MsgBox(TrFmt("update_check_error", e.Message), "InputDood", "Iconi")
    }
}

; Downloads the new file into a temp folder and launches a helper .bat
; that:
;   1) waits (retrying) for this process to release the current file,
;   2) moves the new file on top of the old one (same name and folder,
;      so shortcuts / the startup registry entry keep pointing to the
;      right place),
;   3) relaunches InputDood, passing it an "/updated:<version>" argument so
;      the new instance knows to show a "update complete" notice,
;   4) deletes itself.
; All of this trouble is because Windows won't let you overwrite an
; .exe (or, often, an .ahk in use) while the process still has it open;
; that's why a separate process is needed to wait until this one has
; actually closed.
;
; Note: if InputDood lives in a protected folder (e.g. Program Files),
; replacing the file may require administrator permissions; if the .bat
; keeps retrying forever, that's the most likely cause.
DoSelfUpdate(url, newVersion) {
    try {
        currentFile := A_ScriptFullPath
        tempFile := A_Temp . "\InputDood_update_" . A_TickCount . (A_IsCompiled ? ".exe" : ".ahk")

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetRequestHeader("User-Agent", "InputDood-Updater")
        whr.Send()
        if (whr.Status != 200) {
            MsgBox(TrFmt("update_download_failed", whr.Status), "InputDood", "Iconi")
            return
        }

        stream := ComObject("ADODB.Stream")
        stream.Type := 1  ; binary
        stream.Open()
        stream.Write(whr.ResponseBody)
        stream.SaveToFile(tempFile, 2)  ; 2 = overwrite if it already exists
        stream.Close()

        launchCmd := A_IsCompiled
            ? '"' . currentFile . '" /updated:' . newVersion
            : '"' . A_AhkPath . '" "' . currentFile . '" /updated:' . newVersion

        batLines := [
            "@echo off",
            ":wait",
            "timeout /t 1 /nobreak >nul",
            'move /y "' . tempFile . '" "' . currentFile . '" >nul 2>&1',
            "if errorlevel 1 goto wait",
            'start "" ' . launchCmd,
            'del "%~f0"'
        ]
        batContent := ""
        for line in batLines
            batContent .= line . "`r`n"

        batFile := A_Temp . "\InputDood_update_" . A_TickCount . ".bat"
        FileAppend(batContent, batFile)

        Run('"' . batFile . '"', , "Hide")
        ExitApp()

    } catch as e {
        MsgBox(TrFmt("update_install_failed", e.Message), "InputDood", "Iconi")
    }
}

; If this instance was launched by the self-update .bat above, it will
; carry an "/updated:<version>" argument on the command line — show a
; one-time confirmation that the update actually landed.
CheckPostUpdateNotice() {
    for arg in A_Args {
        if (InStr(arg, "/updated:") = 1) {
            newVersion := SubStr(arg, StrLen("/updated:") + 1)
            MsgBox(TrFmt("update_done_body", newVersion), Tr("update_done_title"), "Iconi")
            return
        }
    }
}

; --- Mouse Mode visual indicator ---
; TrayTip depends on the app having Windows notifications enabled
; (Settings > Notifications), on Focus Assist, and on the .exe having a
; registered AppUserModelID — none of that is guaranteed for an
; AutoHotkey script/exe, so in practice it can easily never show up.
; This little window of our own (same as the on-screen keyboard) doesn't
; depend on anything from Windows: it always shows.
mouseModeIndicatorGui := ""
MOUSE_INDICATOR_DURATION_MS := 2500

ShowMouseModeIndicator(isOn) {
    global mouseModeIndicatorGui, MOUSE_INDICATOR_DURATION_MS

    ; Cancels any pending auto-hide from a previous activation, and
    ; destroys the previous indicator if it somehow was still alive
    ; (avoids an old timer wiping out a new one if you toggle very fast).
    SetTimer(HideMouseModeIndicator, 0)
    if (mouseModeIndicatorGui != "") {
        mouseModeIndicatorGui.Destroy()
        mouseModeIndicatorGui := ""
    }

    if (INDICATOR_MODE = "none")
        return

    ; If the foreground window is a fullscreen game, DON'T create any
    ; window on top of it: in exclusive fullscreen (DirectX), Windows
    ; kicks the game out of fullscreen / minimizes it / makes it lose
    ; focus as soon as another topmost window appears, even one with
    ; WS_EX_NOACTIVATE. An audio cue is used instead: two rising beeps
    ; = ON, two falling beeps = OFF.
    if (INDICATOR_MODE = "beep" || IsForegroundFullscreen()) {
        if isOn {
            SoundBeep(900, 90)
            SoundBeep(1400, 120)
        } else {
            SoundBeep(1400, 90)
            SoundBeep(900, 120)
        }
        return
    }

    ; Font size proportional to screen height, so it's easy to make out
    ; both on a small monitor and on a big 4K TV from the couch. Clamped
    ; so it never looks ridiculous at either extreme.
    fontSize := Round(A_ScreenHeight / 18)
    if (fontSize < 28)
        fontSize := 28
    if (fontSize > 90)
        fontSize := 90

    ; Same style for both states, only the text and color change (lime
    ; green = on, soft red = off) so they're distinguishable at a glance
    ; without having to read carefully.
    text := isOn ? "🖱  Mouse Mode ON" : "🖱  Mouse Mode OFF"
    color := isOn ? "cLime" : "cFF6B6B"

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "InputDood Indicator")
    g.BackColor := "1E1E1E"
    g.MarginX := Round(fontSize * 1.1)
    g.MarginY := Round(fontSize * 0.55)
    g.SetFont("s" . fontSize . " " . color . " Bold", "Segoe UI")
    g.Add("Text", , text)

    ; First shown far off-screen (instead of hidden) to measure its real
    ; size without the user seeing it, then it's centered.
    g.Show("NoActivate AutoSize x-4000 y-4000")
    WinGetPos(, , &w, &h, "ahk_id " . g.Hwnd)

    x := (A_ScreenWidth - w) / 2
    y := (A_ScreenHeight - h) / 2
    WinMove(x, y, , , "ahk_id " . g.Hwnd)
    WinSetTransparent(235, "ahk_id " . g.Hwnd)

    mouseModeIndicatorGui := g
    SetTimer(HideMouseModeIndicator, -MOUSE_INDICATOR_DURATION_MS)
}

; True if the active window covers its whole monitor and has no title
; bar (exclusive or borderless fullscreen game/video). A normal maximized
; window has a caption and leaves the taskbar visible, so it doesn't count.
IsForegroundFullscreen() {
    global FULLSCREEN_SAFE_MODE
    if !FULLSCREEN_SAFE_MODE
        return false
    hwnd := WinExist("A")
    if !hwnd
        return false
    try {
        cls := WinGetClass("ahk_id " . hwnd)
        if (cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd")
            return false   ; desktop / taskbar
        if ((WinGetStyle("ahk_id " . hwnd) & 0xC00000) = 0xC00000)
            return false   ; has a title bar -> regular window
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
    } catch {
        return false
    }
    hMon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")  ; NEAREST
    mi := Buffer(40, 0)
    NumPut("UInt", 40, mi, 0)
    if !DllCall("GetMonitorInfoW", "Ptr", hMon, "Ptr", mi)
        return false
    ml := NumGet(mi, 4, "Int"),  mt := NumGet(mi, 8, "Int")
    mr := NumGet(mi, 12, "Int"), mb := NumGet(mi, 16, "Int")
    return (x <= ml && y <= mt && x + w >= mr && y + h >= mb)
}

HideMouseModeIndicator() {
    global mouseModeIndicatorGui
    SetTimer(HideMouseModeIndicator, 0)
    if (mouseModeIndicatorGui != "") {
        mouseModeIndicatorGui.Destroy()
        mouseModeIndicatorGui := ""
    }
}

; Converts a raw stick value (-32768..32767) into a normalized -1.0..1.0
; value, applying the deadzone. Returns 0 if inside the deadzone.
ApplyDeadzone(rawValue, deadzone) {
    if (Abs(rawValue) < deadzone)
        return 0.0
    sign := rawValue > 0 ? 1 : -1
    magnitude := (Abs(rawValue) - deadzone) / (32767.0 - deadzone)
    if (magnitude > 1.0)
        magnitude := 1.0
    return sign * magnitude
}

; Applies the curve exponent to a normalized value (-1.0..1.0),
; preserving its sign. With exponent=1.0 this is an identity (linear).
ApplyCurve(normValue, exponent) {
    if (normValue = 0)
        return 0.0
    sign := normValue > 0 ? 1 : -1
    return sign * (Abs(normValue) ** exponent)
}

; --- Custom on-screen keyboard (no external dependencies) ---
; Advantage over osk.exe/TabTip.exe: it's our own window, runs at the
; same integrity level as the rest of the script, and doesn't depend on
; any Windows service (which, in your case, the debloat removed).
;
; WHY IT WASN'T TYPING ANYTHING BEFORE (and Windows was beeping):
; Gui.Show("...NoActivate") only prevents the window from being
; activated the FIRST time it's shown. Without the WS_EX_NOACTIVATE
; extended style (0x08000000) set at window CREATION, Windows would
; activate it when clicking a button, focus would move there, and when
; sending keys, Windows looked for them as dialog "mnemonics" -> beep
; and nothing got typed. Fixed with "+E0x08000000" in the Gui() options.
;
; WHY IT COULDN'T BE DRAGGED:
; The trick of forwarding the click as WM_NCLBUTTONDOWN/HTCAPTION
; (moving the window "as if" you'd clicked its title bar) isn't reliable
; in every case, especially combined with WS_EX_NOACTIVATE. It's
; replaced with a simpler, more direct method: while the left mouse
; button stays pressed over the top bar, a timer moves the window
; following the cursor (WinMove). It's the same mechanism most
; overlays/HUDs use, and doesn't depend on Windows interpreting the
; message in any particular way.

oskGui := ""
oskDragBarHwnd := 0
oskCloseHwnd := 0
oskShiftHwnd := 0
oskKeyMeta := Map()       ; each key's hwnd -> {label, kind, action, bg, bgPress, ctrl}
oskLetterHwnds := []      ; hwnds of letter keys, to reflect upper/lowercase
oskKeyControls := []      ; key controls currently drawn (to destroy them when switching layer)
oskLayout := "letters"    ; "letters" or "symbols"
shiftActive := false

oskDragging := false
oskDragStartMouseX := 0
oskDragStartMouseY := 0
oskDragStartWinX := 0
oskDragStartWinY := 0

oskPressedHwnd := 0       ; currently pressed key (for the visual effect and the "click")
oskRepeatAction := ""     ; action currently auto-repeating while held (e.g. backspace)
oskRepeatFirst := false

; --- Long-press accents on vowels ---
; Tap a vowel key -> plain letter. Hold it past OSK_LONGPRESS_MS -> the
; key flips to show its accented form as a preview, and releasing it
; types the accent instead. No extra key or layout needed for á/é/í/ó/ú.
OSK_LONGPRESS_MS := 400
OSK_VOWEL_ACCENTS := Map("A", "Á", "E", "É", "I", "Í", "O", "Ó", "U", "Ú")
oskLongPressReached := false  ; whether the current press has crossed OSK_LONGPRESS_MS

; --- Keyboard size: percentages, not fixed pixels ---
; Previously OSK_WIDTH/OSK_HEIGHT (and everything else: bar, keys, gaps,
; typography) were fixed pixel numbers, designed for 1080p. On a bigger
; screen (1440p, 4K) that looks proportionally tiny, and on a smaller one
; it can run off the screen. Now everything is derived from percentages,
; so it looks equally big relative to the screen no matter the
; resolution.
;
; Note: this is calculated once at script startup. If you change the
; screen resolution (or plug the HTPC into another monitor/TV) while
; InputDood is already running, the script needs to be restarted for the
; keyboard to recalculate its size.

OSK_WIDTH_PCT  := 0.44   ; % of screen width
OSK_HEIGHT_PCT := 0.40   ; % of screen height

; Safety limits (in pixels) so it doesn't end up absurdly small at a
; very low resolution, nor absurdly huge at a very high one (8K,
; ultrawide monitors, etc.).
OSK_WIDTH  := Max(620, Min(1600, Round(A_ScreenWidth  * OSK_WIDTH_PCT)))
OSK_HEIGHT := Max(300, Min(820,  Round(A_ScreenHeight * OSK_HEIGHT_PCT)))

; The rest of the keyboard's measurements (top bar, key height/width,
; spacing, typography) are percentages OF THE SIZE ALREADY CALCULATED
; above, so everything scales together and keeps the same proportions
; no matter what resolution OSK_WIDTH and OSK_HEIGHT ended up at. The
; percentages come from the previous design (which looked good at
; 660x316), just now applied relatively.
OSK_BARHEIGHT         := Round(OSK_HEIGHT * 0.089)
OSK_ROW_HEIGHT         := Round(OSK_HEIGHT * 0.152)
OSK_ROW_GAP             := Round(OSK_HEIGHT * 0.019)
OSK_KEY_GAP             := Round(OSK_WIDTH  * 0.009)
OSK_ROW_START_X         := Round(OSK_WIDTH  * 0.015)
OSK_KEY_WIDTH_NORMAL   := Round(OSK_WIDTH  * 0.070)
OSK_KEY_WIDTH_WIDE     := Round(OSK_WIDTH  * 0.145)
OSK_KEY_WIDTH_SPACE    := Round(OSK_WIDTH  * 0.409)

; Typography sized relative to whatever contains it (key or bar), with a
; readable minimum in case the keyboard ended up very small.
OSK_FONT_KEY   := Max(9, Round(OSK_ROW_HEIGHT * 0.27))
OSK_FONT_BAR   := Max(8, Round(OSK_BARHEIGHT * 0.36))
OSK_FONT_CLOSE := Max(9, Round(OSK_BARHEIGHT * 0.50))

; Margins relative to the SCREEN (not the keyboard): how much breathing
; room to leave against the edges, and how far to separate the keyboard
; from the cursor when it's placed above/below it.
OSK_MARGIN          := Round(A_ScreenHeight * 0.0185)
OSK_GAP_ABOVE_MOUSE := Round(A_ScreenHeight * 0.022)

; --- Color palette ---
OSK_COL_BG            := "1E1E1E"
OSK_COL_BAR           := "111111"
OSK_COL_KEY           := "3A3A3A"
OSK_COL_KEY_PRESS     := "2A2A2A"
OSK_COL_ACCENT        := "3D6EA5"
OSK_COL_ACCENT_PRESS  := "2C5480"
OSK_COL_DANGER        := "8A3B3B"
OSK_COL_DANGER_PRESS  := "6E2E2E"
OSK_COL_TOGGLE_ON     := "3D8A5A"
OSK_COL_TEXT          := "F0F0F0"

; Gui controls in AHK v2 do NOT have their own .Destroy() method (only
; the whole Gui object has one, and it destroys the ENTIRE window). To
; destroy a single control you have to call the Windows API directly on
; its handle.
DestroyOskControl(ctrl) {
    try DllCall("DestroyWindow", "Ptr", ctrl.Hwnd)
}

; "Text" controls don't always repaint themselves when you change their
; background color after creation (WM_CTLCOLORSTATIC is only queried on
; the next repaint, which doesn't always happen on its own). Forced here.
RedrawOskControl(ctrl) {
    DllCall("InvalidateRect", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", true)
    DllCall("UpdateWindow", "Ptr", ctrl.Hwnd)
}

ToggleOnScreenKeyboard() {
    global oskGui

    ; Same limitation as the Mouse Mode indicator: a topmost window over
    ; a fullscreen game makes it lose focus / drop out of fullscreen. If
    ; the keyboard isn't already open and the foreground window is a
    ; fullscreen one, refuse to open it and give an audio cue instead:
    ; three short low beeps = "not available here".
    oskVisible := (oskGui != "" && WinExist("ahk_id " . oskGui.Hwnd)
        && DllCall("IsWindowVisible", "Ptr", oskGui.Hwnd))
    if (!oskVisible && IsForegroundFullscreen()) {
        Loop 3
            SoundBeep(500, 70)
        return
    }

    if (oskGui = "" || !WinExist("ahk_id " . oskGui.Hwnd)) {
        oskGui := BuildOnScreenKeyboardGui()
        ShowOnScreenKeyboardNearMouse()
        return
    }

    if DllCall("IsWindowVisible", "Ptr", oskGui.Hwnd)
        oskGui.Hide()
    else
        ShowOnScreenKeyboardNearMouse()
}

; Placed centered horizontally over the cursor, and ABOVE it (with a
; margin in between) rather than around it — this way it's much harder
; for the keyboard to cover the text box you're using, which is usually
; right where the cursor is or very close to it. If it doesn't fit above
; (cursor too close to the top edge of the screen), it's placed below the
; cursor instead. This is recalculated EVERY time you open the keyboard,
; following wherever the cursor is at that moment.
ShowOnScreenKeyboardNearMouse() {
    global oskGui, OSK_WIDTH, OSK_HEIGHT, OSK_MARGIN, OSK_GAP_ABOVE_MOUSE

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    x := mx - (OSK_WIDTH / 2)
    if (x < OSK_MARGIN)
        x := OSK_MARGIN
    if (x + OSK_WIDTH > A_ScreenWidth - OSK_MARGIN)
        x := A_ScreenWidth - OSK_WIDTH - OSK_MARGIN

    y := my - OSK_HEIGHT - OSK_GAP_ABOVE_MOUSE
    if (y < OSK_MARGIN)
        y := my + OSK_GAP_ABOVE_MOUSE  ; doesn't fit above: placed below the cursor instead
    if (y + OSK_HEIGHT > A_ScreenHeight - OSK_MARGIN)
        y := A_ScreenHeight - OSK_HEIGHT - OSK_MARGIN

    oskGui.Show("x" . x . " y" . y . " w" . OSK_WIDTH . " h" . OSK_HEIGHT . " NoActivate")
}

BuildOnScreenKeyboardGui() {
    global oskDragBarHwnd, oskCloseHwnd, OSK_WIDTH, OSK_BARHEIGHT, OSK_FONT_BAR, OSK_FONT_CLOSE
    global OSK_COL_BG, OSK_COL_BAR, OSK_COL_TEXT

    ; +E0x08000000 = WS_EX_NOACTIVATE: this line is the key fix so the
    ; window never steals focus, whether when shown or when clicking on
    ; it (buttons or drag bar).
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "InputDood Keyboard")
    g.BackColor := OSK_COL_BG
    g.MarginX := 0
    g.MarginY := 0
    g.OnEvent("Close", (*) => g.Hide())

    ; --- Top bar: title + drag zone + close button ---
    dragBar := g.Add("Text", "x0 y0 w" . (OSK_WIDTH - OSK_BARHEIGHT) . " h" . OSK_BARHEIGHT
        . " +0x300 Background" . OSK_COL_BAR . " c" . OSK_COL_TEXT, Tr("osk_drag_hint"))
    dragBar.SetFont("s" . OSK_FONT_BAR, "Segoe UI")
    oskDragBarHwnd := dragBar.Hwnd

    closeBtn := g.Add("Text", "x" . (OSK_WIDTH - OSK_BARHEIGHT) . " y0 w" . OSK_BARHEIGHT . " h" . OSK_BARHEIGHT
        . " Center +0x300 Background" . OSK_COL_BAR . " cSilver", "×")
    closeBtn.SetFont("s" . OSK_FONT_CLOSE . " Bold", "Segoe UI")
    oskCloseHwnd := closeBtn.Hwnd

    RebuildKeys(g, "letters")

    return g
}

; Rebuilds the visible key set for the given layer ("letters" or
; "symbols"). Destroys the previous keys and draws the new ones; the
; drag bar and close button are left untouched.
RebuildKeys(g, layout) {
    global oskLayout, oskKeyMeta, oskLetterHwnds, oskShiftHwnd, oskKeyControls
    global OSK_BARHEIGHT, OSK_ROW_HEIGHT, OSK_ROW_GAP, OSK_KEY_GAP, OSK_ROW_START_X
    global OSK_KEY_WIDTH_NORMAL, OSK_KEY_WIDTH_WIDE, OSK_KEY_WIDTH_SPACE

    for ctrl in oskKeyControls
        DestroyOskControl(ctrl)
    oskKeyControls := []
    oskKeyMeta := Map()
    oskLetterHwnds := []
    oskShiftHwnd := 0
    oskLayout := layout

    spaceLabel := Tr("osk_space")

    if (layout = "letters") {
        rows := [
            [["1","key"],["2","key"],["3","key"],["4","key"],["5","key"],["6","key"],["7","key"],["8","key"],["9","key"],["0","key"],["⌫","danger","BACKSPACE"]],
            [["Q","letter"],["W","letter"],["E","letter"],["R","letter"],["T","letter"],["Y","letter"],["U","letter"],["I","letter"],["O","letter"],["P","letter"]],
            [["A","letter"],["S","letter"],["D","letter"],["F","letter"],["G","letter"],["H","letter"],["J","letter"],["K","letter"],["L","letter"],["Ñ","letter"],["Enter","accent","ENTER"]],
            [["⇧ Shift","toggle","SHIFT"],["Z","letter"],["X","letter"],["C","letter"],["V","letter"],["B","letter"],["N","letter"],["M","letter"],[",","key"],[".","key"]],
            [["?123","accent","LAYOUT_SYMBOLS"],["Esc","accent","ESC"],[spaceLabel,"space","SPACE"],["Tab","accent","TAB"]]
        ]
    } else {
        rows := [
            [["!","key"],["@","key"],["#","key"],["$","key"],["%","key"],["^","key"],["&","key"],["*","key"],["(","key"],[")","key"],["⌫","danger","BACKSPACE"]],
            [["-","key"],["_","key"],["=","key"],["+","key"],["[","key"],["]","key"],["{","key"],["}","key"],["\","key"],["|","key"]],
            [[";","key"],[":","key"],["'","key"],['"',"key"],["<","key"],[">","key"],["Enter","accent","ENTER"]],
            [["~","key"],["``","key"],[",","key"],[".","key"],["/","key"],["?","key"]],
            [["ABC","accent","LAYOUT_LETTERS"],["Esc","accent","ESC"],[spaceLabel,"space","SPACE"],["Tab","accent","TAB"]]
        ]
    }

    y := OSK_BARHEIGHT + OSK_ROW_GAP
    for row in rows {
        x := OSK_ROW_START_X
        for item in row {
            label := item[1]
            kind := item[2]
            action := (item.Length >= 3) ? item[3] : label

            w := (kind = "space") ? OSK_KEY_WIDTH_SPACE
                : (kind = "danger" || kind = "accent" || kind = "toggle") ? OSK_KEY_WIDTH_WIDE
                : OSK_KEY_WIDTH_NORMAL

            ctrl := AddOskKey(g, x, y, w, OSK_ROW_HEIGHT, label, kind, action)
            oskKeyControls.Push(ctrl)

            if (kind = "letter")
                oskLetterHwnds.Push(ctrl.Hwnd)
            if (action = "SHIFT")
                oskShiftHwnd := ctrl.Hwnd

            x += w + OSK_KEY_GAP
        }
        y += OSK_ROW_HEIGHT + OSK_ROW_GAP
    }

    UpdateLetterCaseDisplay()
    UpdateShiftVisual()
}

; Creates a "key" as a text control (not a native button) so it can be
; given its own color per type — native Windows buttons don't let you
; easily customize their background color.
;
; IMPORTANT: style 0x100 (SS_NOTIFY) is added on top of 0x200
; (SS_CENTERIMAGE, to vertically center the text). Without SS_NOTIFY, a
; text control responds HTTRANSPARENT to WM_NCHITTEST: the click simply
; PASSES THROUGH it and reaches the window behind it instead of the key,
; so our click handling (OnMessage below) never finds out about it. This
; also applies to the drag bar and the close button, which is why they
; all use "+0x300" (0x100 | 0x200) in their options.
AddOskKey(g, x, y, w, h, label, kind, action) {
    global oskKeyMeta, OSK_COL_KEY, OSK_COL_KEY_PRESS, OSK_COL_ACCENT, OSK_COL_ACCENT_PRESS
    global OSK_COL_DANGER, OSK_COL_DANGER_PRESS, OSK_COL_TEXT, OSK_FONT_KEY

    switch kind {
        case "accent":
            bg := OSK_COL_ACCENT
            bgPress := OSK_COL_ACCENT_PRESS
        case "danger":
            bg := OSK_COL_DANGER
            bgPress := OSK_COL_DANGER_PRESS
        default:
            bg := OSK_COL_KEY
            bgPress := OSK_COL_KEY_PRESS
    }

    ctrl := g.Add("Text", "x" . x . " y" . y . " w" . w . " h" . h . " Center +0x300 Background" . bg . " c" . OSK_COL_TEXT, label)
    ctrl.SetFont("s" . OSK_FONT_KEY, "Segoe UI")

    oskKeyMeta[ctrl.Hwnd] := {label: label, kind: kind, action: action, bg: bg, bgPress: bgPress, ctrl: ctrl}
    return ctrl
}

; --- Low-level click and drag handling ---
; OnMessage is used instead of OnEvent("Click") because we need to know
; when the mouse button goes DOWN (for visual feedback and to be able to
; repeat while held) and when it goes UP (to fire the action), not just
; when a full click completes.
OnMessage(0x201, OSK_HandleLButtonDown)  ; WM_LBUTTONDOWN
OnMessage(0x202, OSK_HandleLButtonUp)    ; WM_LBUTTONUP

OSK_HandleLButtonDown(wParam, lParam, msg, hwnd) {
    global oskDragBarHwnd, oskCloseHwnd, oskKeyMeta, oskPressedHwnd, oskRepeatAction, oskRepeatFirst
    global oskDragging, oskDragStartMouseX, oskDragStartMouseY, oskDragStartWinX, oskDragStartWinY, oskGui
    global oskLongPressReached, OSK_LONGPRESS_MS, OSK_VOWEL_ACCENTS

    if (hwnd = oskCloseHwnd) {
        oskGui.Hide()
        return
    }

    if (hwnd = oskDragBarHwnd) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        WinGetPos(&wx, &wy, , , "ahk_id " . oskGui.Hwnd)
        oskDragStartMouseX := mx
        oskDragStartMouseY := my
        oskDragStartWinX := wx
        oskDragStartWinY := wy
        oskDragging := true
        ; Raises the system timer resolution to 1ms for the duration of
        ; the drag (Windows rounds to ~15ms by default, which made the
        ; movement noticeably choppy). Reverted on release.
        DllCall("winmm\timeBeginPeriod", "UInt", 1)
        SetTimer(OSK_DragStep, -8)
        return
    }

    if oskKeyMeta.Has(hwnd) {
        oskPressedHwnd := hwnd
        oskLongPressReached := false
        meta := oskKeyMeta[hwnd]
        meta.ctrl.Opt("+Background" . meta.bgPress)
        RedrawOskControl(meta.ctrl)

        ; Backspace: sent immediately on press, and if held down, it
        ; repeats for as long as the mouse button (or the control's
        ; trigger, which also generates mouse clicks) stays down.
        if (meta.action = "BACKSPACE") {
            Send("{Backspace}")
            oskRepeatAction := "BACKSPACE"
            oskRepeatFirst := true
            SetTimer(OSK_RepeatStep, 350)
        }

        ; Vowels: arm a one-shot check that flips the key to its accented
        ; preview once the hold crosses OSK_LONGPRESS_MS. It bails out on
        ; its own (see OSK_VowelLongPressCheck) if the key was released
        ; or a different key is pressed by the time it fires.
        if (meta.kind = "letter" && OSK_VOWEL_ACCENTS.Has(meta.action))
            SetTimer(OSK_VowelLongPressCheck.Bind(hwnd), -OSK_LONGPRESS_MS)
    }
}

; Fires once, OSK_LONGPRESS_MS after a vowel key was pressed. If that
; same key is still the one being held, marks the press as "long" and
; swaps the key's label to its accented form so the user can see what
; they're about to type before letting go.
OSK_VowelLongPressCheck(hwnd) {
    global oskPressedHwnd, oskKeyMeta, oskLongPressReached, shiftActive, OSK_VOWEL_ACCENTS

    if (oskPressedHwnd != hwnd || !oskKeyMeta.Has(hwnd))
        return

    oskLongPressReached := true
    meta := oskKeyMeta[hwnd]
    accented := OSK_VOWEL_ACCENTS[meta.action]
    meta.ctrl.Text := shiftActive ? accented : StrLower(accented)
    RedrawOskControl(meta.ctrl)
}

OSK_DragStep() {
    global oskDragging, oskGui, oskDragStartMouseX, oskDragStartMouseY, oskDragStartWinX, oskDragStartWinY

    if !GetKeyState("LButton", "P") {
        oskDragging := false
        DllCall("winmm\timeEndPeriod", "UInt", 1)
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    newX := oskDragStartWinX + (mx - oskDragStartMouseX)
    newY := oskDragStartWinY + (my - oskDragStartMouseY)
    WinMove(newX, newY, , , "ahk_id " . oskGui.Hwnd)

    ; Self-scheduled: it calls itself again only once this run finishes,
    ; instead of a fixed period that could stack up overlapping calls.
    ; Feels smoother and more consistent.
    SetTimer(OSK_DragStep, -8)
}

OSK_RepeatStep() {
    global oskRepeatAction, oskRepeatFirst
    if !GetKeyState("LButton", "P") {
        SetTimer(OSK_RepeatStep, 0)
        oskRepeatAction := ""
        return
    }
    if oskRepeatFirst {
        oskRepeatFirst := false
        SetTimer(OSK_RepeatStep, 45)  ; repeat speed, after the initial delay
    }
    if (oskRepeatAction = "BACKSPACE")
        Send("{Backspace}")
}

OSK_HandleLButtonUp(wParam, lParam, msg, hwnd) {
    global oskPressedHwnd, oskKeyMeta, oskRepeatAction, oskLongPressReached, shiftActive, OSK_VOWEL_ACCENTS

    if (oskPressedHwnd = 0)
        return

    meta := oskKeyMeta.Has(oskPressedHwnd) ? oskKeyMeta[oskPressedHwnd] : 0
    if !meta {
        oskPressedHwnd := 0
        return
    }

    meta.ctrl.Opt("+Background" . meta.bg)
    ; If this was a vowel showing its accented preview, put its label
    ; back to the plain letter now that the press is over.
    if (meta.kind = "letter" && OSK_VOWEL_ACCENTS.Has(meta.action))
        meta.ctrl.Text := shiftActive ? meta.action : StrLower(meta.action)
    RedrawOskControl(meta.ctrl)

    wasRepeating := (oskRepeatAction != "")
    SetTimer(OSK_RepeatStep, 0)
    oskRepeatAction := ""

    ; Only fires the action if you released over the SAME key you
    ; pressed (if you dragged off it, it's canceled, like a normal
    ; button). Backspace was already sent on "down"/repeat.
    if (hwnd = oskPressedHwnd && !wasRepeating)
        OSK_FireKeyAction(meta, oskLongPressReached)

    oskPressedHwnd := 0
}

OSK_FireKeyAction(meta, longPress := false) {
    global shiftActive, OSK_VOWEL_ACCENTS

    switch meta.action {
        case "ENTER":
            Send("{Enter}")
        case "TAB":
            Send("{Tab}")
        case "ESC":
            Send("{Escape}")
        case "SPACE":
            Send("{Space}")
        case "SHIFT":
            shiftActive := !shiftActive
            UpdateShiftVisual()
            UpdateLetterCaseDisplay()
        case "LAYOUT_SYMBOLS":
            RebuildKeys(meta.ctrl.Gui, "symbols")
        case "LAYOUT_LETTERS":
            RebuildKeys(meta.ctrl.Gui, "letters")
        case "BACKSPACE":
            ; already handled in OSK_HandleLButtonDown / OSK_RepeatStep
        default:
            ch := meta.action
            if (meta.kind = "letter") {
                ; Long-pressing a vowel types its accented form instead
                ; of the plain letter.
                if (longPress && OSK_VOWEL_ACCENTS.Has(ch))
                    ch := OSK_VOWEL_ACCENTS[ch]
                ch := shiftActive ? ch : StrLower(ch)
            }
            SendText(ch)
    }
}

; Highlights the Shift key in green while it's active (like caps-lock),
; so it's noticeable at a glance.
UpdateShiftVisual() {
    global oskShiftHwnd, oskKeyMeta, shiftActive, OSK_COL_TOGGLE_ON, OSK_COL_KEY

    if !oskShiftHwnd
        return
    meta := oskKeyMeta[oskShiftHwnd]
    meta.bg := shiftActive ? OSK_COL_TOGGLE_ON : OSK_COL_KEY
    meta.ctrl.Opt("+Background" . meta.bg)
    RedrawOskControl(meta.ctrl)
    meta.ctrl.Text := shiftActive ? "⇧ SHIFT" : "⇧ Shift"
}

; Reflects on the letter keys whether they'll type upper- or lowercase
; based on Shift's current state.
UpdateLetterCaseDisplay() {
    global oskLetterHwnds, oskKeyMeta, shiftActive

    for h in oskLetterHwnds {
        meta := oskKeyMeta[h]
        meta.ctrl.Text := shiftActive ? meta.action : StrLower(meta.action)
    }
}


; ============================================================================
;  Main window  (sidebar: Status | Shortcuts | Mouse mode | Options | About)
;  Same look and helpers as SyncDood: flat controls, light / dark theme that follows Windows.
; ============================================================================
SW := 200, CX := 228, CW0 := 724, W0 := 980, H0 := 680       ; design units (the real pixels are scaled by Px)
PG_STATUS := 1, PG_KEYS := 2, PG_MOUSE := 3, PG_OPT := 4, PG_ABOUT := 5
PAD_W := 700, PAD_H := 320                  ; size (design units) of the controller drawing on the Status page
GdipToken := 0
PadHbm := 0
PadG := 0, PadFam := 0, PadFmt := 0

TH := Map()                ; colors of the current theme
UI := Map()                ; named controls
Hov := Map()               ; hover info per control hwnd
FS := Map()                ; font of each text control (to recolor them)
OptC := Map()              ; controls of the Mouse mode / Options pages
Nav := []                  ; sidebar entries
PgCtrls := []              ; controls of each page (to show / hide them)
HovCur := 0
HoverHooked := false
MainGui := ""
MainBuilt := false
CurPage := 1
DarkNow := false
BannerCol := "2154A3"
IconFont := ""
Dpi := A_ScreenDPI / 96    ; provisional: BuildMain measures the scale the controls really get
BaseW := 0, BaseH := 0     ; client size (raw pixels) of the main window right after it was built
KeysLV := ""
ED := Map()                ; state of the shortcut editor window

; Scale a design-unit number to real pixels (Move() and the Size event use raw pixels)
Px(n) {
    return Round(n * Dpi)
}

; ---------------------------------------------------------------- Colors -----
; Mixes two RRGGBB colors: t = 0 gives a, t = 1 gives b
Mix(a, b, t) {
    out := ""
    for i in [1, 3, 5] {
        x := Integer("0x" SubStr(a, i, 2))
        y := Integer("0x" SubStr(b, i, 2))
        out .= Format("{:02X}", Round(x + (y - x) * t))
    }
    return out
}

; RRGGBB -> COLORREF (0x00BBGGRR)
BGR(hex) {
    r := Integer("0x" SubStr(hex, 1, 2))
    g := Integer("0x" SubStr(hex, 3, 2))
    b := Integer("0x" SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r
}

WindowsDark() {
    try {
        return (RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 0)
    }
    return false
}

IsDark() {
    if (THEME_PREF = "dark")
        return true
    if (THEME_PREF = "light")
        return false
    return WindowsDark()
}

; Fills TH with the light or dark palette (decided by the "theme" option / Windows)
LoadTheme() {
    global DarkNow
    DarkNow := IsDark()
    if DarkNow {
        c := Map("bg", "141923", "card", "1C2330", "border", "2B3445", "text", "E7EBF3", "sub", "93A0B8"
            , "side", "0D111A", "sideText", "9FB0CC", "sideHov", "171F2E", "sideSel", "1F2B44"
            , "accent", "4F8CFF", "accentHov", "6FA1FF", "btn", "2A3447", "btnHov", "36435C"
            , "ok", "3DD68C", "warn", "F5B83D", "err", "FF6B6B", "info", "8794AB", "down", "35C7D6"
            , "lvBg", "141923", "editBg", "0F141D", "track", "2B3445"
            , "bn_ok", "17603E", "bn_sync", "1B4B8F", "bn_warn", "8F5E0C", "bn_err", "8A2233")
    } else {
        c := Map("bg", "F2F4F8", "card", "FFFFFF", "border", "DCE1EA", "text", "1B2433", "sub", "667085"
            , "side", "14213D", "sideText", "AEBBD3", "sideHov", "1C2D55", "sideSel", "27407A"
            , "accent", "2F6BEB", "accentHov", "2557C2", "btn", "E3E8F1", "btnHov", "D3DAE8"
            , "ok", "1C9B57", "warn", "C27803", "err", "D13B3B", "info", "7D8799", "down", "0E8FA0"
            , "lvBg", "F2F4F8", "editBg", "FFFFFF", "track", "DCE1EA"
            , "bn_ok", "1E7B4F", "bn_sync", "2154A3", "bn_warn", "B4690E", "bn_err", "A32638")
    }
    TH.Clear()
    for k, v in c
        TH[k] := v
}

HasFont(name) {
    for hive in ["HKLM", "HKCU"] {
        try {
            RegRead(hive "\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts", name " (TrueType)")
            return true
        }
    }
    return false
}

; Image for the Picture controls: the logo PNG (always loads); falls back to the .ico. "" if none.
PicPath() {
    for f in [LogoFile, A_ScriptDir "\icons\InputDood.png", A_ScriptDir "\icons\InputDood.ico"] {
        if FileExist(f)
            return f
    }
    return ""
}

; ------------------------------------------------------- Control helpers -----
; Text with its own font / color / background (all given explicitly so it can be recolored later)
AddTxt(g, arr, opts, text, spec, color, bg) {
    g.SetFont(spec " c" color, "Segoe UI")
    c := g.Add("Text", opts " Background" bg, text)
    FS[c.Hwnd] := [spec, "Segoe UI"]
    if IsObject(arr)
        arr.Push(c)
    return c
}

; Changes the text color of a control created with AddTxt / AddBtn
Recolor(c, color) {
    f := FS.Get(c.Hwnd, ["s9 norm", "Segoe UI"])
    c.SetFont(f[1] " c" color, f[2])
}

; [background, hover background, text color] of each button kind
BtnColors(kind) {
    switch kind {
        case "prim", "segon":
            return [TH["accent"], TH["accentHov"], "FFFFFF"]
        case "ban":
            return ["FFFFFF", "E6ECF7", "1B2433"]
        case "ban2":
            return [Mix(BannerCol, "FFFFFF", 0.20), Mix(BannerCol, "FFFFFF", 0.32), "FFFFFF"]
        case "danger":
            return [TH["btn"], TH["btnHov"], TH["err"]]
    }
    return [TH["btn"], TH["btnHov"], TH["text"]]
}

; Flat button made from a Text control: it looks identical in light and dark mode.
AddBtn(g, arr, x, y, w, h, label, fn, kind := "norm", spec := "s9 norm") {
    col := BtnColors(kind)
    g.SetFont(spec " c" col[3], "Segoe UI")
    c := g.Add("Text", Format("x{1} y{2} w{3} h{4} +0x100 +0x200 Center Background{5}", x, y, w, h, col[1]), label)
    FS[c.Hwnd] := [spec, "Segoe UI"]
    c.OnEvent("Click", fn)
    Hov[c.Hwnd] := Map("ctrls", [c], "bg", col[1], "hv", col[2], "kind", kind)
    if IsObject(arr)
        arr.Push(c)
    return c
}

; Re-styles a button (e.g. selected / not selected)
SetBtnKind(c, kind) {
    col := BtnColors(kind)
    info := Hov[c.Hwnd]
    info["bg"] := col[1]
    info["hv"] := col[2]
    info["kind"] := kind
    c.Opt("Background" col[1])
    Recolor(c, col[3])
    c.Redraw()
}

; Single-line text box with the current theme
AddEdit(g, arr, x, y, w, text, extra := "") {
    g.SetFont("s9 norm c" TH["text"], "Segoe UI")
    opt := Format("x{1} y{2} w{3} c{4} Background{5} {6}", x, y, w, TH["text"], TH["editBg"], extra)
    if !RegExMatch(extra, "i)\br\d")
        opt .= " r1"
    if DarkNow
        opt .= " -E0x200 +Border"
    c := g.Add("Edit", opt, text)
    if IsObject(arr)
        arr.Push(c)
    return c
}

; Row of exclusive options. Returns Map("sel", n, "btns", [...])
AddSeg(g, arr, x, y, labels, sel, bw := 92) {
    seg := Map("sel", sel, "btns", [])
    for i, lb in labels {
        c := AddBtn(g, arr, x + (i - 1) * (bw + 4), y, bw, 28, lb, SegClick.Bind(seg, i), (i = sel) ? "segon" : "norm")
        seg["btns"].Push(c)
    }
    return seg
}

SegClick(seg, i, *) {
    seg["sel"] := i
    for n, c in seg["btns"]
        SetBtnKind(c, (n = i) ? "segon" : "norm")
}

; On/off switch with a label. Returns Map("on", bool, ...)
AddToggle(g, arr, x, y, w, label, on) {
    t := Map("on", on ? true : false)
    g.SetFont("s10 norm cFFFFFF", "Wingdings")
    t["box"] := g.Add("Text", Format("x{1} y{2} w22 h22 +0x100 +0x200 Center Background{3}", x, y, on ? TH["accent"] : TH["btn"]), on ? Chr(0xFC) : "")
    t["lbl"] := AddTxt(g, arr, Format("x{1} y{2} w{3} h22 +0x100 +0x200", x + 32, y, w - 32), label, "s9 norm", TH["text"], TH["bg"])
    if IsObject(arr)
        arr.Push(t["box"])
    t["box"].OnEvent("Click", ToggleClick.Bind(t))
    t["lbl"].OnEvent("Click", ToggleClick.Bind(t))
    return t
}

ToggleClick(t, *) {
    t["on"] := !t["on"]
    t["box"].Opt("Background" (t["on"] ? TH["accent"] : TH["btn"]))
    t["box"].Text := t["on"] ? Chr(0xFC) : ""
    t["box"].Redraw()
}

SetToggle(t, on) {
    t["on"] := on ? true : false
    t["box"].Opt("Background" (t["on"] ? TH["accent"] : TH["btn"]))
    t["box"].Text := t["on"] ? Chr(0xFC) : ""
}

; "✓ Saved" next to a button, gone after a moment
ShowSaved(key) {
    try {
        UI[key].Text := T("saved")
        SetTimer(ClearSaved.Bind(key), -2500)
    }
}

ClearSaved(key) {
    try {
        UI[key].Text := ""
    }
}

; ---------------------------------------------------------------- Hover -----
OnMouseMove(wParam, lParam, msg, hwnd) {
    global HovCur
    ctl := 0
    try {
        MouseGetPos(, , , &ctl, 2)
    }
    if (ctl = HovCur)
        return
    HoverOut()
    if (ctl != 0 && Hov.Has(ctl)) {
        HovCur := ctl
        for c in Hov[ctl]["ctrls"] {
            c.Opt("Background" Hov[ctl]["hv"])
            c.Redraw()
        }
        SetTimer(HoverPoll, 100)
    }
}

HoverOut() {
    global HovCur
    if (HovCur = 0)
        return
    if Hov.Has(HovCur) {
        info := Hov[HovCur]
        try {
            for c in info["ctrls"] {
                c.Opt("Background" info["bg"])
                c.Redraw()
            }
        }
    }
    HovCur := 0
}

HoverPoll() {
    ctl := 0
    try {
        MouseGetPos(, , , &ctl, 2)
    }
    if (ctl != HovCur) {
        HoverOut()
        SetTimer(HoverPoll, 0)
    }
}

; ---------------------------------------------------------------- Window -----
ShowMain(page := 0) {
    if !IsObject(MainGui)
        BuildMain()
    ShowPage(page > 0 ? page : CurPage)
    UpdateState()
    MainGui.Show()
    UpdateLive(lastMaskAll)
}

BuildMain() {
    global MainGui, MainBuilt, KeysLV, IconFont, BannerCol, HoverHooked, Dpi, BaseW, BaseH
    MainBuilt := false
    LoadTheme()
    UI.Clear()
    Hov.Clear()
    FS.Clear()
    OptC.Clear()
    Nav.Length := 0
    PgCtrls.Length := 0
    BannerCol := TH["bn_sync"]
    IconFont := HasFont("Segoe MDL2 Assets") ? "Segoe MDL2 Assets" : ""

    g := Gui("+Resize +MinSize" Px(900) "x" Px(620), "InputDood")
    g.BackColor := TH["bg"]
    g.MarginX := 0
    g.MarginY := 0
    g.SetFont("s9 norm c" TH["text"], "Segoe UI")
    MainGui := g

    ; ---- sidebar
    UI["side"] := g.Add("Text", Format("x0 y0 w{1} h{2} Background{3}", SW, H0, TH["side"]), "")
    ; Real scale of this window: the sidebar was asked to be SW design units wide. Everything that is moved later
    ; (Px) uses this, not A_ScreenDPI, which can differ (laptop screen vs external 4K monitor).
    try {
        UI["side"].GetPos(, , &sideRaw)
        if (sideRaw > 0)
            Dpi := sideRaw / SW
    }
    g.Opt("+MinSize" Px(900) "x" Px(620))
    logo := PicPath()
    if (logo != "") {
        try {
            g.Add("Picture", "x18 y20 w36 h36 BackgroundTrans", logo)
        }
    }
    AddTxt(g, "", "x64 y20 w130 h36 +0x200", "InputDood", "s14 bold", "FFFFFF", TH["side"])
    labels := [T("tab_status"), T("tab_keys"), T("tab_mouse"), T("tab_options"), T("tab_about")]
    icons := [Chr(0xE80F), Chr(0xE7FC), Chr(0xE7C9), Chr(0xE713), Chr(0xE946)]
    for i, lb in labels
        AddNav(g, i, 88 + (i - 1) * 46, (IconFont != "") ? icons[i] : "", lb)
    UI["navBar"] := g.Add("Text", Format("x0 y95 w4 h26 Background{1}", TH["accent"]), "")
    UI["sideDot"] := AddTxt(g, "", Format("x20 y{1} w18 h24 +0x200", H0 - 62), "●", "s10 norm", TH["info"], TH["side"])
    UI["sideTxt"] := AddTxt(g, "", Format("x40 y{1} w{2} h24 +0x200", H0 - 62, SW - 50), "", "s9 norm", TH["sideText"], TH["side"])
    UI["sideVer"] := AddTxt(g, "", Format("x20 y{1} w{2} h20 +0x200", H0 - 36, SW - 30), T("ab_version", APP_VERSION) . (A_IsAdmin ? "  ·  " . Tr("admin_tag") : ""), "s8 norm", Mix(TH["sideText"], TH["side"], 0.45), TH["side"])

    ; ---- pages
    Loop 5
        PgCtrls.Push([])
    BuildStatusPage(g, PgCtrls[PG_STATUS])
    BuildKeysPage(g, PgCtrls[PG_KEYS])
    BuildMousePage(g, PgCtrls[PG_MOUSE])
    BuildOptionsPage(g, PgCtrls[PG_OPT])
    BuildAboutPage(g, PgCtrls[PG_ABOUT])

    LoadMouseIntoUI()
    LoadOptionsIntoUI()
    FillKeys()

    ; modern look for the list (dark scrollbars in dark mode)
    DllCall("uxtheme\SetWindowTheme", "Ptr", KeysLV.Hwnd, "Str", DarkNow ? "DarkMode_Explorer" : "Explorer", "Ptr", 0)

    try {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 20, "Int*", DarkNow ? 1 : 0, "Int", 4)   ; dark title bar
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 35, "Int*", BGR(TH["side"]), "Int", 4)   ; title bar color
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", g.Hwnd, "Int", 36, "Int*", 0xFFFFFF, "Int", 4)          ; title text
    }

    if !HoverHooked {
        OnMessage(0x200, OnMouseMove)      ; WM_MOUSEMOVE: hover colors for the flat buttons
        HoverHooked := true
    }
    g.OnEvent("Size", OnMainSize)
    g.OnEvent("Close", (*) => SetTimer(DestroyMain, -10))
    g.Show("w" W0 " h" H0 " Hide")
    BaseW := Px(W0), BaseH := Px(H0)
    try {
        g.GetClientPos(, , &BaseW, &BaseH)
    }
    MainBuilt := true
}

; Closing the window frees it completely (controls, bitmaps, GDI+): InputDood goes back to a few MB in the tray.
; It is built again the next time it is opened.
DestroyMain() {
    global MainGui, MainBuilt, PadHbm, GdipToken, HovCur
    if !IsObject(MainGui)
        return
    MainBuilt := false
    SetTimer(HoverPoll, 0)
    HovCur := 0
    try {
        MainGui.Destroy()
    }
    MainGui := ""
    Hov.Clear()
    FS.Clear()
    UI.Clear()
    if (PadHbm != 0) {
        DllCall("DeleteObject", "Ptr", PadHbm)
        PadHbm := 0
    }
    if (GdipToken != 0) {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", GdipToken)
        GdipToken := 0
    }
    SetTimer(TrimMemory, -500)
}

; Asks Windows to take back the memory this process isn't using right now (what Task Manager shows drops a lot)
TrimMemory() {
    if MainBuilt
        return
    try DllCall("psapi\EmptyWorkingSet", "Ptr", DllCall("GetCurrentProcess", "Ptr"))
}

; Rebuilds the window with the current theme (Windows switched between light and dark)
RebuildMain() {
    global MainGui, MainBuilt
    if !IsObject(MainGui)
        return
    wasVisible := DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
    page := CurPage
    MainBuilt := false
    try {
        MainGui.Destroy()
    }
    MainGui := ""
    BuildMain()
    ShowPage(page)
    UpdateState()
    if wasVisible {
        MainGui.Show()
        UpdateLive(lastMaskAll)
    }
}

OnDpiChanged(wParam, lParam, msg, hwnd) {
    if (IsObject(MainGui) && MainBuilt && hwnd = MainGui.Hwnd)
        SetTimer(RebuildMain, -400)
}

OnSettingChange(wParam, lParam, msg, hwnd) {
    ; Windows changed its theme: if we follow it, rebuild the window
    if (THEME_PREF = "auto" && IsObject(MainGui) && MainBuilt && (IsDark() != DarkNow))
        SetTimer(RebuildMain, -300)
}

AddNav(g, i, y, icon, label) {
    bg := TH["side"]
    fnt := (IconFont != "") ? IconFont : "Segoe UI"
    strip := g.Add("Text", Format("x8 y{1} w{2} h40 +0x100 Background{3}", y, SW - 16, bg), "")
    g.SetFont("s12 norm c" TH["sideText"], fnt)
    ico := g.Add("Text", Format("x20 y{1} w32 h40 +0x100 +0x200 Center Background{2}", y, bg), icon)
    FS[ico.Hwnd] := ["s12 norm", fnt]
    lbl := AddTxt(g, "", Format("x58 y{1} w{2} h40 +0x100 +0x200", y, SW - 70), label, "s10 norm", TH["sideText"], bg)
    ctrls := [strip, ico, lbl]
    info := Map("ctrls", ctrls, "bg", bg, "hv", TH["sideHov"], "kind", "nav")
    for c in info["ctrls"] {
        Hov[c.Hwnd] := info
        c.OnEvent("Click", NavClick.Bind(i))
    }
    Nav.Push(Map("ico", ico, "lbl", lbl, "info", info))
}

NavClick(i, *) {
    ShowPage(i)
}

SetNav(sel) {
    for i, n in Nav {
        on := (i = sel)
        bg := on ? TH["sideSel"] : TH["side"]
        n["info"]["bg"] := bg
        n["info"]["hv"] := on ? TH["sideSel"] : TH["sideHov"]
        for c in n["info"]["ctrls"]
            c.Opt("Background" bg)
        Recolor(n["ico"], on ? TH["accentHov"] : TH["sideText"])
        Recolor(n["lbl"], on ? "FFFFFF" : TH["sideText"])
        for c in n["info"]["ctrls"]
            c.Redraw()
    }
    try {
        Nav[sel]["info"]["ctrls"][1].GetPos(, &sy, , &sh)
        UI["navBar"].GetPos(, , , &bh)
        UI["navBar"].Move(, sy + (sh - bh) // 2)
    }
}

ShowPage(i) {
    global CurPage
    CurPage := i
    for idx, arr in PgCtrls {
        for c in arr
            c.Visible := (idx = i)
    }
    SetNav(i)
    UpdateState()
    if (i = PG_STATUS)
        UpdateLive(lastMaskAll)
    if (i = PG_KEYS)
        FillKeys()
}

; Window resized: stretch / move what depends on the size (values are raw pixels)
OnMainSize(g, minMax, w, h) {
    if (minMax = -1 || !MainBuilt)
        return
    dw := w - BaseW            ; how much bigger than when it was built (raw pixels)
    dh := h - BaseH
    UI["side"].Move(, , , h)
    UI["sideDot"].Move(, Px(H0 - 62) + dh)
    UI["sideTxt"].Move(, Px(H0 - 62) + dh)
    UI["sideVer"].Move(, Px(H0 - 36) + dh)
    ; status
    UI["banner"].Move(, , Px(CW0) + dw)
    UI["bBtn1"].Move(Px(CX + CW0 - 196) + dw)
    UI["bBtn2"].Move(Px(CX + CW0 - 196) + dw)
    UI["bTitle"].Move(, , Px(CW0 - 118 - 220) + dw)
    UI["bSub"].Move(, , Px(CW0 - 120 - 220) + dw)
    UI["liveCard"].Move(, , Px(CW0) + dw)
    UI["liveHint"].Move(, , Px(CW0 - 32) + dw)
    UI["live"].Move(, , Px(CW0 - 32) + dw)
    DrawPad()
    ; shortcuts
    KeysLV.Move(, , Px(CW0 + 28) + dw, Px(H0 - 188 - 16) + dh)
    UI["kLine"].Move(, , Px(CW0 + 28) + dw)
    LayoutKeys(Px(CW0 + 28) + dw)
}

; ---------------------------------------------------------- Page: Status -----
BuildStatusPage(g, arr) {
    x := CX
    w := CW0
    ; banner: its color follows the state (blue = Mouse Mode on, green = ready, amber = no controller)
    UI["banner"] := g.Add("Text", Format("x{1} y24 w{2} h120 Background{3}", x, w, BannerCol), "")
    arr.Push(UI["banner"])
    bico := PicPath()
    if (bico != "") {
        try {
            arr.Push(g.Add("Picture", Format("x{1} y44 w80 h80 BackgroundTrans", x + 20), bico))
        }
    }
    UI["bTitle"] := AddTxt(g, arr, Format("x{1} y34 w{2} h36 +0x200", x + 118, w - 118 - 220), "", "s17 bold", "FFFFFF", BannerCol)
    UI["bSub"] := AddTxt(g, arr, Format("x{1} y74 w{2} h62", x + 120, w - 120 - 220), "", "s9 norm", "FFFFFF", BannerCol)
    UI["bBtn1"] := AddBtn(g, arr, x + w - 196, 36, 184, 38, T("btn_mouse_on"), (*) => ToggleMouseMode(), "ban", "s10 bold")
    UI["bBtn2"] := AddBtn(g, arr, x + w - 196, 86, 184, 32, T("btn_edit_keys"), BBtn2Click, "ban2")

    ; controller test: drawing of the pad that lights up what you press (GDI+, see DrawPad)
    AddTxt(g, arr, Format("x{1} y164 w{2} h24 +0x200", x, w), T("st_live_title"), "s11 bold", TH["text"], TH["bg"])
    UI["liveCard"] := g.Add("Text", Format("x{1} y196 w{2} h400 Background{3}", x, w, TH["card"]), "")
    arr.Push(UI["liveCard"])
    UI["pad"] := g.Add("Picture", Format("x{1} y204 w{2} h{3} 0xE", x + 12, PAD_W, PAD_H))
    arr.Push(UI["pad"])
    UI["liveHint"] := AddTxt(g, arr, Format("x{1} y528 w{2} h18 +0x200 +0x1", x + 16, w - 32), T("st_live_hint"), "s9 norm", TH["sub"], TH["card"])
    UI["live"] := AddTxt(g, arr, Format("x{1} y548 w{2} h40 +0x200 +0x1", x + 16, w - 32), T("st_live_none"), "s16 bold", TH["accent"], TH["card"])
}

BBtn2Click(*) {
    if (adminBlocked && !A_IsAdmin)
        RestartElevated()
    else
        ShowPage(PG_KEYS)
}

; Colors the banner (and the button that sits on it)
SetBannerColor(col) {
    global BannerCol
    BannerCol := col
    UI["banner"].Opt("Background" col)
    UI["bTitle"].Opt("Background" col)
    UI["bSub"].Opt("Background" col)
    SetBtnKind(UI["bBtn2"], "ban2")
    UI["banner"].Redraw()
    UI["bTitle"].Redraw()
    UI["bSub"].Redraw()
}

; Everything that shows the app state: tray tooltip, banner, sidebar footer
UpdateState() {
    UpdateTray()
    UpdateStatus()
}

UpdateStatus() {
    if (!MainBuilt || !IsObject(MainGui))
        return
    if (ctrlCount = 0) {
        SetBannerColor(TH["bn_warn"])
        UI["bTitle"].Text := T("st_nopad")
        UI["bSub"].Text := T("st_nopad_sub")
    } else if (adminBlocked && !A_IsAdmin) {
        SetBannerColor(TH["bn_warn"])
        UI["bTitle"].Text := T("st_admin_block")
        UI["bSub"].Text := T("st_admin_block_sub")
    } else if mouseModeActive {
        SetBannerColor(TH["bn_sync"])
        UI["bTitle"].Text := T("st_mouse_on")
        UI["bSub"].Text := T("st_mouse_on_sub")
    } else {
        SetBannerColor(TH["bn_ok"])
        UI["bTitle"].Text := T("st_ready")
        UI["bSub"].Text := T("st_ready_sub", ctrlCount)
    }
    UI["bBtn1"].Text := mouseModeActive ? T("btn_mouse_off") : T("btn_mouse_on")
    UI["bBtn2"].Text := (adminBlocked && !A_IsAdmin) ? T("btn_restart_admin") : T("btn_edit_keys")

    Recolor(UI["sideDot"], (ctrlCount > 0) ? TH["ok"] : TH["warn"])
    if (ctrlCount = 0)
        UI["sideTxt"].Text := T("side_pads_none")
    else if (ctrlCount = 1)
        UI["sideTxt"].Text := T("side_pads_one")
    else
        UI["sideTxt"].Text := T("side_pads_many", ctrlCount)
}

; Called when the held buttons / sticks change: updates the text and redraws the pad
UpdateLive(mask) {
    if (!MainBuilt || CurPage != PG_STATUS || !UI.Has("live"))
        return
    try {
        if !DllCall("IsWindowVisible", "Ptr", MainGui.Hwnd)
            return
        UI["live"].Text := (mask = 0) ? T("st_live_none") : MaskToLabel(mask)
        DrawPad()
    }
}

; ---- Controller drawing (GDI+). The picture is rendered only when something changes. ----
Argb(hex) {
    return 0xFF000000 | Integer("0x" . hex)
}

GdipStart() {
    global GdipToken
    if (GdipToken != 0)
        return true
    if !DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")
        DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si, 0)
    tok := 0
    if (DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok, "Ptr", si, "Ptr", 0, "UInt") != 0)
        return false
    GdipToken := tok
    return true
}

GFill(kind, x, y, w, h, hex) {
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", Argb(hex), "Ptr*", &br)
    if (kind = "e")
        DllCall("gdiplus\GdipFillEllipse", "Ptr", PadG, "Ptr", br, "Float", x, "Float", y, "Float", w, "Float", h)
    else
        DllCall("gdiplus\GdipFillRectangle", "Ptr", PadG, "Ptr", br, "Float", x, "Float", y, "Float", w, "Float", h)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
}

; Rectangle with rounded corners (radius r)
GRound(x, y, w, h, r, hex) {
    p := 0
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &p)
    d := r * 2
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", p, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", p)
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", Argb(hex), "Ptr*", &br)
    DllCall("gdiplus\GdipFillPath", "Ptr", PadG, "Ptr", br, "Ptr", p)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeletePath", "Ptr", p)
}

; Text centered in a rectangle (size in design pixels)
GText(txt, x, y, w, h, size, hex) {
    fnt := 0
    DllCall("gdiplus\GdipCreateFont", "Ptr", PadFam, "Float", size, "Int", 1, "Int", 2, "Ptr*", &fnt)
    br := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", Argb(hex), "Ptr*", &br)
    rc := Buffer(16, 0)
    NumPut("Float", x, "Float", y, "Float", w, "Float", h, rc)
    DllCall("gdiplus\GdipDrawString", "Ptr", PadG, "WStr", txt, "Int", -1, "Ptr", fnt, "Ptr", rc, "Ptr", PadFmt, "Ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
    DllCall("gdiplus\GdipDeleteFont", "Ptr", fnt)
}

; Draws the controller with the current buttons / sticks lit up (coordinates in a 700 x 320 space)
DrawPadShapes() {
    m := lastMaskAll
    body := TH["border"]
    off := Mix(body, TH["text"], 0.20)
    well := Mix(body, TH["card"], 0.50)
    on := TH["accent"]
    mid := Mix(off, on, 0.55)
    lbl := TH["sub"]

    ; body
    GFill("e", 95, 60, 510, 190, body)
    GFill("e", 70, 140, 175, 170, body)
    GFill("e", 455, 140, 175, 170, body)

    ; triggers (fill follows how far they are pulled) and bumpers
    for t in [[150, padLT, "LT"], [486, padRT, "RT"]] {
        GFill("r", t[1], 4, 64, 28, well)
        fh := 28 * t[2] / 255
        if (fh > 0)
            GFill("r", t[1], 32 - fh, 64, fh, on)
        GText(t[3], t[1], 4, 64, 28, 13, (t[2] > 0) ? "FFFFFF" : lbl)
    }
    GRound(120, 38, 120, 24, 11, (m & XI_LB) ? on : off)
    GText("LB", 120, 38, 120, 24, 13, (m & XI_LB) ? "FFFFFF" : lbl)
    GRound(460, 38, 120, 24, 11, (m & XI_RB) ? on : off)
    GText("RB", 460, 38, 120, 24, 13, (m & XI_RB) ? "FFFFFF" : lbl)

    ; sticks: the thumb moves with the stick, and lights up when pushed or clicked
    for st in [[215, 120, padLX, padLY, XI_L3], [430, 195, padRX, padRY, XI_R3]] {
        sx := st[1], sy := st[2]
        GFill("e", sx - 36, sy - 36, 72, 72, well)
        tx := st[3] / 32768 * 14
        ty := -st[4] / 32768 * 14
        defl := Sqrt(st[3] ** 2 + st[4] ** 2) / 32768
        col := (m & st[5]) ? on : ((defl > STICK_DEADZONE_PCT / 100) ? mid : off)
        GFill("e", sx + tx - 24, sy + ty - 24, 48, 48, col)
    }

    ; d-pad
    dx := 270, dy := 195
    GFill("r", dx - 13, dy - 13, 26, 26, off)
    GRound(dx - 13, dy - 44, 26, 34, 5, (m & XI_DPAD_UP) ? on : off)
    GRound(dx - 13, dy + 10, 26, 34, 5, (m & XI_DPAD_DOWN) ? on : off)
    GRound(dx - 44, dy - 13, 34, 26, 5, (m & XI_DPAD_LEFT) ? on : off)
    GRound(dx + 10, dy - 13, 34, 26, 5, (m & XI_DPAD_RIGHT) ? on : off)

    ; A B X Y
    for f in [[485, 150, "A", XI_A, "1FA55A"], [515, 120, "B", XI_B, "D13B3B"], [455, 120, "X", XI_X, "2F6BEB"], [485, 90, "Y", XI_Y, "E0A81F"]] {
        pressed := (m & f[4]) != 0
        GFill("e", f[1] - 17, f[2] - 17, 34, 34, pressed ? f[5] : Mix(body, f[5], 0.35))
        GText(f[3], f[1] - 17, f[2] - 17, 34, 34, 16, pressed ? "FFFFFF" : lbl)
    }

    ; Guide, Back, Start
    GFill("e", 350 - 19, 100 - 19, 38, 38, (m & XI_GUIDE) ? on : off)
    GFill("e", 305 - 10, 125 - 10, 20, 20, (m & XI_BACK) ? on : off)
    GFill("e", 395 - 10, 125 - 10, 20, 20, (m & XI_START) ? on : off)
}

; Renders the controller into a bitmap (w x h in real pixels). Returns an HBITMAP, 0 if GDI+ failed.
RenderPad(w, h, sc) {
    global PadG, PadFam, PadFmt
    if !GdipStart()
        return 0
    bmp := 0
    if (DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp) != 0)
        return 0
    g := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g)
    PadG := g
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", Argb(TH["card"]))
    DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", g, "Float", sc, "Float", sc, "Int", 0)
    fam := 0
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
    fmt := 0
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &fmt)
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", 1)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
    PadFam := fam
    PadFmt := fmt
    try {
        DrawPadShapes()
    }
    DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
    DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    hbm := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm, "UInt", Argb(TH["card"]))
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    return hbm
}

; Draws the controller scaled to the free space of the card and centered in it (above the hint text)
DrawPad() {
    global PadHbm
    if (!MainBuilt || CurPage != PG_STATUS || !UI.Has("pad"))
        return
    try {
        if (WinGetMinMax("ahk_id " . MainGui.Hwnd) = -1)
            return
        UI["liveCard"].GetPos(&cx0, &cy0, &cw0, &ch0)
        UI["liveHint"].GetPos(, &hy0)
        availW := cw0 - Px(24)
        availH := hy0 - cy0 - Px(12)
        sc := Min(availW / PAD_W, availH / PAD_H)
        sc := Max(sc, Dpi * 0.5)
        pw := Round(PAD_W * sc)
        ph := Round(PAD_H * sc)
        hbm := RenderPad(pw, ph, sc)
        if (hbm = 0)
            return
        old := SendMessage(0x172, 0, hbm, UI["pad"].Hwnd)     ; STM_SETIMAGE, IMAGE_BITMAP
        if (old != 0)
            DllCall("DeleteObject", "Ptr", old)
        PadHbm := hbm
        UI["pad"].Move(cx0 + (cw0 - pw) // 2, cy0 + (hy0 - cy0 - ph) // 2, pw, ph)
        UI["pad"].Redraw()
    }
}

; -------------------------------------------------------- Page: Shortcuts -----
BuildKeysPage(g, arr) {
    global KeysLV
    AddTxt(g, arr, Format("x{1} y22 w{2} h40 +0x200", CX, CW0), T("tab_keys"), "s18 bold", TH["text"], TH["bg"])
    AddTxt(g, arr, Format("x{1} y68 w{2} h44", CX, CW0), T("k_intro"), "s9 norm", TH["sub"], TH["bg"])
    bx := CX
    for it in [[T("k_add"), AddBindingUI, 120, "prim"], [T("k_edit"), EditSelectedBindingUI, 110, "norm"], [T("k_remove"), RemoveBindingUI, 110, "norm"], [T("k_reset"), ResetBindingsUI, 210, "norm"]] {
        AddBtn(g, arr, bx, 118, it[3], 32, it[1], it[2], it[4])
        bx += it[3] + 8
    }
    UI["kCols"] := []
    for lb in [T("k_col_when"), T("k_col_input"), T("k_col_action")]
        UI["kCols"].Push(AddTxt(g, arr, Format("x{1} y162 w100 h20 +0x200", CX), lb, "s9 bold", TH["sub"], TH["bg"]))
    UI["kLine"] := g.Add("Text", Format("x{1} y184 w{2} h1 Background{3}", CX, CW0 + 28, TH["border"]), "")
    arr.Push(UI["kLine"])
    g.SetFont("s9 norm c" TH["text"], "Segoe UI")
    KeysLV := g.Add("ListView", Format("x{1} y188 w{2} h{3} -Hdr -Multi +LV0x10000 -E0x200 c{4} Background{5}"
        , CX, CW0 + 28, H0 - 188 - 16, TH["text"], TH["lvBg"])
        , [T("k_col_when"), T("k_col_input"), T("k_col_action")])
    arr.Push(KeysLV)
    KeysLV.OnEvent("DoubleClick", (*) => EditSelectedBindingUI())
    LayoutKeys(Px(CW0 + 28))
}

LayoutKeys(wRaw) {
    wd := wRaw / Dpi
    cols := [150, 250, 0]
    cols[3] := Max(200, wd - 150 - 250 - 24)
    x := 0
    for i, cw in cols {
        KeysLV.ModifyCol(i, Px(cw))
        UI["kCols"][i].Move(Px(CX) + Px(x) + Px(6), , Px(cw) - Px(8))
        x += cw
    }
}

FillKeys() {
    if !IsObject(KeysLV)
        return
    KeysLV.Delete()
    for b in Bindings
        KeysLV.Add("", T((b["scope"] = "always") ? "scope_always" : "scope_mouse"), MaskToLabel(b["mask"]), ActionLabel(b))
}

; Row selected in the list (0 + a notice if none)
SelectedBindingIndex() {
    row := KeysLV.GetNext(0)
    if (row = 0 || row > Bindings.Length) {
        MsgBox(T("k_nosel"), "InputDood", "Iconi")
        return 0
    }
    return row
}

AddBindingUI(*) {
    EditBindingUI(0)
}

EditSelectedBindingUI(*) {
    i := SelectedBindingIndex()
    if (i > 0)
        EditBindingUI(i)
}

RemoveBindingUI(*) {
    i := SelectedBindingIndex()
    if (i = 0)
        return
    list := Bindings.Clone()
    list.RemoveAt(i)
    ApplyBindings(list)
}

ResetBindingsUI(*) {
    if (MsgBox(T("k_reset_confirm"), "InputDood", "YesNo Icon?") != "Yes")
        return
    ApplyBindings(DefaultBindings())
}

; Makes a new shortcut list the active one and refreshes the lists
ApplyBindings(list) {
    CommitBindings(list)
    FillKeys()
}

; ------------------------------------------------------ Shortcut editor -----
; Small window (modal over the main one) to add or edit a shortcut.
EditBindingUI(idx) {
    if (ED.Has("gui") && IsObject(ED["gui"]))
        return
    cur := (idx > 0) ? Bindings[idx] : ""
    dlg := Gui("+Owner" MainGui.Hwnd " -MinimizeBox -MaximizeBox", T((idx > 0) ? "ed_title_edit" : "ed_title_add"))
    dlg.BackColor := TH["bg"]
    dlg.MarginX := 0
    dlg.MarginY := 0
    dlg.SetFont("s9 norm c" TH["text"], "Segoe UI")
    ED["gui"] := dlg
    ED["idx"] := idx
    ED["prev"] := ""
    x := 24

    AddTxt(dlg, "", Format("x{1} y16 w500 h22 +0x200", x), T("ed_input"), "s9 bold", TH["sub"], TH["bg"])
    ED["combo"] := AddEdit(dlg, "", x, 42, 300, IsObject(cur) ? MaskToIni(cur["mask"]) : "")
    ED["capBtn"] := AddBtn(dlg, "", x + 312, 40, 200, 30, T("ed_capture"), EdCapture, "prim")
    AddTxt(dlg, "", Format("x{1} y80 w512 h40", x), T("ed_hint"), "s8 norm", TH["sub"], TH["bg"])

    AddTxt(dlg, "", Format("x{1} y128 w500 h22 +0x200", x), T("ed_when"), "s9 bold", TH["sub"], TH["bg"])
    ED["scope"] := AddSeg(dlg, "", x, 154, [T("scope_always"), T("scope_mouse")], (IsObject(cur) && cur["scope"] = "mouse") ? 2 : 1, 170)

    AddTxt(dlg, "", Format("x{1} y196 w500 h22 +0x200", x), T("ed_action"), "s9 bold", TH["sub"], TH["bg"])
    dlg.SetFont("s9 norm c" TH["text"], "Segoe UI")
    lv := dlg.Add("ListView", Format("x{1} y222 w512 h190 -Hdr -Multi +LV0x10000 -E0x200 c{2} Background{3}", x, TH["text"], TH["lvBg"]), ["Action"])
    ED["lv"] := lv
    sel := 0
    for i, id in ACTION_IDS {
        lv.Add("", Tr("act_" id))
        if (IsObject(cur) && cur["act"] = id)
            sel := i
    }
    lv.ModifyCol(1, Px(486))
    DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", DarkNow ? "DarkMode_Explorer" : "Explorer", "Ptr", 0)

    AddTxt(dlg, "", Format("x{1} y426 w500 h22 +0x200", x), T("ed_param"), "s9 bold", TH["sub"], TH["bg"])
    ED["param"] := AddEdit(dlg, "", x, 452, 300, IsObject(cur) ? cur["param"] : "")
    AddTxt(dlg, "", Format("x{1} y452 w200 h26 +0x200", x + 312), T("ed_param_hint"), "s8 norm", TH["sub"], TH["bg"])

    AddBtn(dlg, "", x, 500, 150, 36, T("ed_ok"), EdOk, "prim", "s9 bold")
    AddBtn(dlg, "", x + 158, 500, 130, 36, T("ed_cancel"), EdClose)

    lv.OnEvent("ItemSelect", (*) => EdUpdateParam())
    dlg.OnEvent("Close", EdClose)
    dlg.OnEvent("Escape", EdClose)
    if (sel > 0)
        lv.Modify(sel, "Select Focus Vis")
    EdUpdateParam()
    try {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", dlg.Hwnd, "Int", 20, "Int*", DarkNow ? 1 : 0, "Int", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", dlg.Hwnd, "Int", 35, "Int*", BGR(TH["side"]), "Int", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", dlg.Hwnd, "Int", 36, "Int*", 0xFFFFFF, "Int", 4)
    }
    MainGui.Opt("+Disabled")
    dlg.Show("w560 h556")
}

; The "key or text" box is only used by the two "custom" actions
EdUpdateParam() {
    if !ED.Has("lv")
        return
    row := ED["lv"].GetNext(0)
    isCustom := false
    if (row > 0 && row <= ACTION_IDS.Length)
        isCustom := (ACTION_IDS[row] = "custom_tap" || ACTION_IDS[row] = "custom_hold")
    ED["param"].Enabled := isCustom
}

EdCapture(*) {
    if !ED.Has("gui")
        return
    if captureActive {
        CaptureCancel()
        ED["capBtn"].Text := T("ed_capture")
        ED["combo"].Value := ED["prev"]
        return
    }
    ED["prev"] := ED["combo"].Value
    ED["capBtn"].Text := T("ed_capturing")
    ED["combo"].Value := T("ed_press")
    CaptureStart(EdCaptureDone, EdCaptureLive)
}

EdCaptureLive(mask) {
    if ED.Has("combo")
        ED["combo"].Value := MaskToIni(mask)
}

; mask = 0 means it timed out
EdCaptureDone(mask) {
    if !ED.Has("gui")
        return
    ED["capBtn"].Text := T("ed_capture")
    if (mask != 0)
        ED["combo"].Value := MaskToIni(mask)
    else
        ED["combo"].Value := ED["prev"]
}

EdOk(*) {
    if !ED.Has("gui")
        return
    mask := TextToMask(ED["combo"].Value)
    if (mask = 0) {
        MsgBox(T("ed_bad_combo"), "InputDood", "Iconx")
        return
    }
    row := ED["lv"].GetNext(0)
    if (row = 0) {
        MsgBox(T("ed_pick_action"), "InputDood", "Iconx")
        return
    }
    id := ACTION_IDS[row]
    param := Trim(ED["param"].Value)
    isCustom := (id = "custom_tap" || id = "custom_hold")
    if (isCustom && param = "") {
        MsgBox(T("ed_need_param"), "InputDood", "Iconx")
        return
    }
    scope := (ED["scope"]["sel"] = 1) ? "always" : "mouse"
    b := MakeBinding(scope, mask, isCustom ? id ":" param : id)
    if !IsObject(b)
        return

    idx := ED["idx"]
    dupAt := 0
    for k, ob in Bindings {
        if (k != idx && ob["scope"] = scope && ob["mask"] = mask) {
            if (MsgBox(T("ed_dup"), "InputDood", "YesNo Icon?") != "Yes")
                return
            dupAt := k
            break
        }
    }
    list := Bindings.Clone()
    if (dupAt > 0) {
        list.RemoveAt(dupAt)
        if (idx > dupAt)
            idx -= 1
    }
    if (idx > 0)
        list[idx] := b
    else
        list.Push(b)
    ApplyBindings(list)
    EdClose()
}

EdClose(*) {
    CaptureCancel()
    try MainGui.Opt("-Disabled")
    try ED["gui"].Destroy()
    ED.Clear()
    try WinActivate("ahk_id " MainGui.Hwnd)
}

; --------------------------------------------------------- Page: Mouse mode -----
BuildMousePage(g, arr) {
    AddTxt(g, arr, Format("x{1} y22 w{2} h40 +0x200", CX, CW0), T("tab_mouse"), "s18 bold", TH["text"], TH["bg"])
    AddTxt(g, arr, Format("x{1} y68 w{2} h44", CX, CW0), T("m_intro"), "s9 norm", TH["sub"], TH["bg"])
    lx := CX
    vx := CX + 380
    y := 128
    Lbl := (txt) => AddTxt(g, arr, Format("x{1} y{2} w366 h28 +0x200", lx, y), txt, "s9 norm", TH["text"], TH["bg"])

    Lbl(T("m_speed"))
    OptC["speed"] := AddEdit(g, arr, vx, y, 80, "", "Number")
    y += 44
    Lbl(T("m_curve"))
    OptC["curve"] := AddSeg(g, arr, vx, y, [T("curve_linear"), T("curve_precise"), T("curve_sensitive")], 1, 104)
    y += 44
    Lbl(T("m_dead"))
    OptC["dead"] := AddEdit(g, arr, vx, y, 80, "", "Number")
    y += 44
    Lbl(T("m_trigger"))
    OptC["trig"] := AddEdit(g, arr, vx, y, 80, "", "Number")
    y += 44
    Lbl(T("m_scroll_delay"))
    OptC["sdelay"] := AddEdit(g, arr, vx, y, 80, "", "Number")
    y += 44
    Lbl(T("m_scroll_rate"))
    OptC["srate"] := AddEdit(g, arr, vx, y, 80, "", "Number")
    y += 44
    Lbl(T("m_indicator"))
    OptC["ind"] := AddSeg(g, arr, vx, y, [T("ind_window"), T("ind_beep"), T("ind_none")], 1, 104)
    y += 52
    OptC["fsafe"] := AddToggle(g, arr, lx, y, CW0, T("m_fsafe"), true)
    y += 56
    AddBtn(g, arr, lx, y, 190, 36, T("m_save"), SaveMouse, "prim", "s9 bold")
    AddBtn(g, arr, lx + 198, y, 190, 36, T("m_defaults"), MouseDefaults)
    UI["mSaved"] := AddTxt(g, arr, Format("x{1} y{2} w200 h36 +0x200", lx + 406, y), "", "s9 bold", TH["ok"], TH["bg"])
}

LoadMouseIntoUI() {
    OptC["speed"].Value := CURSOR_MAX_SPEED
    SegClick(OptC["curve"], (CURVE_NAME = "precise") ? 2 : ((CURVE_NAME = "sensitive") ? 3 : 1))
    OptC["dead"].Value := STICK_DEADZONE_PCT
    OptC["trig"].Value := TRIGGER_PCT
    OptC["sdelay"].Value := WHEEL_REPEAT_DELAY_MS
    OptC["srate"].Value := WHEEL_REPEAT_MS
    SegClick(OptC["ind"], (INDICATOR_MODE = "beep") ? 2 : ((INDICATOR_MODE = "none") ? 3 : 1))
    SetToggle(OptC["fsafe"], FULLSCREEN_SAFE_MODE)
}

; Puts the original values in the boxes (it is saved when you press Save)
MouseDefaults(*) {
    OptC["speed"].Value := 32
    SegClick(OptC["curve"], 1)
    OptC["dead"].Value := 24
    OptC["trig"].Value := 39
    OptC["sdelay"].Value := 350
    OptC["srate"].Value := 60
    SegClick(OptC["ind"], 1)
    SetToggle(OptC["fsafe"], true)
}

SaveMouse(*) {
    sp := Trim(OptC["speed"].Value)
    dz := Trim(OptC["dead"].Value)
    tg := Trim(OptC["trig"].Value)
    sd := Trim(OptC["sdelay"].Value)
    sr := Trim(OptC["srate"].Value)
    if !(IsInteger(sp) && sp >= 1 && sp <= 100 && IsInteger(dz) && dz >= 5 && dz <= 40 && IsInteger(tg) && tg >= 10 && tg <= 90 && IsInteger(sd) && sd >= 50 && sd <= 2000 && IsInteger(sr) && sr >= 10 && sr <= 500) {
        MsgBox(T("m_invalid"), "InputDood", "Iconx")
        return
    }
    IniWrite(Integer(sp), IniFile, "mouse", "cursorSpeed")
    IniWrite(["linear", "precise", "sensitive"][OptC["curve"]["sel"]], IniFile, "mouse", "curve")
    IniWrite(Integer(dz), IniFile, "mouse", "deadzonePct")
    IniWrite(Integer(tg), IniFile, "mouse", "triggerPct")
    IniWrite(Integer(sd), IniFile, "mouse", "scrollDelayMs")
    IniWrite(Integer(sr), IniFile, "mouse", "scrollRateMs")
    IniWrite(["window", "beep", "none"][OptC["ind"]["sel"]], IniFile, "mouse", "indicator")
    IniWrite(OptC["fsafe"]["on"] ? "1" : "0", IniFile, "general", "fullscreenSafe")
    LoadSettings()
    ShowSaved("mSaved")
}

; ----------------------------------------------------------- Page: Options -----
BuildOptionsPage(g, arr) {
    AddTxt(g, arr, Format("x{1} y22 w{2} h40 +0x200", CX, CW0), T("tab_options"), "s18 bold", TH["text"], TH["bg"])
    lx := CX
    vx := CX + 380
    y := 84
    Lbl := (txt) => AddTxt(g, arr, Format("x{1} y{2} w366 h28 +0x200", lx, y), txt, "s9 norm", TH["text"], TH["bg"])

    Lbl(T("o_language"))
    OptC["lang"] := AddSeg(g, arr, vx, y, [T("seg_auto"), "English", "Español"], 1, 104)
    y += 44
    Lbl(T("o_theme"))
    OptC["theme"] := AddSeg(g, arr, vx, y, [T("seg_auto"), T("th_light"), T("th_dark")], 1, 104)
    y += 44
    Lbl(T("o_grace"))
    OptC["grace"] := AddEdit(g, arr, vx, y, 80, "", "Number")
    y += 52
    OptC["startup"] := AddToggle(g, arr, lx, y, CW0, T("o_startup"), false)
    y += 38
    OptC["checkupd"] := AddToggle(g, arr, lx, y, CW0, T("o_checkupd"), true)
    y += 38
    OptC["adm"] := AddToggle(g, arr, lx, y, CW0, T("o_admin"), false)
    y += 38
    OptC["admst"] := AddToggle(g, arr, lx, y, CW0, T("o_admin_startup"), false)
    y += 40
    AddTxt(g, arr, Format("x{1} y{2} w{3} h40", lx + 32, y, CW0 - 32), T("o_admin_note"), "s8 norm", TH["sub"], TH["bg"])
    y += 50
    AddBtn(g, arr, lx, y, 190, 36, T("o_save"), SaveOptions, "prim", "s9 bold")
    AddBtn(g, arr, lx + 198, y, 190, 36, T("o_open_ini"), (*) => OpenConfigFile())
    AddBtn(g, arr, lx + 396, y, 190, 36, T("o_open_folder"), (*) => OpenConfigFolder())
    UI["oSaved"] := AddTxt(g, arr, Format("x{1} y{2} w200 h28 +0x200", lx, y + 46), "", "s9 bold", TH["ok"], TH["bg"])
}

LoadOptionsIntoUI() {
    SegClick(OptC["lang"], (LANG_PREF = "en") ? 2 : ((LANG_PREF = "es") ? 3 : 1))
    SegClick(OptC["theme"], (THEME_PREF = "light") ? 2 : ((THEME_PREF = "dark") ? 3 : 1))
    OptC["grace"].Value := FORCE_KILL_GRACE_SEC
    SetToggle(OptC["startup"], IsStartupEnabled() || ADMIN_STARTUP)
    SetToggle(OptC["adm"], ADMIN_MODE)
    SetToggle(OptC["admst"], ADMIN_STARTUP)
    SetToggle(OptC["checkupd"], CHECK_UPDATES)
}

SaveOptions(*) {
    gr := Trim(OptC["grace"].Value)
    if !(IsInteger(gr) && gr >= 0 && gr <= 30) {
        MsgBox(T("o_invalid"), "InputDood", "Iconx")
        return
    }
    oldLang := LANG_PREF
    oldTheme := THEME_PREF
    newLang := ["auto", "en", "es"][OptC["lang"]["sel"]]
    newTheme := ["auto", "light", "dark"][OptC["theme"]["sel"]]
    IniWrite(newLang, IniFile, "general", "language")
    IniWrite(newTheme, IniFile, "general", "theme")
    IniWrite(Integer(gr), IniFile, "general", "forceKillGraceSec")
    IniWrite(OptC["checkupd"]["on"] ? "1" : "0", IniFile, "general", "checkUpdates")

    ; administrator mode: tasks are created / deleted in one elevated step (one confirmation)
    wantAdmin := OptC["adm"]["on"]
    wantElev := wantAdmin && OptC["admst"]["on"]
    if (wantAdmin != ADMIN_MODE || wantElev != ADMIN_STARTUP) {
        if !SetupAdminTasks(wantAdmin, wantElev) {
            MsgBox(T("o_admin_failed"), "InputDood", "Iconx")
            LoadSettings()
            LoadOptionsIntoUI()
            return
        }
        IniWrite(wantAdmin ? "1" : "0", IniFile, "general", "adminMode")
        IniWrite(wantElev ? "1" : "0", IniFile, "general", "adminStartup")
    }
    LoadSettings()
    ; start with Windows: an elevated start replaces the normal "Run" entry (never both)
    if ADMIN_STARTUP {
        try RegDelete(RUN_KEY, RUN_VALUE_NAME)
    } else if (OptC["startup"]["on"] != IsStartupEnabled()) {
        ToggleStartup()
    }
    RefreshStartupMenu()
    BuildTray()
    if (newLang != oldLang || newTheme != oldTheme) {
        RestartApp(PG_OPT)      ; texts and colors are built once: reopen the window to apply them
        return
    }
    ShowSaved("oSaved")
}

; Reloads InputDood and reopens the window on that page
RestartApp(page := 1) {
    IniWrite(page, IniFile, "general", "reopenUI")
    Reload()
}

OpenConfigFile() {
    if !FileExist(IniFile) {
        try FileAppend("", IniFile)
    }
    try Run('notepad.exe "' IniFile '"')
}

OpenConfigFolder() {
    try Run('explorer.exe "' AppDir '"')
}

; ------------------------------------------------------------ Page: About -----
BuildAboutPage(g, arr) {
    x := CX
    ico := PicPath()
    if (ico != "") {
        try {
            arr.Push(g.Add("Picture", Format("x{1} y34 w84 h84 BackgroundTrans", x), ico))
        }
    }
    AddTxt(g, arr, Format("x{1} y34 w500 h46 +0x200", x + 104), "InputDood", "s24 bold", TH["text"], TH["bg"])
    AddTxt(g, arr, Format("x{1} y82 w500 h26 +0x200", x + 106), T("ab_version", APP_VERSION), "s11 norm", TH["accent"], TH["bg"])
    AddTxt(g, arr, Format("x{1} y142 w{2} h66", x, CW0), T("ab_desc"), "s10 norm", TH["text"], TH["bg"])
    AddTxt(g, arr, Format("x{1} y216 w{2} h28 +0x200", x, CW0), T("ab_made", APP_AUTHOR), "s10 norm", TH["sub"], TH["bg"])
    AddBtn(g, arr, x, 262, 280, 38, T("ab_patreon"), (*) => Run(PATREON_URL), "prim", "s10 bold")
    AddBtn(g, arr, x + 290, 262, 280, 38, T("ab_github"), (*) => Run(GITHUB_URL), "norm", "s10 norm")
    AddBtn(g, arr, x, 312, 280, 34, T("ab_check"), (*) => CheckForUpdates(true))
    AddTxt(g, arr, Format("x{1} y366 w{2} h28 +0x200", x, CW0), T("ab_libs"), "s9 norm", TH["sub"], TH["bg"])
}


; ============================================================================
;  Startup (must stay at the end of the file: everything above is defined by now)
; ============================================================================
MigrateFromGSX()                 ; before the folder is created, so the old one can be moved
if !DirExist(AppDir)
    DirCreate(AppDir)
try FileInstall("icons\InputDood.png", LogoFile, 1)

LoadSettings()
LoadBindings()

XINPUT_DLL := "xinput1_4.dll"
hModule := DllCall("GetModuleHandle", "Str", XINPUT_DLL, "Ptr")
if !hModule
    hModule := DllCall("LoadLibrary", "Str", XINPUT_DLL, "Ptr")
if !hModule
    throw Error("Couldn't load " . XINPUT_DLL)
pGetStateEx := DllCall("GetProcAddress", "Ptr", hModule, "Ptr", 100, "Ptr")
if !pGetStateEx
    throw Error("Couldn't find XInputGetStateEx (ordinal 100) in " . XINPUT_DLL)

BuildTray()
FixStartupArg()
OnMessage(0x2E0, OnDpiChanged)       ; WM_DPICHANGED
OnMessage(0x1A, OnSettingChange)     ; WM_SETTINGCHANGE (Windows light / dark switch)
OnExit((*) => ReleaseAllHeld())      ; never leave a mouse button or key held down

SetTimer(CheckCombo, POLL_INTERVAL_IDLE_MS)
SetTimer(TrimMemory, 60000)          ; while the window is closed, keep the memory footprint small

CheckPostUpdateNotice()
if CHECK_UPDATES
    SetTimer(() => CheckForUpdates(false), -3000)

; Window: opened on a normal launch, kept hidden when Windows starts InputDood (/startup) or after an update
firstRun := ShowFirstRunWarning()
reopen := IniRead(IniFile, "general", "reopenUI", "0")
if IsInteger(reopen) && reopen > 0 {
    try IniDelete(IniFile, "general", "reopenUI")
    ShowMain(Integer(reopen))
} else if (firstRun || !(HasArg("/startup") || HasArg("/updated:"))) {
    ShowMain(0)
}

if !IsObject(MainGui)
    SetTimer(TrimMemory, -3000)

