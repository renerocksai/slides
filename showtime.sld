# #############################################################
# ##   T  E  M  P  L  A  T  E  S
# #############################################################

# -- global setup
@fontsize=36
@font=./assets/press-start-2p.ttf
@font_bold=./assets/fonts/GeorgiaPro-Bold.ttf
@font_italic=./assets/fonts/GeorgiaPro-Italic.ttf
@font_bold_italic=./assets/fonts/GeorgiaPro-BoldItalic.ttf
@underline_width=2
@color=#eeeeeeff
@bullet_color=#cd0f2dff

# -------------------------------------------------------------
# -- definitions for later
# -------------------------------------------------------------

@push slide_title  x=110  y=71   w=1712 h=73  fontsize=52 color=#eeff41ff
@push slide_number x=1803 y=1027 w=40   h=40  fontsize=20 color=#404040ff text=$slide_number
@push sources_info x=110  y=1027  w=1758 h=129 fontsize=20 color=#404040ff text=Sources:

@push bigbox       x=110  y=181  w=1700 h=971 fontsize=45 color=#eeeeeeff
@push leftbox      x=110  y=181  w=850  h=861 fontsize=45 color=#eeeeeeff
@push rightbox     x=1080 y=181  w=850  h=879 fontsize=45 color=#eeeeeeff

# -------------------------------------------------------------
# -- intro slide template
# -------------------------------------------------------------
@bg color=#000000ff 

@push intro_title    x=120 y=300 w=1800 h=223 fontsize=96 color=#eeff41ff
@push intro_subtitle x=219 y=528 w=1500 h=246 fontsize=45 color=#eeeeeeff
@push intro_authors  x=219 y=618 w=1500 h=246 fontsize=45 color=#ffab40ff
@pushslide intro


# -------------------------------------------------------------
# -- chapter slide template
# -------------------------------------------------------------
# Note: with each new @slide, the current item context will be cleared.
#       That means, you will not inherit attributes from previous slides.

@bg color=#000000ff
@push chapter_number x=201 y=300 w=500 h=362 fontsize=400 color=#ffab40ff
@push chapter_title  x=757 y=400 w=1500 h=114 fontsize=72  color=#eeff41ff
@push chapter_subtitle x=757 y=550 w=1500 h=141 fontsize=45 color=#eeeeeeff
@pushslide chapter


# -------------------------------------------------------------
# -- content slide template
# -------------------------------------------------------------
@bg color=#000000ff
@pop slide_number
@pushslide content

# -------------------------------------------------------------
# -- thankyou slide template
# -------------------------------------------------------------
@bg color=#000000ff 
@box x=120 y=170 w=1800 h=223 fontsize=96 color=#eeff41ff text=Thank you for your 
    attention
@push thankyou_title    x=219 y=470 w=1800 h=223 fontsize=64 color=#eeff41ff
@push thankyou_subtitle x=219 y=568 w=1500 h=246 fontsize=45 color=#eeeeeeff
@push thankyou_authors  x=219 y=648 w=1500 h=246 fontsize=45 color=#ffab40ff
@pushslide thankyou

# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title text=Slideshows in ZIG
@pop intro_subtitle text=Easy slideshows for Hackers
@pop intro_authors text=@renerocksai

@pop rightbox x=1200 y=75 fontsize=18 color=#808080FF
~~https://github.com/renerocksai/~~

#@pop rightbox x=1732 y=75 fontsize=18 color=#F7A41DFF
@pop rightbox x=1732 y=75 fontsize=18 color=#ffab40ff
~~slides~~
@box img=assets/github-dark-lg.png x=1120 y=56 w=64 h=64


# -------------------------------------------------------------
@popslide chapter
@pop chapter_number text=1
@pop chapter_title text=Chapter One
@pop chapter_subtitle text=How it all began



# -------------------------------------------------------------
@popslide content
@pop slide_title text=Basic slide 2 columns
@pop slide_number

@pop leftbox
this is left
_
-> and so on
_
-> and on

@pop rightbox
this is right
_
-> and so on
_
-> and on


# -------------------------------------------------------------
@popslide content
@pop slide_title text=What about a dense slide?
@pop slide_number

@pop leftbox
this is left
-> and so on
-> and on

@pop rightbox
this is right
-> and so on
-> and on

@pop bigbox x=110 y=400
<#ffab40ff>~~Another block of text:~~</>
_
OK, let's not make it too dense, but let it wrap over multiple lines, which shouldn't be too hard with this font and its size.

# -------------------------------------------------------------
@popslide chapter
@pop chapter_number text=2
@pop chapter_title text=More stuff
@pop chapter_subtitle text=Images and slide numbers


# -------------------------------------------------------------
@popslide content
@pop slide_title text=A slide with an image
@pop sources_info text=Sources: @renerocksai
@pop slide_number

@pop bigbox
-> This slide contains an image
_
-> It is slide number <#00ffffff>$slide_number</>

@box img=screenshots/slides_plus_ed.png x=300 y=350 w=1280 h=640

# -------------------------------------------------------------
@popslide content
@pop slide_title text=A slide with an image
@pop sources_info text=Sources: @renerocksai
@pop slide_number

@pop bigbox
-> This slide contains an image
_
-> It is slide number <#00ffffff>$slide_number</>

@box img=screenshots/slides_plus_ed.png x=300 y=350 w=1280 h=640

# -------------------------------------------------------------
@popslide chapter
@pop chapter_number text=3
@pop chapter_title text=Even more stuff
@pop chapter_subtitle text=Laserpointer ...

# -------------------------------------------------------------
@popslide content
@pop slide_title text=Laserpointers and clickers
@pop slide_number

@pop bigbox
-> We have a laserpointer
_
-> In multiple sizes
_
-> Wireless clickers are supported
_

# -------------------------------------------------------------
@popslide thankyou
@pop thankyou_title text=Slideshows in ZIG
@pop thankyou_subtitle text=Easy slideshows for Hackers
@pop thankyou_authors text=@renerocksai

@pop rightbox x=1200 y=75 fontsize=18 color=#808080FF
~~https://github.com/renerocksai/~~

@pop rightbox x=1732 y=75 fontsize=18 color=#F7A41DFF
~~slides~~



@box img=assets/github-dark-lg.png x=1120 y=56 w=64 h=64


