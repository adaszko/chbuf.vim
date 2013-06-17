let s:save_cpo = &cpo
set cpo&vim


" This accounts for 'showcmd'.  Is there a way to calculate it?
let g:chbuf_cmdwidth_fixup = 15


function! s:Echo(line) " {{{
    echon strpart(a:line, 0, &columns - g:chbuf_cmdwidth_fixup)
endfunction " }}}

function! s:ClearLine(contents) " {{{
    let rubber = "\r" . repeat(' ', strlen(a:contents)) . "\r"
    call s:Echo(rubber)
endfunction! " }}}

function! s:WithoutLastWord(string) " {{{
    let result = substitute(a:string, '\v(\S+)\s+\S+$', '\1', '')

    if result == a:string
        let result = ""
    endif

    return result
endfunction " }}}

function! s:CanReturn(choice) " {{{
    return len(a:choice)
endfunction " }}}

function! getline#GetLine(prompt, get_status, default) " {{{
    let line = ""
    let [choice, status] = call(a:get_status, [line])

    let displayed = a:prompt . line . status
    call s:Echo(displayed)
    call s:Echo("\r" . strpart(displayed, 0, strlen(a:prompt) + strlen(line)))

    while 1
        let c = getchar()
        if c == 27 " <Esc>
            call s:ClearLine(displayed)
            return [a:default, '<Esc>']
        endif

        if type(c) == type(0)
            if c == 13 " <Enter>
                if s:CanReturn(choice)
                    call s:ClearLine(displayed)
                    return [choice, '<CR>']
                endif
            elseif c == 21 " <C-U>
                let line = ""
            elseif c == 23 " <C-W>
                let line = s:WithoutLastWord(line)
            elseif c == 1 " <C-a>
                continue
            elseif c == 4 " <C-d>
                continue
            elseif c == 5 " <C-e>
                continue
            elseif c == 9
                if s:CanReturn(choice)
                    call s:ClearLine(displayed)
                    return [choice, '<Tab>']
                endif
            elseif c == 19 " <C-s>
                if s:CanReturn(choice)
                    call s:ClearLine(displayed)
                    return [choice, '<C-S>']
                endif
            elseif c == 20 " <C-t>
                if s:CanReturn(choice)
                    call s:ClearLine(displayed)
                    return [choice, '<C-T>']
                endif
            elseif c == 22 " <C-v>
                if s:CanReturn(choice)
                    call s:ClearLine(displayed)
                    return [choice, '<C-V>']
                endif
            else
                let line .= nr2char(c)
            endif
        elseif type(c) == type("")
            if c == "\x80kb" " <BS>
                " Remove last character of input
                if empty(line)
                    call s:ClearLine(displayed)
                    return [a:default, '<BS>']
                else
                    let line = strpart(line, 0, strlen(line)-1)
                endif
            endif
        endif

        call s:ClearLine(displayed)
        let [choice, status] = call(a:get_status, [line])
        let displayed = a:prompt . line . status
        call s:Echo("\r" . displayed)
        call s:Echo("\r" . strpart(displayed, 0, strlen(a:prompt) + strlen(line)))
    endwhile
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
