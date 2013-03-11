" TODO Multiply &columns by &cmdheight


let s:save_cpo = &cpo
set cpo&vim


function! s:Echo(line)
    echon strpart(a:line, 0, &columns-1)
endfunction


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


function! getline#GetLine(prompt, get_status) " {{{
    let line = ""
    let status = call(a:get_status, [line])

    let displayed = a:prompt . line . status
    call s:Echo(displayed)
    call s:Echo("\r" . strpart(displayed, 0, strlen(a:prompt) + strlen(line)))

    while 1
        let c = getchar()
        if c == 27 " escape
            return ""
            call s:ClearLine(displayed)
        endif

        if type(c) == type(0)
            if c == 13 " enter
                break
            elseif c == 21 " ^U
                let line = ""
            elseif c == 23 " ^W
                let line = s:WithoutLastWord(line)
            else
                let line .= nr2char(c)
            endif
        elseif type(c) == type("")
            if c == "\x80kb" " backspace
                " Remove last character of input
                if empty(line)
                    call s:ClearLine(displayed)
                    return ""
                else
                    let line = strpart(line, 0, strlen(line)-1)
                endif
            endif
        endif

        call s:ClearLine(displayed)
        let status = call(a:get_status, [line])
        let displayed = a:prompt . line . status
        call s:Echo("\r" . displayed)
        call s:Echo("\r" . strpart(displayed, 0, strlen(a:prompt) + strlen(line)))
    endwhile

    call s:ClearLine(displayed)
    return line
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
