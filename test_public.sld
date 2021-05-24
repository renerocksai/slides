# #############################################################
# ##   T  E  M  P  L  A  T  E  S
# #############################################################

# -- global setup
@fontsize=36
@font=assets/Calibri Light.ttf
@font_bold=assets/Calibri Regular.TTF
@font_italic=assets/Calibri Light Italic.ttf
@font_bold_italic=assets/Calibri Bold Italic.ttf
@underline_width=2
@color=#000000ff
@bullet_color=#cd0f2dff

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
@push intro_title    x=219 y=500 w=836 h=223 fontsize=96 color=#000000ff
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
@box                    x=219  y=469  w=750  h=223 fontsize=68 color=#cd0f2dff text=THANK YOU FOR YOUR ATTENTION
@push thankyou_title    x=219  y=655  w=918  h=223 fontsize=52 color=#000000ff 
@push thankyou_subtitle x=219  y=749  w=836  h=246 fontsize=45 color=#000000ff
@push thankyou_authors  x=219  y=836  w=836  h=243 fontsize=45 color=#993366ff
@pushslide thankyou



# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title text=**Slideshows in ZIG**
@pop intro_subtitle text=_**Easy text-based slideshows for Hackers**_
@pop intro_authors text=_@renerocksai_

@pop rightbox x=1200 y=75
<#0000ffff>_~~https://github.com/renerocksai/slides~~_</>
@box img=assets/GitHub-Mark-64px.png x=1120 y=65 w=64 h=64

# -------------------------------------------------------------
@popslide chapter
@pop chapter_number text=1

@pop chapter_title 
The big picture

@pop chapter_subtitle
The big picture


# -------------------------------------------------------------
@popslide content
@pop slide_title text=The Big Plan

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

@pop rightbox 
_
_
_
- here is text in the right box
_
- here comes more text
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
@pop slide_title text=Easier than Bullets

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
@popslide thankyou
@pop thankyou_title text=**Slideshows in ZIG**
@pop thankyou_subtitle text=_Slideshows for Hackers_
@pop thankyou_authors text=_@renerocksai_

@pop rightbox x=1200 y=530
<#0000ffff>_~~https://github.com/renerocksai/slides~~_</>
@box img=assets/GitHub-Mark-64px.png x=1120 y=520 w=64 h=64
# -------------------------------------------------------------
# eof commits the slide
