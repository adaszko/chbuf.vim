let s:save_cpo = &cpo
set cpo&vim


if has('unix')
    let s:directory_separator = '/'
else
    let s:directory_separator = '\\'
endif

if has('unix') && (&termencoding ==# 'utf-8' || &encoding ==# 'utf-8')
    let s:prompt_string = '∷ '
    let s:choices_string = ' ↦ '
else
    let s:prompt_string = ':: '
    let s:choices_string = ' => '
endif

function! SwitchToNumber() dict " {{{
    execute 'silent' 'buffer' self.number
endfunction " }}}

function! BufferFromNumber(number, name) " {{{
    return {'number': a:number, 'name': a:name, 'basename': split(a:name, s:directory_separator)[-1], 'switch': function('SwitchToNumber')}
endfunction " }}}

function! DummyBuffer() " {{{
    return {}
endfunction " }}}

function! SwitchToPath() dict " {{{
    execute 'silent' 'edit' self.path
endfunction " }}}

function! BufferFromPath(path) " {{{
    let name = split(a:path, s:directory_separator)[-1]
    return {'path': a:path, 'name': name, 'switch': function('SwitchToPath')}
endfunction " }}}

function! GetBuffers() " {{{
    let result = []

    for buffer in range(1, bufnr('$'))
        let score = 0

        if !bufexists(buffer)
            continue
        endif

        if !buflisted(buffer)
            continue
        endif

        if buffer == bufnr('%')
            continue
        endif

        let name = bufname(buffer)

        if name == ''
            continue
        endif

        call add(result, BufferFromNumber(buffer, name))
    endfor

    let oldfiles = map(copy(v:oldfiles), 'BufferFromPath(v:val)')
    call extend(result, oldfiles)

    return result
endfunction " }}}

function! FilterBuffersMatching(input, buffers) " {{{
    let input = tolower(a:input)
    let needles = split(input, '\v\s+')

    let result = a:buffers
    for needle in needles
        call filter(result, printf('stridx(tolower(v:val.name), "%s") >= 0', escape(needle, '"')))
    endfor

    return result
endfunction " }}}

function! MakeChoicesString(buffers) " {{{
    let names = map(copy(a:buffers), 'v:val.name')
    let choices = s:choices_string . join(names)
    return choices
endfunction " }}}

function! BufferNameCallback(input) " {{{
    let buffers = FilterBuffersMatching(a:input, GetBuffers())

    if len(buffers) == 0
        return [DummyBuffer(), '']
    endif

    return [buffers[0], MakeChoicesString(buffers)]
endfunction " }}}

function! PromptBuffer() " {{{
    return getline#GetLine(s:prompt_string, 'BufferNameCallback', DummyBuffer())
endfunction " }}}

function! chbuf#SwitchBuffer() " {{{
    let buffer = PromptBuffer()
    if has_key(buffer, 'switch')
        call buffer.switch()
    endif
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
