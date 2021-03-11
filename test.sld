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
@push slide_number x=1803 y=1021 w=40   h=40  fontsize=20 color=#000000ff text=$slide_number
@push sources_info x=110  y=960  w=1758 h=129 fontsize=20 color=#bfbfbfff 

@push bigbox       x=110  y=181  w=1700 h=971 fontsize=36 color=#000000ff
@push leftbox      x=110  y=181  w=850  h=861 fontsize=36 color=#000000ff
@push rightbox     x=1080 y=181  w=850  h=879 fontsize=36 color=#000000ff

# -------------------------------------------------------------
# -- intro slide template
# -------------------------------------------------------------
@bg img=assets/nim/1.png
# @push intro_title    x=219 y=481 w=950 h=100 fontsize=96 color=#000000ff
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

@bg img=assets/nim/3.png
@push chapter_number x=201 y=509 w=260 h=422 fontsize=300 color=#000000ff 
@push chapter_title  x=757 y=673 w=949 h=114 fontsize=72  color=#cd0f2dff 
@push chapter_subtitle x=757 y=794 w=887 h=141 fontsize=36 color=#993366ff 
@pushslide chapter

# -------------------------------------------------------------
# -- content slide template
# -------------------------------------------------------------
@bg img=assets/nim/5.png
@pop slide_number
@pushslide content

# -------------------------------------------------------------
# -- thankyou slide template
# -------------------------------------------------------------
@bg img=assets/nim/thankyou.png
@box                    x=219  y=469  w=750  h=223 fontsize=68 color=#cd0f2dff text=THANK YOU FOR YOUR ATTENTION
@push thankyou_title    x=219  y=655  w=918  h=223 fontsize=53 color=#000000ff 
@push thankyou_subtitle x=219  y=749  w=836  h=246 fontsize=45 color=#cd0f2dff
@push thankyou_authors  x=219  y=836  w=836  h=243 fontsize=45 color=#993366ff
@pushslide thankyou



# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title text=Artificial Voices in Human Choices
@pop intro_subtitle text=Milestone 3
@pop intro_authors text=Dr. Carolin Kaiser, Rene Schallner


# -------------------------------------------------------------
@popslide chapter
@pop chapter_number text=1
@pop chapter_title text=The big picture
@pop chapter_subtitle text=The big picture


# -------------------------------------------------------------
@popslide content

@pop slide_title text=The Big Plan


@pop  sources_info text=here come the sources

@pop leftbox 
- here comes the text
- and so on
- here comes the text
- and so on
- here comes the text
- and so on

@pop rightbox 
- here is text in the right box
- here comes the text
- and so on
- here comes the text
- and so on
- here comes the text
- and so on


# -------------------------------------------------------------
@popslide thankyou
@pop thankyou_title text=Artificial Voices in Human Choices
@pop thankyou_subtitle text=Milestone 3
@pop thankyou_authors text=Dr. Carolin Kaiser, Rene Schallner

# -------------------------------------------------------------
# eof commits the slide
