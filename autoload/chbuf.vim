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
    let path = expand('%:p:h')
    return {'number': a:number, 'path': path, 'name': a:name, 'basename': split(a:name, s:directory_separator)[-1], 'switch': function('SwitchToNumber')}
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

    let oldfiles = map(copy(v:oldfiles), 'BufferFromPath(v:val)')
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

        call add(result, BufferFromNumber(buffer, name))
    endfor

    return result
endfunction " }}}

function! GetUniqueBuffers() " {{{
    let buffers = GetBuffers()

    let unique = {}
    for buf in buffers
        let unique[buf['path']] = buf
    endfor

    return values(unique)
endfunction " }}}

function! SetUniqueSuffixes(node, cand, accum) " {{{
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
            call SetUniqueSuffixes(val, cand, accum)
        else
            call add(cand, seg)
            call SetUniqueSuffixes(val, cand, accum)
            call remove(cand, -1)
        endif
    endfor
endfunction " }}}

function! BySuffixLen(left, right) " {{{
    return strlen(a:left.suffix) - strlen(a:right.suffix)
endfunction " }}}

function! ShortestUniqueSuffixes() " {{{
    let buffers = GetUniqueBuffers()

    let trie = {}
    for buf in buffers
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

    call SetUniqueSuffixes(trie, [], [])
    call sort(buffers, 'BySuffixLen')
    return buffers
endfunction " }}}

function! FilterBuffersMatching(input, buffers) " {{{
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

function! MakeChoicesString(buffers) " {{{
    let names = map(copy(a:buffers), 'v:val.suffix')
    let choices = s:choices_string . join(names)
    return choices
endfunction " }}}

function! BufferNameCallback(input) " {{{
    let buffers = FilterBuffersMatching(a:input, ShortestUniqueSuffixes())

    if len(buffers) == 0
        return [DummyBuffer(), '']
    endif

    return [buffers[0], MakeChoicesString(buffers)]
endfunction " }}}

function! PromptBuffer() " {{{
    return getline#GetLine(s:prompt_string, 'BufferNameCallback', DummyBuffer())
endfunction " }}}

function! chbuf#SwitchBuffer() " {{{
    let [buffer, method] = PromptBuffer()

    if !has_key(buffer, 'switch')
        " DummyBuffer
        return
    endif

    if method == '<Esc>'
        return
    elseif method == '<CR>'
        call buffer.switch()
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
