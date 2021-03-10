# Backlog

- [ ] jump to editor cursor pos on error
- [ ] fix parser and slide rendering
- [ ] drag editor width / shrink, grow buttons
- [ ] Themes
- [ ] Menus - bring back the menus!
- [ ] nicer (image?) buttons
- [ ] laserpointer
- [ ] hide mouse cursor

## Themes
- Load `default.theme` if present next to executable
- Auto-reload theme if file changed
    - Call checkIfThemeChanged(check_interval_ms: i32, dt_ms: i32) 
    - Put in:
        - all anim timers, colors
        - all relevant slides specific ui colors
        - all relevant imgui colors
        - fonts, font sizes

## Menus

**Hide menus in full-screen mode !!!** 

- File
    - new
    - new from template
    - open
    - save
    - save as
    - quit

- (edit)

- View
    - toggle fullscreen
    - toggle editor
    - toggle overview
    - toggle on-screen menu buttons
    - Switch Theme
        - default
        - other detected theme 1
        - other detected theme 2
        - separator ---
        - load theme file

Show menu also in main menu screen (on startup). This makes the main menu screen a start screen only. Going back to the start screen is not really practical once we have the menu. So the main menu button can go.


