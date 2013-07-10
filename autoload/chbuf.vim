if exists('g:autoloaded_chbuf') || &compatible || v:version < 700
    finish
endif

let g:autoloaded_chbuf = 1

let s:save_cpo = &cpo
set cpo&vim


if !exists('+shellslash') || &shellslash
    let s:unescaped_path_seg_sep = '/'
    let s:escaped_path_seg_sep = '/'
else
    let s:unescaped_path_seg_sep = '\'
    let s:escaped_path_seg_sep = '\\'
endif

let s:case_sensitive_file_system = has('unix')

function! s:SID() " {{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun " }}}

let s:sid = s:SID()

function! s:MakeRef(name) " {{{
    return function(printf('<SNR>%s_%s', s:sid, a:name))
endfunction " }}}

function! s:SwitchToNumber() dict " {{{
    execute 'silent' 'buffer' self.number
endfunction " }}}

function! s:NumberChoosable() dict " {{{
    return 1
endfunction " }}}

function! s:BufferFromNumber(number, name) " {{{
    let path = expand('#' . a:number . ':p')
    return { 'number':      a:number
          \, 'path':        path
          \, 'name':        a:name
          \, 'switch':      s:MakeRef('SwitchToNumber')
          \, 'IsChoosable': s:MakeRef('NumberChoosable')
          \}
endfunction " }}}

function! s:SwitchToPath() dict " {{{
    execute 'silent' 'edit' self.path
endfunction " }}}

function! s:PathChoosable() dict " {{{
    return filereadable(self.path)
endfunction " }}}

function! s:BufferFromPath(path) " {{{
    return { 'path':        expand(a:path)
          \, 'switch':      s:MakeRef('SwitchToPath')
          \, 'IsChoosable': s:MakeRef('PathChoosable')
          \}
endfunction " }}}

function! s:BufferFromRelativePath(relative) " {{{
    return { 'relative':    a:relative
          \, 'path':        join([getcwd(), a:relative], s:unescaped_path_seg_sep)
          \, 'switch':      s:MakeRef('SwitchToPath')
          \, 'IsChoosable': s:MakeRef('PathChoosable')
          \}
endfunction " }}}

function! s:GetGlobFiles(glob_pattern) " {{{
    let paths = glob(a:glob_pattern, 0, 1)
    call filter(paths, 'getftype(v:val) =~# "\\v(file|link)"')
    call map(paths, 's:BufferFromRelativePath(v:val)')
    return paths
endfunction " }}}

function! s:GetOldFiles(ignored_pattern) " {{{
    let result = map(copy(v:oldfiles), 's:BufferFromPath(v:val)')
    return filter(result, "v:val.path !~ '" . escape(a:ignored_pattern, "'") . "'")
endfunction " }}}

function! s:GetBuffers(ignored_pattern) " {{{
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

        let buf = s:BufferFromNumber(buffer, name)
        if buf.path =~ a:ignored_pattern
            continue
        endif

        call add(result, buf)
    endfor

    return result
endfunction " }}}

function! s:UniqPaths(buffers) " {{{
    let unique = {}

    for buf in a:buffers
        if len(buf['path']) == 0
            continue
        endif

        if s:case_sensitive_file_system
            let unique[buf['path']] = buf
        else
            let unique[tolower(buf['path'])] = buf
        endif
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
            let buf['suffix'] = join(reverse(cand), s:unescaped_path_seg_sep)
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
        " Paths are allowed to have multiple adjacent segment separators
        let sep = printf('\V%s\+', s:escaped_path_seg_sep)
        let path = s:case_sensitive_file_system ? buf['path'] : tolower(buf['path'])
        let segments = reverse(split(path, sep))

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

function! s:FilterMatching(input, buffers) " {{{
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

function! s:RenderHint(buffers) " {{{
    if len(a:buffers) == 1
        return a:buffers[0].path
    else
        return join(map(copy(a:buffers), 'v:val.suffix'))
    endif
endfunction " }}}

function! s:GetLineCallback(input) " {{{
    let matching = s:FilterMatching(a:input, copy(w:chbuf_cache))

    if len(matching) == 0
        return {}
    endif

    return {'choice': matching[0], 'possible': s:RenderHint(matching)}
endfunction " }}}

function! s:FilterUnchoosable(buffers) " {{{
    return filter(a:buffers, 'v:val.IsChoosable()')
endfunction " }}}

function! s:Accept(state) " {{{
    if a:state.choice.IsChoosable()
        return {'result': a:state.choice}
    endif

    return {'state': a:state}
endfunction " }}}

function! s:Yank(state) " {{{
    call setreg(v:register, a:state.choice.path)
    return {'final': a:state.config.separator . a:state.choice.path}
endfunction " }}}

let s:key_handlers =
    \{ 'CTRL-S': s:MakeRef('Accept')
    \, 'CTRL-V': s:MakeRef('Accept')
    \, 'CTRL-T': s:MakeRef('Accept')
    \, 'CTRL-I': s:MakeRef('Accept')
    \, 'CTRL-M': s:MakeRef('Accept')
    \, 'CTRL-Y': s:MakeRef('Yank')
    \}

function! s:Prompt(buffers) " {{{
    let w:chbuf_cache = a:buffers
    if !has('win32')
        let w:chbuf_cache = s:FilterUnchoosable(w:chbuf_cache)
    endif
    let w:chbuf_cache = s:ShortestUniqueSuffixes(w:chbuf_cache)

    let result = getline#GetLineReactivelyOverrideKeys(s:MakeRef('GetLineCallback'), s:key_handlers)

    unlet w:chbuf_cache
    return result
endfunction " }}}

function! s:Change(result) " {{{
    if !has_key(a:result, 'value')
        return
    endif
    let buffer = a:result.value
    let key = a:result.key

    if key == 'CTRL-M'
        call buffer.switch()
    elseif key == 'CTRL-I'
        call buffer.switch()
        execute 'lcd' expand("%:h")
    elseif key == 'CTRL-T'
        execute 'tabnew'
        call buffer.switch()
    elseif key == 'CTRL-S'
        execute 'split'
        call buffer.switch()
    elseif key == 'CTRL-V'
        execute 'vsplit'
        call buffer.switch()
    endif
endfunction " }}}

function! chbuf#ChangeBuffer(ignored_pattern) " {{{
    return s:Change(s:Prompt(s:GetBuffers(a:ignored_pattern)))
endfunction " }}}

function! chbuf#ChangeOldFile(ignored_pattern) " {{{
    return s:Change(s:Prompt(s:GetOldFiles(ignored_pattern)))
endfunction " }}}

function! chbuf#ChangeBufferOldFile(ignored_pattern) " {{{
    let buffers = extend(s:GetBuffers(a:ignored_pattern), s:GetOldFiles(a:ignored_pattern))
    return s:Change(s:Prompt(s:UniqPaths(buffers)))
endfunction " }}}

function! chbuf#ChangeFile(glob_pattern) " {{{
    return s:Change(s:Prompt(s:GetGlobFiles(a:glob_pattern)))
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
