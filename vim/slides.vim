" Vim syntax file
" Language:    Slides Syntax
" By: Rene Schallner <renemann@gmail.com>
" Creation date: 29-Mar-2021
" Version 1.0


" Remove any old syntax stuff hanging about
syn clear
syn case ignore

syn keyword pushpop @push @pop @pushslide @popslide 
syn keyword attrs x= y= w= h= fontsize= color= text=
syn keyword classes @bg @img @box

syn region bolditalictext matchgroup=mdsym start=/\v_\*\*/ end=/\v\*\*_/ oneline contains=boldtext,italictext
syn region boldtext matchgroup=mdsym start=/\v\*\*/ end=/\v\*\*/ oneline 
syn region italictext matchgroup=mdsym start=/_/ end=/_/ oneline 
syn region underline matchgroup=mdsym start=/\v\~\~/ end=/\~\~/ oneline 
hi link mdsym Special
hi  boldtext cterm=bold gui=bold
hi  italictext cterm=italic gui=italic
hi  underline cterm=underline gui=underline
hi  bolditalictext cterm=bold,italic gui=bold,italic ctermfg=yellow guifg=yellow

"syn region underlinetext matchgroup=mdsym start=/\v_/ end=/\v\*\*/ oneline 

syn region color_begin matchgroup=color start="<#\x\+>" end="</>"

" The default methods for highlighting.  Can be overridden later
hi link Label    Label
hi link String    String
hi link Comment    Comment
hi link Settings    Statement
hi link pushpop Statement
hi link classes Special
hi link attrs Identifier
hi link color_begin Identifier
hi link color Number
"hi link Settings Conditional
hi link Todo Debug

hi link underline Special

hi link Globals Identifier
let b:current_syntax = "slides"


syn region dummy  matchgroup=Globals start="@font"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@fontsize"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@font_bold"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@font_italic"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@font_bold_italic"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@font_extra"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@underline_width"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@color"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@bullet_color"  skip="=" end="/\@!" display oneline 
syn region dummy  matchgroup=Globals start="@bullet_symbol"  skip="=" end="/\@!" display oneline 

syn region dummy  matchgroup=attrs start="x="   end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="y="   end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="w="   end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="h="   end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="fontsize="  end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="color="  end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="text="  end="/\@!" display oneline 
syn region dummy  matchgroup=attrs start="img="  end="/\@!" display oneline 

syn match color	"#\x\+\>"
syn match number "\d"
syn match Comment        "^#.*"
