# -------------------------------------------------------------
# GLOBALS
#

# for now, no include of masters. too much can go wrong 
# if we don't find it
# but: we need the bg pngs anyway, so an additional text file
# shouldn't be a problem, ... hmmm

# for slides without bg pngs:
@bgcolor #f0d020

# global settings of the presentation
@date today - just some string if used
# -------------------------------------------------------------


# -------------------------------------------------------------
# title slide
@slide
@bg 0.png
@textbox x y w h fontsize color Title

@textbox x y w h fontsize color 
subtitle

@textbox x y w h fontsize color authors

# -------------------------------------------------------------
@slide
@bg 3.png
@textbox x y w h fontsize color Title of the slide

# left box
@textbox x y w h fontsize color 
Here comes the left text.
- we have a bulleted list
    - we can indent
    - like so
- and back
_
We make empty lines with _.

# left box
@textbox x y w h fontsize color 
this goes into the right box

# sources box
@textbox x y w h fontsize color 
if present, the sources come here
# -------------------------------------------------------------



# -------------------------------------------------------------
@slide 

@title this is the second slide

@singlebox
this is a single box layout
so no left and right, just one big one

@img "/path/to/image.png" tl 0.1 0.1 br 0.9 0.9 centerscale

@img "/path/to/image.png" tl 0.1 0.1 scale 0.9 0.9 

@textbox x y w h fontsize color 
- we just placed an image and placed it 
- with relative TL BR coords, scaling to fit, centering the img
- with relative TL coords and x, y scale
# -------------------------------------------------------------



