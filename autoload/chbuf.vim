let s:save_cpo = &cpo
set cpo&vim


function! SplitPath(path) " {{{
    if has('unix')
        return split(a:path, '/')
    else
        return split(a:path, '\\')
    endif
endfunction " }}}
function! ScoredBuffers() " {{{
    let result = []

    for buffer in range(1, bufnr('$'))
        let score = 0

        if !bufexists(buffer)
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

        if buflisted(buffer)
            let score += 1000
        else
            let score -= 1000
        endif

        let basename = SplitPath(name)[-1]

        call add(result, {'score': score, 'number': buffer, 'name': name, 'basename': basename})
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
function! SortBuffers(buffers) " {{{
    return sort(a:buffers, 'CompareScores')
endfunction " }}}
function! MatchBuffer(input) " {{{
    let buffers = SortBuffers(ScoredBuffers())

    call filter(buffers, printf('v:val.name =~ "%s"', escape(a:input, '"')))

    return buffers
endfunction " }}}
function! BufferNameCallback(input) " {{{
    let buffers = MatchBuffer(a:input)

    if len(buffers) == 0
        return [bufnr('%'), '']
    endif

    let basenames = map(copy(buffers), 'v:val.basename')
    let caption = ' ↦ ' . join(basenames)
    return [buffers[0].number, caption]
endfunction " }}}
function! PromptBuffer() " {{{
    return getline#GetLine('∷ ', 'BufferNameCallback')
endfunction " }}}
function! chbuf#SwitchBuffer() " {{{
    execute 'silent' 'buffer' PromptBuffer()
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
