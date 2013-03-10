" DONE Show only path basenames as suggestions
" DONE Get rid of "Press ENTER..." message
" DONE Truncate choices on &columns
" TODO There may be two buffers of the same name --- pick the first one
" TODO Tab-completion of longest common prefix
" TODO Filter out current buffer in choices
" TODO Score expand('#') file highest and select it initially
" TODO Make Tab behave as enter when longest common prefix is unambiguous
" TODO Score higher subsequences occuring after directory separator
" TODO Make functions script-private once they are sufficiently tested
" IDEA Perhaps <S-Return> should also :lcd into file's directory


let s:save_cpo = &cpo
set cpo&vim


function! ExistingBuffersNumbers() " {{{
    return filter(range(bufnr('$')), 'bufexists(v:val)')
endfunction " }}}


function! SplitPath(path) " {{{
    return split(a:path, '/')
endfunction " }}}


function! ScoredBuffers() " {{{
    let buffers = ExistingBuffersNumbers()
    let listed = filter(copy(buffers), 'buflisted(v:val)')
    let unlisted = filter(copy(buffers), '!buflisted(v:val)')
    return extend(listed, unlisted)
endfunction " }}}


function! MatchBuffers(input) " {{{
    let buffers = ScoredBuffers()

    call map(buffers, 'bufname(v:val)')

    call filter(buffers, 'v:val != ""')

    call map(buffers, 'SplitPath(v:val)[-1]')

    call filter(buffers, printf('v:val =~ "%s"', escape(a:input, '"')))

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
    let buffers = MatchBuffers(a:input)
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
