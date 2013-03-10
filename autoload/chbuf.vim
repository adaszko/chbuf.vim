" DONE Show only path basenames as suggestions
" TODO Truncate choices on &columns
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


function! BufferNameCallback(input) " {{{
    let buffers = MatchBuffers(a:input)

    if len(buffers) == 0
        return ''
    endif

    let caption = join(buffers)
    return ' ↦ ' . caption
endfunction " }}}


function! chbuf#PromptBuffer() " {{{
    let name = getline#GetLine('∷ ', 'BufferNameCallback')
    execute 'silent' 'buffer' name
    return name
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
