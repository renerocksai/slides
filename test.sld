# #############################################################
# ##   T  E  M  P  L  A  T  E  S
# #############################################################

# -- global setup
@fontsize=16
@font=assets/Calibri Light.ttf
@font_bold=assets/Calibri Regular.TTF
@font_italic=assets/Calibri Light Italic.ttf
@font_bold_italic=assets/Calibri Bold Italic.ttf
@underline_width=2
@color=#aabbccdd
@bullet_color=#ff0000ff

# -------------------------------------------------------------
# -- definitions for later
# -------------------------------------------------------------
@push slide_title x=100 y=100 w=1920 h=1080 fontsize=64 color=#000000ff
@push leftbox x=0 y=0 w=100 h=100 fontsize=16 color=#000000ff bullet_color=#11223344 underline_width=4
@push rightbox x=0 y=0 w=100 h=100 fontsize=16 color=#000000ff
@push bigbox x=0 y=0 w=100 h=100 fontsize=16 color=#000000ff

# the text $slide_number will be auto expanded 
@push slide_number x=0 y=0 w=100 h=100 fontsize=16 color=#000000ff text=$slide_number / $num_slides

# -------------------------------------------------------------
# -- intro slide template
# -------------------------------------------------------------
@bg img=assets/nim/1.png
# or
# @bg color=#000000000
@push intro_title    x=200 y=450 w=950 h=100 fontsize=96 color=#123456aa 
@push intro_subtitle x=200 y=650 w=950 h=100 fontsize=96 color=#123456aa 
@push intro_authors  x=200 y=850 w=950 h=100 fontsize=36 color=#123456aa 
# the following pushslide will the slide cause to be pushed, not rendered
@pushslide intro     fontsize=16 bullet_color=#12345678 color=#bbccddee


# -------------------------------------------------------------
# -- chapter slide template
# -------------------------------------------------------------
# Note: with each new @slide, the current item context will be cleared.
#       That means, you will not inherit attributes from previous slides.

@bg img=assets/nim/3.png
@push chapter_number x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
@push chapter_title x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
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
@push thankyou_title x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
@push thankyou_subtitle x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
@push thankyou_authors x=0 y=0 w=100 h=100 fontsize=16 color=#123456aa 
@pushslide thankyou



# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title text=Artificial Voices in Human Choices
@pop intro_subtitle text=Milestone 3
@pop intro_authors fontsize=72 text=Dr. Carolin Kaiser, Rene Schallner


# -------------------------------------------------------------
@popslide chapter
@pop chapter_number text=1
@pop chapter_title fontsize=16 text=The big picture


# -------------------------------------------------------------
@popslide content

@pop slide_title text=The Big Plan

@pop leftbox
- here comes the text
- and so on

@pop rightbox
- here is text in the right box

# some random textbox
@box x=100 y=100 w=100 h=100
here comes the text
- and we start a bullet list
- on with the list
_
And some more text. Note that the _ is a placeholder for empty lines.
Empty lines will be swallowed by the parser!

# -------------------------------------------------------------
@popslide thankyou
@pop thankyou_title text=Artificial Voices in Human Choices
@pop thankyou_subtitle text=Milestone 3
@pop thankyou_subtitle text=Dr. Carolin Kaiser, Rene Schallner

# -------------------------------------------------------------
# eof commits the slide
