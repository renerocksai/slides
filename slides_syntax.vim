" Vim syntax file
" Language:	Slides Syntax
" By: Rene Schallner <renemann@gmail.com>
" Creation date: 29-Mar-2021
" Version 1.0

" Remove any old syntax stuff hanging about
syn clear
syn case ignore
"

syn keyword pushpop @push @pop @pushslide @popslide 
syn keyword attrs x= y= w= h= fontsize= color= text=
syn keyword classes @bg @img @box


syn match Comment		"^#.*"
syn region underline		start=+_+ skip=+\\"+ end=+_+
syn region bold		start=+**+ skip=+\\"+ end=+**+
syn keyword Settings	    @fontsize @font @font_bold @font_italic @font_bold_italic @underline_width @color @bullet_color
syn keyword color_end </color>


" how do we match <color=#rrggbbaa> and </color>
syn match color	"#\x\+\>"
syn match color_begin	"<color=\x\+\>>"

"
"syn case match
if !exists("did_asmR2_syntax_init")
  let did_slide_syntax_init = 1

  " The default methods for highlighting.  Can be overridden later
  hi link Label	Label
  hi link String	String
  hi link Comment	Comment
  hi link Settings	Statement
 hi link pushpop Statement
 hi link classes Special
 hi link attrs Identifier
 hi link color_begin Identifier
 hi link color_end Identifier
 hi link color Number
 hi link Settings Conditional
" hi link Todo Debug

  hi link bold Special
  hi link underline Special

endif

let b:current_syntax = "slides"


