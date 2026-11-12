# Changelog

🇬🇧 English | [🇲🇽 Español](CHANGELOG.es.md)

## 0.3

### Added
- **Visual interface** in the style of SyncDood: sidebar with *Status*, *Shortcuts*, *Mouse mode*, *Options* and *About* pages, flat buttons, light/dark theme that follows Windows (or forced), resizable window, English / Spanish.
- **Configurable shortcuts**: add, edit, remove and restore defaults; record the combination by pressing it on the controller; choose *Always* or *Mouse Mode only*; 27 actions including custom key / text. Buttons available: Guide, LB, RB, LT, RT, Start, Back, L3, R3, A, B, X, Y, D-pad and right-stick directions. When combinations overlap the longest one wins.
- Live *controller test* on the Status page.
- Settings are stored in `%AppData%\InputDood\config.ini` (cursor speed, curve, dead zone, trigger threshold, indicator mode, language, theme, grace time, shortcuts).
- New indicator mode: window / beeps / nothing.

### Changed
- The default shortcuts reproduce the previous behavior exactly.
- Left click on the tray icon opens the window. When Windows starts InputDood ("Run at startup") it stays in the tray without opening it (the startup entry now carries a `/startup` flag; older entries are upgraded automatically).
- Most constants that were at the top of the `.ahk` are now options in the window / `config.ini`.

## 0.2

### Fixed
- Toggling Mouse Mode (**Guide + Back**) while a fullscreen game was in the foreground (e.g. FIFA 17) made the game drop out of fullscreen and lose focus, because the "Mouse Mode ON/OFF" message is a topmost window.

### Changed
- InputDood now detects when the active window is fullscreen (covers the whole monitor and has no title bar).
  - **Mouse Mode indicator:** no window is drawn in that case; two rising beeps = ON, two falling beeps = OFF.
  - **On-screen keyboard (Y):** it won't open over a fullscreen window; three short low beeps are played instead. If the keyboard was already open it can still be closed normally.
- New `FULLSCREEN_SAFE_MODE` setting (default `true`) at the top of the `.ahk`; set it to `false` to turn the fullscreen detection off.
- README (EN/ES): new **Fullscreen & anti-cheat** section documenting these limitations, workarounds (fullscreen optimizations, borderless window) and the anti-cheat/antivirus risks; limitations list updated.
- Version bumped to 0.2 (`APP_VERSION` and exe metadata).

## 0.1

- Initial release: Guide + Start closes/kills the active window; Mouse Mode (Guide + Back) with on-screen indicator and custom on-screen keyboard; tray menu; auto-update check against GitHub releases.
