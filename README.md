# 🎮 InputDood — Guide + Start task killer & mouse mode for XInput controllers

🇬🇧 English | [🇲🇽 Español](README.es.md)

Ultra lightweight AutoHotkey v2 app with a small visual interface that runs in the background and, by default, sends **WinClose + WinKill** when you press **Guide** (Xbox/Home) **+ Start** at the same time on any XInput-compatible controller. ⚡

The main focus of the app is to be used in an HTPC setup from the couch for closing games that for some reason don't have an option to exit to desktop, but it can pretty much kill any program that is in focus.

On top of that, it also includes an optional **full mouse + keyboard mode** (toggled with **Guide + Back**) so you can control your whole PC from the couch without ever picking up a mouse or keyboard — including a built-in on-screen keyboard.

## ✨ Features

- 🎮 Detects the combo **on any XInput controller** (Xbox 360, One, Series, and most third-party/clone pads), no per-device button mapping needed.
- 🪟 **Visual interface (new in 0.3)** — a SyncDood-style window (sidebar, light/dark theme that follows Windows, flat buttons) with live controller status, shortcut editor, Mouse Mode settings and options. Open it from the tray icon.
- ⌨️ **Configurable shortcuts (new in 0.3)** — add, edit or remove any controller shortcut (single buttons or combinations, including triggers and right-stick directions) and pick what it does; press the buttons on your controller to record the combination.
- 👻 Stays in the background with a tray icon; when Windows starts it ("Run at startup") it doesn't open the window.
- 🪶 Very low CPU usage: optimized 100ms polling, with a cache of which controller slots are connected to skip unnecessary calls (0% usage in my Ryzen 5600x and only 4mb of RAM usage).
- 🖱️ **Full mouse & keyboard mode** — move the cursor, click, scroll, control media/volume, and even type using a built-in on-screen keyboard, all from the controller.
- 🟢 **On-screen "Mouse Mode ON/OFF" indicator** — a big, centered, auto-fading message every time you toggle Mouse Mode, so you always know its state at a glance from the couch. Doesn't depend on Windows notifications (which are unreliable for unsigned scripts/exes) since it's drawn by InputDood itself.
- ⌨️ **Custom on-screen keyboard** — draggable, positions itself above your cursor so it doesn't cover the field you're typing into, with letter/symbol layouts, a caps-lock-style shift key, visual press feedback on every key, and no dependency on Windows' own on-screen keyboard (which can be broken by debloat tools or blocked by UAC elevation on some setups).
- 🔄 **Auto-updates** — checks your GitHub releases in the background on startup (silently, no popups unless there's actually something new) and lets you check manually from the tray menu at any time.
- 🖱️ Tray menu icon (left or right click).
- ⚠️ Shows a requirements notice the first time it runs.

## 🧠 How it works

XInput doesn't expose the Guide button through its public API (`XInputGetState`) — Windows reserves it for its own UI. This script uses `XInputGetStateEx`, an undocumented but rock-solid function that's been stable for over a decade (also used by tools like x360ce and DS4Windows), which does include the Guide button bit in the button state bitmask.

On every timer tick, it queries the state of the 4 possible controller slots (0-3) via `DllCall` into `xinput1_4.dll`, and if the button bitmask matches `START | GUIDE`, it sends `WinClose + WinKill` with `Send()`.

Polling speeds up automatically (from 100ms to 16ms) whenever Mouse Mode is active, so cursor movement feels smooth, and slows back down when it's off to keep CPU usage minimal.

## 📋 Requirements

- 🤖 **[AutoHotkey v2](https://www.autohotkey.com/)** — only needed if you're running the `.ahk` script directly. If you use the compiled `.exe` from the Releases page, the AutoHotkey runtime is bundled in and you don't need to install anything else.
- 🪟 Windows 8 or later (uses `xinput1_4.dll`, included by default on the system).

Note: *[SuperF4](https://github.com/stefansundin/superf4) installed and running — only needed if you use the `InputDood with Super F4.ahk` variant (the old SuperF4-based version).*

## 📦 Installation

### Option A: Compiled executable
1. Download the `.exe` from [Releases](../../releases) (or compile it yourself, see below).
2. Run the executable. A tray icon (a red **I**) and the window will appear. 🎮
3. *(Optional)* Right click the tray icon and select "Run at startup" (or use the toggle in the *Options* page). 🚀

### Option B: From source
1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download `InputDood.ahk` from this repo (plus the `icons` folder next to it for the tray icon and the logo).
3. Run the script by double-clicking it, or compile it yourself with Ahk2Exe (right-click the `.ahk` → *Compile Script*; the icon in `icons\InputDood.ico` is applied automatically).

## ▶️ Usage

1. Run this script (or its `.exe`). The window opens; close it and InputDood keeps running in the tray. 🎮
2. With the window you want to close in the foreground, press **Guide + Start** on your controller. 💥
3. Press **Guide + Back** to toggle Mouse Mode on/off and take full control of your PC from the couch (see the table below).
4. Want different buttons? Open the **Shortcuts** page and change them (next section).

## 🪟 Window & custom shortcuts

Left click the tray icon (or *Open InputDood*) to open the window. Pages:

- **Status** — whether a controller is detected, Mouse Mode state, your main shortcuts and a live *controller test* that shows the buttons you are pressing.
- **Shortcuts** — the list of every shortcut. **Add**, **Edit** (or double click), **Remove** or **Restore defaults**.
- **Mouse mode** — cursor speed, response curve, dead zone, trigger threshold, how the ON/OFF message is shown (window / beeps / nothing) and the fullscreen-safe switch.
- **Options** — language, theme (auto / light / dark), close grace time, run at startup, check for updates, open `config.ini`.
- **About** — version, links, manual update check.

### Editing a shortcut

1. Press **Add** (or select one and press **Edit**).
2. Click **Press on controller** and hold the buttons you want at the same time; release them and the combination is recorded. You can also type it, e.g. `Guide+Start`.
3. Choose **when** it works: **Always**, or **Mouse Mode only**.
4. Choose the **action** (close window, toggle Mouse Mode, clicks, scroll, Enter/Esc/Space/Tab/arrows, Alt+Tab, Windows key, media/volume, on-screen keyboard…). *Send a key or text* and *Hold a key* let you type your own key (AutoHotkey syntax, e.g. `{F11}`, `^c` or `Space`).

Buttons you can use: Guide, LB, RB, LT, RT, Start, Back, L3, R3, A, B, X, Y, D-pad (4 directions) and right-stick directions (4).

Rules: when two combinations overlap, **the longest one wins** (holding Guide + Start runs only that shortcut, not Start alone). *Always* shortcuts react to any connected controller; *Mouse Mode only* ones react to the first controller. The default shortcuts reproduce exactly what the table below lists.

## 🖱️ Mouse Mode

Toggle with **Guide + Back**. While active, every button on the controller does something useful. The table shows the **default** shortcuts (all of them can be changed in the *Shortcuts* page):

| Button | Action | Notes |
|---|---|---|
| **Guide + Back** | Toggle Mouse Mode on/off | Works at any time, from anywhere |
| **Guide + Start** | Close/kill active window | Still works even while Mouse Mode is on, as a safety net |
| Left Stick | Move cursor | Linear response by default, adjustable deadzone and speed |
| Right Stick (up/down) | Volume up/down | Repeats while tilted |
| Right Stick (left/right) | Previous/Next media track | One shot per tilt (must re-center before it fires again) |
| RT (trigger) | Left click | Analog trigger, held while past the threshold |
| LT (trigger) | Right click | Analog trigger, held while past the threshold |
| RB | Scroll up | One step per press |
| LB | Scroll down | One step per press |
| A | Enter | Held down while the button is held |
| B | Escape | Held down while the button is held |
| X | Middle click | Held down while the button is held |
| Y | Show/hide on-screen keyboard | Custom built-in keyboard, see below |
| D-Pad | Arrow keys | Held down, supports OS key-repeat |
| L3 (left stick click) | Alt+Tab | One tap = one switch |
| R3 (right stick click) | Play/Pause media | One tap |
| Start (alone, no Guide) | Windows key | Opens the Start Menu |
| Back (alone, no Guide) | Tab | Handy for cycling through UI fields |

Turning Mouse Mode off automatically releases any keys/clicks that might still be held down, so nothing gets "stuck."

Every time you toggle it (either way), a big centered message flashes on screen for a couple of seconds and fades out on its own — green **"Mouse Mode ON"** when you turn it on, red **"Mouse Mode OFF"** when you turn it off — so it's obvious at a glance from across the room whether the controller is currently driving the mouse or not.

> 🔊 **In fullscreen games** the message is not drawn (see [Fullscreen & anti-cheat](#️-fullscreen--anti-cheat)); instead you hear **two rising beeps** when turning it on and **two falling beeps** when turning it off.

### ⌨️ On-screen keyboard

Press **Y** while in Mouse Mode to show/hide a custom on-screen keyboard — built entirely in-house, with no dependency on Windows' `osk.exe` or the touch keyboard (`TabTip.exe`), both of which can be unreliable (elevation issues, or missing services after debloating Windows).

- Move the cursor with the left stick and click keys with **RT**, just like any other on-screen button. Every key lights up while pressed, so you always get clear visual feedback.
- Every time you open it, it appears centered above wherever your cursor currently is (falling back to below the cursor if there's no room above), so it stays out of the way of the text field you're about to use. You can still drag it anywhere by its top bar while it's open.
- **⇧ Shift** is a toggle (like caps-lock) — tap it to switch to uppercase, tap it again to go back; the letter keys themselves flip case so you can see which mode you're in.
- **⌫ Backspace** repeats automatically if you keep it held down, instead of needing to press it repeatedly.
- **?123 / ABC** switches between the letter layout and a symbols/punctuation layout (`< >`, `@#$%`, brackets, quotes, etc.).
- **✕** closes the keyboard from its own title bar.
- 🔊 **It won't open over fullscreen games**: if you press **Y** while a game is fullscreen, you'll hear **three short low beeps** and the keyboard won't appear (so it doesn't kick you out of the game). See [Fullscreen & anti-cheat](#️-fullscreen--anti-cheat).

## 🗂️ Tray menu

- 🪟 **Open InputDood** — opens the window (also the default left click).
- 🖱️ **Mouse mode** — toggle it without the controller.
- ℹ️ **About** — project credits and instructions.
- 🔄 **Check for updates** — manually asks GitHub for the latest release right away. If you're already on the latest version it'll tell you so; if there's an update, it offers to open the download page for you.
- ☕ **Donations** — link to [Patreon](https://www.patreon.com/cw/KyaaaDood).
- 🚀 **Run at startup** — self-explanatory.
- ❌ **Exit** — closes the script.

Left click opens the window; right click opens this menu.

On top of the manual check, InputDood also checks for updates silently a few seconds after it starts — if there's nothing new, it says nothing at all; if there's a newer release, it shows the same "update available" prompt as the manual check.

## 🖥️ Fullscreen & anti-cheat

**Fullscreen.** The "Mouse Mode" message and the on-screen keyboard are regular Windows windows drawn *on top of* whatever is open. Games running in **exclusive fullscreen** (DirectX, e.g. FIFA 17) don't tolerate another window appearing over them: Windows minimizes them, drops them out of fullscreen or takes their focus away. So, since v0.2, InputDood detects when the active window is fullscreen and behaves like this:

| Situation | Mouse Mode indicator | On-screen keyboard |
|---|---|---|
| Normal window / desktop | On-screen message | Works normally |
| Fullscreen game | 2 rising beeps (ON) / 2 falling beeps (OFF) | Doesn't open; 3 short low beeps |

The cursor, clicks, scrolling, volume and every other Mouse Mode button **do work** in fullscreen; what can't be done is *drawing* things over the game.

To use the on-screen keyboard inside a game you have these options:

1. **Windows fullscreen optimizations.** Right-click the game's `.exe` → Properties → Compatibility, and untick *"Disable fullscreen optimizations"*. For many DX11 games, Windows then treats them almost like a borderless window. To make InputDood show the message and keyboard there again, untick *Don't draw windows over fullscreen games* in the *Mouse mode* page (see [Configuration](#-configuration)).
2. **Borderless window.** Set the game to windowed mode at native resolution and use a tool like Borderless Gaming to remove the border. This is the most reliable method.
3. **In-game overlays** (Steam's keyboard, for example) work because they inject into the game. InputDood does **not** do this and never will: it is exactly the behavior anti-cheat systems flag.

> ℹ️ Unticking that option disables this detection. By default, detection treats any window without a title bar that covers the whole monitor as "fullscreen", so it also applies to borderless games. In those cases the visual indicator and the keyboard are also replaced by beeps.

**Anti-cheat.** InputDood is built on AutoHotkey, simulates mouse/keyboard input (`MouseMove`, `Click`, `Send`) and can kill processes (`WinKill`). Some anti-cheat systems, especially kernel-level ones (Vanguard, EasyAntiCheat, BattlEye, etc.), detect or restrict exactly that kind of tool, so:

- You may get a warning, have the game refuse to launch or, in the worst case, get banned. **Compatibility with any online game is not guaranteed.**
- **Don't use it with competitive online games protected by anti-cheat** unless you accept the risk. Single-player/offline games are usually fine.
- If you want to be safe, close InputDood (tray menu → Exit) before launching the game.
- InputDood doesn't inject into other processes, read other programs' memory or run elevated, but that doesn't stop an anti-cheat from flagging it just for using AutoHotkey.
- The same goes for **antivirus detection**: the compiled `.exe` can trigger false positives because it's AutoHotkey.

## ⚠️ Known limitations

- 🗝️ Your antivirus may block this application, but you can always take a look at the source code if you have any suspicions.
- 🎮 If your controller isn't fully compatible with Windows' XInput driver (e.g. some DirectInput-only pads), the Guide button might not be detected.
- 🔒 InputDood runs unelevated by design (safer, and less likely to get flagged by anti-cheat). This means it can't send clicks/keys to windows that are running as Administrator — you'd need to run InputDood elevated too for that, which isn't recommended for online games with kernel-level anti-cheat.
- 🖥️ It can't draw the Mouse Mode indicator or the on-screen keyboard over fullscreen games (see [Fullscreen & anti-cheat](#️-fullscreen--anti-cheat)); it uses beeps instead.
- ❌ You'll probably get warned by some anti-cheats about this app because it uses AutoHotkey, **USE IT AT YOUR OWN RISK, BE CAREFUL**.

## 🔧 Configuration

Since 0.3 everything is changed from the window and saved in **`%AppData%\InputDood\config.ini`** (the *Options* page has buttons to open the file or its folder). You can also edit it by hand:

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

Each shortcut is `scope|buttons|action` (`scope` = `always` or `mouse`; custom actions are written `custom_tap:{F11}` / `custom_hold:Space`). If `[bindings]` doesn't exist the defaults are used.

A few advanced values are still constants at the top of the `.ahk`: `APP_VERSION`, `GITHUB_REPO`, `POLL_INTERVAL_IDLE_MS` (100), `POLL_INTERVAL_MOUSE_MS` (16), `VOLUME_REPEAT_MS` (120), `MEDIA_TRACK_DEADZONE` (20000) and `MOUSE_INDICATOR_DURATION_MS` (2500).

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md).

## 🔨 Build the `.exe`

Double-click **`Build.bat`** (Windows, no administrator rights). The first time it downloads AutoHotkey v2 and Ahk2Exe into `build\cache`, then compiles everything into **`dist\InputDood.exe`**: a single file with the AutoHotkey runtime and the icon inside. The exe's version is read from `APP_VERSION` in `InputDood.ahk`. If your network blocks the downloads, put `AutoHotkey64.exe` (v2) and `Ahk2Exe.exe` in `build\cache` and run it again.

## 📄 License

InputDood is free software under the **[GNU GPL v2](LICENSE)**. You can use, study, modify and share it; if you distribute it (or a modified version), it must stay under the same license and come with its source code.

The compiled `InputDood.exe` includes [AutoHotkey v2](https://www.autohotkey.com) (GPLv2). Their notices and source links are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 💛 Credits

Made by **KyaaaDood** with Claude AI. 🤖✨

If you want, you can support me at [Patreon](https://www.patreon.com/cw/KyaaaDood).

InputDood includes [AutoHotkey v2](https://www.autohotkey.com) (GPLv2); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
