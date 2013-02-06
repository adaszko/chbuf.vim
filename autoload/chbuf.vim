let s:save_cpo = &cpo
set cpo&vim


function! BufferNameCallback(contents) " {{{
    let buffer = bufname(a:contents)

    if buffer == ''
        return ''
    else
        return ' ↦ ' . bufname(a:contents)
    endif
endfunction " }}}


function! chbuf#PromptBuffer() " {{{
    let name = getline#GetLine('∷ ', 'BufferNameCallback')
    execute 'silent' 'buffer' name
    return name
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
