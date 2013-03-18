" TODO Include v:oldfiles in buffers list
" TODO Make <C-s>, <C-v> and <C-t> open splits or tab respectively for selected buffer


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

function! BufferFromNumber(number, name, score) " {{{
    return {'number': a:number, 'name': a:name, 'score': a:score, 'basename': split(a:name, s:directory_separator)[-1], 'switch': function('SwitchToNumber')}
endfunction " }}}

function! CurrentBuffer() " {{{
    return BufferFromNumber(bufnr('%'), bufname('%'), 0)
endfunction " }}}

function! SwitchToPath() dict " {{{
    execute 'silent' 'edit' self.path
endfunction " }}}

function! BufferFromPath(path) " {{{
    return {'switch': function('SwitchToPath')}
endfunction " }}}

function! ScoredBuffers() " {{{
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

        if buffer == bufnr('#')
            let score += 10000
        endif

        let name = bufname(buffer)

        if name == ''
            continue
        endif

        call add(result, BufferFromNumber(buffer, name, score))
    endfor

    return result
endfunction " }}}

function! CompareScores(left, right) " {{{
    if a:left.score > a:right.score
        return -1
    elseif a:left.score == a:right.score
        return 0
    else
        return 1
    endif
endfunction " }}}

function! GetSortedBuffers() " {{{
    return sort(ScoredBuffers(), 'CompareScores')
endfunction " }}}

function! FilterBuffersMatching(input, buffers) " {{{
    let input = tolower(a:input)
    return filter(a:buffers, printf('stridx(tolower(v:val.name), "%s") >= 0', escape(input, '"')))
endfunction " }}}

function! MakeChoicesString(buffers) " {{{
    let names = map(copy(a:buffers), 'v:val.name')
    let choices = s:choices_string . join(names)
    return choices
endfunction " }}}

function! BufferNameCallback(input) " {{{
    let buffers = FilterBuffersMatching(a:input, GetSortedBuffers())

    if len(buffers) == 0
        return [CurrentBuffer(), '']
    endif

    return [buffers[0], MakeChoicesString(buffers)]
endfunction " }}}

function! PromptBuffer() " {{{
    return getline#GetLine(s:prompt_string, 'BufferNameCallback', CurrentBuffer())
endfunction " }}}

function! chbuf#SwitchBuffer() " {{{
    let buffer = PromptBuffer()
    call buffer.switch()
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
