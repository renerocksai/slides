# Backlog

* re-introduce `$slide_number`

- [x] jump to editor cursor pos on error
- [x] dupe editor mem -> editing won't change slides stuff
- [x] fix parser and initial slide rendering
- [x] allow shortcut keys if editor !active (instead of !visible)
- [x] editor width shrink, grow buttons
- [x] show line in open editor when changing slides (!new! flash it!)
- [x] drag editor width button y-centered - can be used as dummy button for flash animation? no, it would flash, too
- [x] If there are no slides, show a red background in showslides
- [x] if current slide index > num_slides: jump to last slide in showslides -- this will be used in hot reloads
- [x] hot reload slides
- [x] `$slide_number`
- [x] bullets bg imgs and colors -- bullets-like template
- [x] separate arena for slides : on reload just wipe the arena
- [x] initial bullet rendering: draw text first, substituting bullet symbols by "  ", then a second time with just the bullets in their own style
- [x] slides: get items parsed into render elements: texts split into blocks of normal and bulleted text - for special bullet rendering and formatting like centering
- [x] Menus - bring back the menus!
- [x] render bullets in bulleted text boxes, with nice indents (come automatically on wrap :) 
- [x] parse markdown (dialect) subset
- [x] load (and cache) bold, italic, bolditalic fonts
- [x] render markdown
  - [ ] not perfect. screws up in title **artificial** _voices_ in _**human choices**_ with wrapping (cut off)
        manual line break solves it, though.
- [x] laserpointer
- [ ] Overview Mode
- [ ] PDF export
  - [ ] via png?
  - [ ] native?
- [ ] Themes
- [ ] hide mouse cursor in full-screen mode
  - at least in i3wm this does neither work with `sapp_show_mouse(false)` nor 
    `igSetMouseCursor(ImGuiMouseCursor_None)`.
- [ ] presenter mode - with notes? multi-monitor-support?
  - interesting idea: compagnion website: shows slideshow notes, timer, etc -- instead of 2nd monitor
  - when in home office, we aren't connected to a beamer - and don't have a 2nd monitor
  - hosted directly by the exe: we are in same network anyway
- [ ] **export to bullets** 
  - [ ] dockerized exports for web, win, linux
- [ ] dockerized builds of slides, incl windows !!! (provide missing libs) -- is this possible?
- [ ] nicer (image?) buttons
- [ ] FONTS
  - [ ] **cache all font sizes**
    - [ ] cache **fullscreen** font sizes (cause they matter most!)
  - [ ] allow user-defined fonts
  - see below



## Themes
- Load `default.theme` if present next to executable
- Auto-reload theme if file changed
    - Call checkIfThemeChanged(check_interval_ms: i32, dt_ms: i32) 
    - Put in:
        - all anim timers, colors
        - all relevant slides specific ui colors
        - all relevant imgui colors
        - fonts, font sizes
- edit themes in built-in editor



## Menus

**Hide menus in full-screen mode !!!** 

- File
    - new
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



## Exports and Builds


### Export to Bullets

Export a godot project : templated .tscn

Create static Dockerfile in Export that builds all exports (win, lin, web) of the presentation.

### Build Slides executable via docker
Easy builds and releases -- can potentially be put into GitHub CI.

#### Option A
GitHub CI - if it provides windows builds

#### Option B
Check if we can provide the missing windows links and cross-compile / cross-build it in just one Docker container.


## Fonts
We cannot add fonts to the font atlas while in a render call. However, with upaya, we never get outside of a render call. Hence, we adapted the default baked font sizes so they look good on our monitor, both in default window size and full screen

### Workarounds

#### Adapt sokol
To give us a callback before rendering a frame. 

#### Write font baking info to file 
... and allow to load it from the command line

a default baked_fonts.config could replace our fixed list - the list would only be used if no baked_fonts.config is present.
