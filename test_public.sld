# #############################################################
# ##   T  E  M  P  L  A  T  E  S
# #############################################################

# -- global setup
@fontsize=36
@font=./assets/fonts/GeorgiaPro-Light.ttf
@font_bold=./assets/fonts/GeorgiaPro-Bold.ttf
@font_italic=./assets/fonts/GeorgiaPro-Italic.ttf
@font_bold_italic=./assets/fonts/GeorgiaPro-BoldItalic.ttf
@underline_width=2
@color=#000000ff
@bullet_color=#cd0f2dff
# Override bullet symbol default of > with the bullet point
# @bullet_symbol=•

# -------------------------------------------------------------
# -- definitions for later
# -------------------------------------------------------------

@push slide_title  x=110  y=71   w=1712 h=73  fontsize=52 color=#000000ff

@push slide_number x=1803 y=1027 w=40   h=40  fontsize=20 color=#404040ff text=$slide_number

@push sources_info x=110  y=960  w=1758 h=129 fontsize=20 color=#bfbfbfff text=Sources:

@push bigbox       x=110  y=181  w=1700 h=971 fontsize=45 color=#000000ff
@push leftbox      x=110  y=181  w=850  h=861 fontsize=45 color=#000000ff
@push rightbox     x=1080 y=181  w=850  h=879 fontsize=45 color=#000000ff

# -------------------------------------------------------------
# -- intro slide template
# -------------------------------------------------------------
@bg img=assets/bgwater.jpg
@push intro_title    x=150 y=400 w=1700 h=223 fontsize=96 color=#7A7A7AFF
@push intro_title_shadow    x=154 y=404 w=1700 h=223 fontsize=96 color=#000000FF
@push intro_subtitle x=219 y=728 w=836 h=246 fontsize=45 color=#cd0f2dff
@push intro_authors  x=219 y=818 w=836 h=246 fontsize=45 color=#993366ff
# the following pushslide will the slide cause to be pushed, not rendered
@pushslide intro


# -------------------------------------------------------------
# -- chapter slide template
# -------------------------------------------------------------
# Note: with each new @slide, the current item context will be cleared.
#       That means, you will not inherit attributes from previous slides.

@bg img=assets/bgwater.jpg
@push chapter_number x=201 y=509 w=260 h=362 fontsize=300 color=#cd0f2dff 
@push chapter_title  x=757 y=673 w=949 h=114 fontsize=72  color=#000000ff 
@push chapter_subtitle x=757 y=794 w=887 h=141 fontsize=45 color=#993366ff 
@pushslide chapter

# -------------------------------------------------------------
# -- content slide template
# -------------------------------------------------------------
@bg img=assets/bglb.jpg
@pop slide_number
@pushslide content

# -------------------------------------------------------------
# -- thankyou slide template
# -------------------------------------------------------------
@bg img=assets/bgwater.jpg
@box                    x=221  y=252  w=1750  h=223 fontsize=144 color=#000000FF text=**THANK YOU FOR YOUR ATTENTION**
@box                    x=219  y=250  w=1750  h=223 fontsize=144 color=#cd0f2dff text=**THANK YOU FOR YOUR ATTENTION**
#@box                    x=219  y=250  w=1750  h=223 fontsize=144 color=#606060FF text=**THANK YOU FOR YOUR ATTENTION**
@push thankyou_title    x=219  y=655  w=918  h=223 fontsize=52 color=#000000ff 
@push thankyou_title_shadow    x=221  y=657  w=918  h=223 fontsize=52 color=#000000ff 
@push thankyou_subtitle x=219  y=749  w=836  h=246 fontsize=45 color=#000000ff
@push thankyou_authors  x=219  y=836  w=836  h=243 fontsize=45 color=#993366ff
@pushslide thankyou



# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title_shadow text=!Slideshows in ZIG!
@pop intro_title text=!Slideshows in <#F7A41DFF>ZIG</>!
@pop intro_subtitle text=_**Easy, text-based slideshows for Hackers**_
@pop intro_authors text=_@renerocksai_

@pop rightbox x=1200 y=75
<#0000ffff>_~~https://github.com/renerocksai/slides~~_</>
@box img=assets/GitHub-Mark-64px.png x=1120 y=65 w=64 h=64

# -------------------------------------------------------------
@popslide content
@pop slide_title text=~~**Overview**~~
@pop bigbox bullet_symbol=- color=#202020FF
- **Presentations are created in a simple, markdown-based text format**
        - <#808080FF>_makes your slides totally GitHub-friendly_</>
_
- **One single (mostly static) executable** _- no install required._
        - <#808080FF>_for Windows, Linux (and Mac, if you build it yourself)_</>
_
_
- **Built-in editor:** _create, edit, present, ..., make changes while presenting_
        - <#808080FF>_press [E] key to try it out_</>
_
- **Support for clickers**
_
_
- **Virtual laser pointer in different sizes**
        - <#808080FF>_press [L] key and [SHIFT] + [L] to try it out_</>



# -------------------------------------------------------------
@popslide content
@pop slide_title text=~~**Formatting Text**~~

@pop  sources_info 
here come the sources

@pop leftbox 
This is Markdown _**ta-dah**_, **tah**, _dah_!
_
empty lines are marked with just an _ underscore
_
- here comes the text
    - even more
        - and let's wrap one more time into a nicely aligned textbox
_
- and so on
_
- now let us create a text that is very likely to need to be wrapped since it is too long to be rendered on a single line of text in the left box 
_
- **and so on**, _and on_

@pop rightbox bullet_symbol=•
_
_
_
- here is text in the right box
_
- we changed the **~~bullet symbol~~**!
_
- and so on
_
- here comes more text
_
- and so on
_
- here comes more text
_
- and ~~**so on**~~

# -------------------------------------------------------------
@popslide content
@pop slide_title text=**Easier than Bullets**

@box img=assets/godotscr2.png x=400 y=150 w=1475 h=840

@pop leftbox w=260 h=800
- single executable for presenting and editing 
_
- text based slide format. 
_
- no need to drag, click, and find and edit properties
_
- compare ------->
_
- however, simpler:
    - no complex animationse
    - no scripting
    - ...

# -------------------------------------------------------------
@popslide content
@pop slide_title text=~~**Easier than Bullets**~~

@box x=1398 y=148 w=404 h=204 color=#606060FF
@box x=1400 y=150 w=400 h=200 img=./assets/bgwater.jpg
@box x=1400 y=450 w=400 h=200 color=#B00040B0
@box x=1430 y=760 w=340 h=180 img=./assets/bgwater.jpg
@box x=1600 y=800 w=240 h=100 color=#B00040B0

@pop rightbox x=1431 y=801 w=400 color=#B0B0B0FF
       **it works in combination, too**
@pop rightbox x=1430 y=800 w=400 color=#202020FF
       **it works in combination, too**

@pop leftbox w=1000 h=800
_
- with _@box img=..._ you place images
_
_
_
_
_
- with _@box color=..._ and no text, you place colored boxes
    > ... with ALPHA!

@box leftbox x=110 y=800 w=1000 h=800 color=#cd0f2dff
- with _@box color=... text=..._ you place text boxes with colored text


# -------------------------------------------------------------
@popslide thankyou
@pop thankyou_title_shadow color=#000000FF text=!Slideshows in ZIG!
@pop thankyou_title color=#7A7A7AFF text=!Slideshows in ZIG!
@pop thankyou_subtitle color=#202020FF text=_Slideshows for Hackers_
@pop thankyou_authors text=_@renerocksai_

@pop rightbox x=1200 y=50
<#0000ffff>_~~https://github.com/renerocksai/slides~~_</>
@box img=assets/GitHub-Mark-64px.png x=1120 y=45 w=64 h=64
# -------------------------------------------------------------
# eof commits the slide
