nmap <leader>t :VimuxRunCommand("zig build slides")<cr>

" run :make to get compilation errors into quickfix list
:set makeprg=zig\ build\ slides

