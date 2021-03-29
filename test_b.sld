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
# -- intro slide template
# -------------------------------------------------------------
@bg img=assets/bgwater.jpg
# @push intro_title    x=219 y=481 w=950 h=100 fontsize=96 color=#000000ff
@push intro_title    x=219 y=500 w=950  h=223 fontsize=96 color=#000000ff
@push intro_subtitle x=219 y=728 w=836 h=246 fontsize=45 color=#cd0f2dff
@push intro_authors  x=219 y=818 w=836 h=246 fontsize=45 color=#993366ff
# the following pushslide will the slide cause to be pushed, not rendered
@pushslide intro

# #############################################################
# ##   S  L  I  D  E  S
# #############################################################

# -------------------------------------------------------------
@popslide intro
@pop intro_title text=Artificial Voices in Human Choices
@pop intro_subtitle text=Milestone 3
@pop intro_authors text=Dr. Carolin Kaiser, Rene Schallner
