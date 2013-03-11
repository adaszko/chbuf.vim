" TODO There may be two buffers of the same name --- pick the first one
" TODO Tab-completion of longest common prefix
" TODO Make Tab behave as enter when longest common prefix is unambiguous
" TODO Score higher subsequences occuring after directory separator
" TODO Make functions script-private once they are sufficiently tested
" DONE Score expand('#') file highest and select it initially
" DONE Filter out current buffer in choices
" DONE Show only path basenames as suggestions
" DONE Get rid of "Press ENTER..." message
" DONE Truncate choices on &columns
" IDEA Perhaps <S-Return> should also :lcd into file's directory


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

    for buffer in range(bufnr('$'))
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

        let score = 0

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

    call map(buffers, 'v:val.basename')

    return buffers
endfunction " }}}
function! LongestPrefixFitting(elems, length) " {{{
    let curlen = 0

    for i in range(len(a:elems))
        let curlen += strlen(a:elems[i])
        if curlen > a:length
            if i == 0
                return []
            else
                return a:elems[:i-1]
            endif
        endif
    endfor

    return a:elems
endfunction " }}}
function! BufferNameCallback(input) " {{{
    let buffers = MatchBuffer(a:input)
    let cols = &columns - len(buffers) - 1 - 1
    let buffers = LongestPrefixFitting(buffers, cols)

    if len(buffers) == 0
        return ''
    endif

    let caption = join(buffers)
    return ' ↦ ' . caption
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
