let s:save_cpo = &cpo
set cpo&vim


function! WithoutLastWord(string) " {{{
    let result = substitute(a:string, '\v(\S+)\s+\S+$', '\1', '')

    if result == a:string
        let result = ""
    endif

    return result
endfunction " }}}


function! GetLine(prompt) " {{{
    let result = ""

    let displayed = a:prompt
    echon displayed

    while 1
	let c = getchar()
	if c == 27 " escape
	    return ""
	endif

	if type(c) == type(0)
	    if c == 13 " enter
		break
            elseif c == 21 " ^U
                let result = ""
	    elseif c == 23 " ^W
		let result = WithoutLastWord(result)
	    else
		let result .= nr2char(c)
	    endif
	elseif type(c) == type("")
	    if c == "\x80kb" " backspace
		" Remove last character of input
		if empty(result)
		    echon "\r" . repeat(' ', strlen(displayed))
		    return ""
		else
		    let result = strpart(result, 0, strlen(result)-1)
		endif
	    endif
	endif

        " Erase previous contents
        echon "\r" . repeat(' ', strlen(displayed))

        " Display updated contents
        let displayed = a:prompt . result
        echon "\r" . displayed
    endwhile

    return result
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
