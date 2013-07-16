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

function! s:GetGlobFiles() " {{{
    let paths = glob('**', 0, 1)
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

    return {'choice': matching[0], 'possible': matching, 'hint': s:RenderHint(matching)}
endfunction " }}}

function! s:FilterUnchoosable(buffers) " {{{
    return filter(a:buffers, 'v:val.IsChoosable()')
endfunction " }}}

function! s:Accept(state, key) " {{{
    if a:state.choice.IsChoosable()
        return {'result': a:state.choice}
    endif

    return {'state': a:state}
endfunction " }}}

function! s:Yank(state, key) " {{{
    call setreg(v:register, a:state.choice.path)
    return {'final': a:state.config.separator . a:state.choice.path}
endfunction " }}}

function! s:GuardedSpace(state, key) " {{{
    if len(a:state.contents) == 0
        return {'state': a:state}
    endif

    if a:state.contents =~ '\v\s$'
        return {'state': a:state}
    endif

    if len(a:state.possible) <= 1
        return {'state': a:state}
    endif

    return {'state': a:state.Transition(a:state.contents . a:key)}
endfunction " }}}

let s:key_handlers =
    \{ 'CTRL-S': s:MakeRef('Accept')
    \, 'CTRL-V': s:MakeRef('Accept')
    \, 'CTRL-T': s:MakeRef('Accept')
    \, 'CTRL-I': s:MakeRef('Accept')
    \, 'CTRL-M': s:MakeRef('Accept')
    \, 'CTRL-Y': s:MakeRef('Yank')
    \, ' ': s:MakeRef('GuardedSpace')
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
        call s:SafeChDir(expand("%:h"))
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

function! chbuf#ChangeFile() " {{{
    return s:Change(s:Prompt(s:GetGlobFiles()))
endfunction " }}}

function! s:ByLen(left, right) " {{{
    return len(a:left) - len(a:right)
endfunction " }}}

function! s:GoodDirs(path) " {{{
    if a:path == '.'
        return 0
    endif

    let type = getftype(a:path)
    if type == 'dir'
        return 1
    elseif type == 'link'
        return getftype(resolve(a:path)) == 'dir'
    else
        return 0
    endif
endfunction " }}}

function! s:ListGlob(glob) " {{{
    let dirs = glob(a:glob, 1, 1)
    call filter(dirs, 's:GoodDirs(v:val)')
    call sort(dirs, 's:ByLen')
    return dirs
endfunction " }}}

function! s:GetDirs() " {{{
    let dirs = s:ListGlob('*')
    return extend(dirs, s:ListGlob('.*'))
endfunction " }}}

function! s:ChangeDirCallback(input) " {{{
    let dirs = copy(w:chbuf_cache)

    for sub in split(a:input)
        call filter(dirs, printf('stridx(v:val, "%s") >= 0', escape(sub, '\')))
    endfor

    if len(dirs) == 0
        return {}
    endif

    return {'choice': dirs[0], 'possible': dirs, 'hint': join(dirs)}
endfunction " }}}

function! s:SafeChDir(dir) " {{{
    execute 'lcd' escape(a:dir, ' ')
endfunction " }}}

function! s:ChSeg(state, key) " {{{
    call s:SafeChDir(a:state.choice)
    let w:chbuf_cache = s:GetDirs()
    return {'state': a:state.Transition('')}
endfunction " }}}

function! s:AcceptDir(state, key) " {{{
    return {'result': a:state.choice}
endfunction " }}}

function! s:YankDir(state, key) " {{{
    let full_path = getcwd() . s:escaped_path_seg_sep . a:state.choice
    call setreg(v:register, full_path)
    return {'final': a:state.config.separator . full_path}
endfunction " }}}

let s:chdir_key_handlers =
    \{ 'CTRL-I': s:MakeRef('ChSeg')
    \, 'CTRL-S': s:MakeRef('AcceptDir')
    \, 'CTRL-V': s:MakeRef('AcceptDir')
    \, 'CTRL-T': s:MakeRef('AcceptDir')
    \, 'CTRL-M': s:MakeRef('AcceptDir')
    \, 'CTRL-Y': s:MakeRef('YankDir')
    \, ' ': s:MakeRef('GuardedSpace')
    \}

function! chbuf#ChangeDir() " {{{
    let w:chbuf_cache = s:GetDirs()
    let result = getline#GetLineReactivelyOverrideKeys(s:MakeRef('ChangeDirCallback'), s:chdir_key_handlers)
    unlet w:chbuf_cache
    if !has_key(result, 'value')
        return
    endif

    if result.key == 'CTRL-M'
        call s:SafeChDir(result.value)
    elseif result.key == 'CTRL-T'
        execute 'silent' 'tabedit' result.value
    elseif result.key == 'CTRL-S'
        execute 'silent' 'split' result.value
    elseif result.key == 'CTRL-V'
        execute 'silent' 'vsplit' result.value
    endif
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
