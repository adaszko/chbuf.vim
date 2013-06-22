let s:save_cpo = &cpo
set cpo&vim


if has('unix')
    let s:directory_separator = '/'
else
    let s:directory_separator = '\\'
endif

function! chbuf#SwitchToNumber() dict " {{{
    execute 'silent' 'buffer' self.number
endfunction " }}}

function! chbuf#SwitchToNumberLCD() dict " {{{
    execute 'silent' 'buffer' self.number
    execute 'lcd' expand("%:h")
endfunction " }}}

function! chbuf#NumberChoosable() dict " {{{
    return 1
endfunction " }}}

function! s:BufferFromNumber(number, name) " {{{
    let path = expand('#' . a:number . ':p')
    return { 'number': a:number
          \, 'path': path
          \, 'name': a:name
          \, 'switch': function('chbuf#SwitchToNumber')
          \, 'switchlcd': function('chbuf#SwitchToNumberLCD')
          \, 'IsChoosable': function('chbuf#NumberChoosable')
          \}
endfunction " }}}

function! chbuf#SwitchToPath() dict " {{{
    execute 'silent' 'edit' self.path
endfunction " }}}

function! chbuf#SwitchToPathLCD() dict " {{{
    execute 'silent' 'edit' self.path
    execute 'lcd' expand("%:h")
endfunction " }}}

function! chbuf#PathChoosable() dict " {{{
    return filereadable(expand(self.path))
endfunction " }}}

function! s:BufferFromPath(path) " {{{
    return { 'path': expand(a:path)
          \, 'switch': function('chbuf#SwitchToPath')
          \, 'switchlcd': function('chbuf#SwitchToPathLCD')
          \, 'IsChoosable': function('chbuf#PathChoosable')
          \}
endfunction " }}}

function! s:GetBuffers() " {{{
    let result = []

    let oldfiles = map(copy(v:oldfiles), 's:BufferFromPath(v:val)')
    call extend(result, oldfiles)

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

        call add(result, s:BufferFromNumber(buffer, name))
    endfor

    let unique = {}
    for buf in result
        let unique[buf['path']] = buf
    endfor

    return values(unique)
endfunction " }}}

function! s:SetUniqueSuffixes(node, cand, accum) " {{{
    let children = keys(a:node)

    let cand = copy(a:cand)
    let accum = copy(a:accum)

    if len(children) > 1
        call extend(cand, accum)
        let accum = []
    endif

    for seg in children
        let val = a:node[seg]
        if type(val) == type([])
            let buf = val[0]
            let buf['suffix'] = join(reverse(cand), s:directory_separator)
        elseif len(children) == 1
            call add(accum, seg)
            call s:SetUniqueSuffixes(val, cand, accum)
        else
            call add(cand, seg)
            call s:SetUniqueSuffixes(val, cand, accum)
            call remove(cand, -1)
        endif
        unlet val
    endfor
endfunction " }}}

function! s:BySuffixLen(left, right) " {{{
    return strlen(a:left.suffix) - strlen(a:right.suffix)
endfunction " }}}

function! s:ShortestUniqueSuffixes(buffers) " {{{
    let trie = {}
    for buf in a:buffers
        " Special case for e.g. fugitive-like paths with multiple adjacent separators
        let sep = printf('\V%s\+', s:directory_separator)
        let segments = reverse(split(buf['path'], sep))

        " ASSUMPTION: None of the segments list is a prefix of another
        let node = trie
        for i in range(len(segments)-1)
            let seg = segments[i]
            if !has_key(node, seg)
                let node[seg] = {}
            endif
            let node = node[seg]
        endfor
        let seg = segments[-1]
        let node[seg] = [buf]
    endfor

    call s:SetUniqueSuffixes(trie, [], [])
    call sort(a:buffers, 's:BySuffixLen')
    return a:buffers
endfunction " }}}

function! s:FilterBuffersMatching(input, buffers) " {{{
    let result = a:buffers

    if &ignorecase
        for needle in split(tolower(a:input), '\v\s+')
            call filter(result, printf('stridx(tolower(v:val.suffix), "%s") >= 0', escape(needle, '\\"')))
        endfor
    else
        for needle in split(a:input, '\v\s+')
            call filter(result, printf('stridx(v:val.suffix, "%s") >= 0', escape(needle, '\\"')))
        endfor
    endif

    return result
endfunction " }}}

function! s:FilterIgnoredBuffers(buffers) " {{{
    if exists('g:chbuf_ignore_pattern')
        call filter(a:buffers, "v:val.path !~ '" . escape(g:chbuf_ignore_pattern, "'") . "'")
    endif

    return a:buffers
endfunction " }}}

function! s:RenderChoices(buffers) " {{{
    return join(map(copy(a:buffers), 'v:val.suffix'))
endfunction " }}}

function! chbuf#GetLineCallback(input) " {{{
    let matching = s:FilterBuffersMatching(a:input, copy(w:chbuf_cache))

    if len(matching) == 0
        return []
    endif

    return [matching[0], s:RenderChoices(matching)]
endfunction " }}}

function! s:PromptBuffer() " {{{
    let w:chbuf_cache = s:ShortestUniqueSuffixes(s:FilterIgnoredBuffers(s:GetBuffers()))
    let result = getline#GetLine('chbuf#GetLineCallback')
    unlet w:chbuf_cache
    return result
endfunction " }}}

function! chbuf#SwitchBuffer() " {{{
    let choice = s:PromptBuffer()
    if len(choice) == 0
        return
    endif
    let [buffer, method] = choice

    if method == '<CR>'
        call buffer.switch()
    elseif method == '<S-CR>'
        call buffer.switch()
    elseif method == '<Tab>'
        call buffer.switchlcd()
    elseif method == '<C-T>'
        execute 'tabnew'
        call buffer.switch()
    elseif method == '<C-S>'
        execute 'split'
        call buffer.switch()
    elseif method == '<C-V>'
        execute 'vsplit'
        call buffer.switch()
    endif
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
