if exists('g:autoloaded_chbuf') || &compatible || v:version < 700
    finish
endif

let g:autoloaded_chbuf = 1

let s:save_cpo = &cpo
set cpo&vim


" {{{ Data Source: Filenames
if !exists('+shellslash') || &shellslash
    let s:unescaped_path_seg_sep = '/'
    let s:escaped_path_seg_sep = '/'
else
    let s:unescaped_path_seg_sep = '\'
    let s:escaped_path_seg_sep = '\\'
endif

let s:case_sensitive_file_system = has('unix')

function! s:get_script_id() " {{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_get_script_id$')
endfun " }}}

let s:script_id = s:get_script_id()

function! s:make_ref(name) " {{{
    return function(printf('<SNR>%s_%s', s:script_id, a:name))
endfunction " }}}

function! s:switch_to_number() dict " {{{
    execute 'silent' 'buffer' self.number
endfunction " }}}

function! s:is_number_choosable() dict " {{{
    return 1
endfunction " }}}

function! s:buffer_from_number(number, name) " {{{
    let path = expand('#' . a:number . ':p')
    return { 'number':          a:number
          \, 'path':            path
          \, 'name':            a:name
          \, 'switch':          s:make_ref('switch_to_number')
          \, 'is_choosable':    s:make_ref('is_number_choosable')
          \}
endfunction " }}}

function! s:switch_to_path() dict " {{{
    execute 'silent' 'edit' self.path
endfunction " }}}

function! s:path_choosable() dict " {{{
    return filereadable(self.path)
endfunction " }}}

function! s:buffer_from_path(path) " {{{
    return { 'path':            expand(a:path)
          \, 'switch':          s:make_ref('switch_to_path')
          \, 'is_choosable':    s:make_ref('path_choosable')
          \}
endfunction " }}}

function! s:buffer_from_relative_path(relative) " {{{
    return { 'relative':    a:relative
          \, 'path':        join([getcwd(), a:relative], s:unescaped_path_seg_sep)
          \, 'switch':      s:make_ref('switch_to_path')
          \, 'is_choosable': s:make_ref('path_choosable')
          \}
endfunction " }}}

function! s:get_glob_files() " {{{
    let paths = glob('**', 0, 1)
    call filter(paths, 'getftype(v:val) =~# "\\v(file|link)"')
    call map(paths, 's:buffer_from_relative_path(v:val)')
    return paths
endfunction " }}}

function! s:get_old_files(ignored_pattern) " {{{
    let result = map(copy(v:oldfiles), "fnamemodify(v:val, ':p')")
    let result = map(result, 's:buffer_from_path(v:val)')

    if !a:ignored_pattern
        return result
    endif

    return filter(result, "v:val.path !~ '" . escape(a:ignored_pattern, "'") . "'")
endfunction " }}}

function! s:get_buffers(ignored_pattern) " {{{
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

        let buf = s:buffer_from_number(buffer, name)
        if buf.path =~ a:ignored_pattern
            continue
        endif

        call add(result, buf)
    endfor

    return result
endfunction " }}}

function! s:uniq_paths(buffers) " {{{
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

function! s:set_unique_suffixes(node, cand, accum) " {{{
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
            call s:set_unique_suffixes(val, cand, accum)
        else
            call add(cand, seg)
            call s:set_unique_suffixes(val, cand, accum)
            call remove(cand, -1)
        endif
        unlet val
    endfor
endfunction " }}}

function! s:by_suffix_len(left, right) " {{{
    return strlen(a:left.suffix) - strlen(a:right.suffix)
endfunction " }}}

function! s:shortest_unique_suffixes(buffers) " {{{
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

    call s:set_unique_suffixes(trie, [], [])
    call sort(a:buffers, 's:by_suffix_len')
    return a:buffers
endfunction " }}}

function! s:filter_matching(input, buffers) " {{{
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

function! s:render_hint(buffers) " {{{
    if len(a:buffers) == 1
        return a:buffers[0].path
    else
        return join(map(copy(a:buffers), 'v:val.suffix'))
    endif
endfunction " }}}

function! s:get_line_callback(input) " {{{
    let matching = s:filter_matching(a:input, copy(w:chbuf_cache))

    if len(matching) == 0
        return {}
    endif

    return {'choice': matching[0], 'possible': matching, 'hint': s:render_hint(matching)}
endfunction " }}}

function! s:filter_unchoosable(buffers) " {{{
    return filter(a:buffers, 'v:val.is_choosable()')
endfunction " }}}

function! s:accept(state, key) " {{{
    if a:state.choice.is_choosable()
        return {'result': a:state.choice}
    endif

    return {'state': a:state}
endfunction " }}}

function! s:yank(state, key) " {{{
    call setreg(v:register, a:state.choice.path)
    return {'final': a:state.config.separator . a:state.choice.path}
endfunction " }}}

function! s:guarded_space(state, key) " {{{
    if len(a:state.contents) == 0
        return {'state': a:state}
    endif

    if a:state.contents =~ '\v\s$'
        return {'state': a:state}
    endif

    if len(a:state.possible) <= 1
        return {'state': a:state}
    endif

    return {'state': a:state.transition(a:state.contents . a:key)}
endfunction " }}}

let s:key_handlers =
    \{ 'CTRL-S': s:make_ref('accept')
    \, 'CTRL-V': s:make_ref('accept')
    \, 'CTRL-T': s:make_ref('accept')
    \, 'CTRL-I': s:make_ref('accept')
    \, 'CTRL-M': s:make_ref('accept')
    \, 'CTRL-Y': s:make_ref('yank')
    \, ' ': s:make_ref('guarded_space')
    \}

function! s:prompt(buffers) " {{{
    let w:chbuf_cache = a:buffers
    if !has('win32')
        let w:chbuf_cache = s:filter_unchoosable(w:chbuf_cache)
    endif
    let w:chbuf_cache = s:shortest_unique_suffixes(w:chbuf_cache)

    let result = getline#get_line_reactively_override_keys(s:make_ref('get_line_callback'), s:key_handlers)

    unlet w:chbuf_cache
    return result
endfunction " }}}

function! s:change(result) " {{{
    if !has_key(a:result, 'value')
        return
    endif
    let buffer = a:result.value
    let key = a:result.key

    if key == 'CTRL-M'
        call buffer.switch()
    elseif key == 'CTRL-I'
        call buffer.switch()
        call s:safe_chdir(expand("%:h"))
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

function! s:choose_path_interactively(path_objects) " {{{
    return s:change(s:prompt(a:path_objects))
endfunction " }}}

function! chbuf#change_buffer(ignored_pattern) " {{{
    return s:choose_path_interactively(s:get_buffers(a:ignored_pattern))
endfunction " }}}

function! chbuf#change_mixed(ignored_pattern) " {{{
    let buffers = extend(s:get_buffers(a:ignored_pattern), s:get_old_files(a:ignored_pattern))
    return s:choose_path_interactively(s:uniq_paths(buffers))
endfunction " }}}

function! chbuf#change_file() " {{{
    return s:choose_path_interactively(s:get_glob_files())
endfunction " }}}
" }}}

" {{{ Data Source: Directories
function! s:by_len(left, right) " {{{
    return len(a:left) - len(a:right)
endfunction " }}}

function! s:good_dirs(path) " {{{
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

function! s:list_glob(glob) " {{{
    let dirs = glob(a:glob, 1, 1)
    call filter(dirs, 's:good_dirs(v:val)')
    call sort(dirs, 's:by_len')
    return dirs
endfunction " }}}

function! s:get_dirs() " {{{
    let dirs = s:list_glob('*')
    return extend(dirs, s:list_glob('.*'))
endfunction " }}}

function! s:change_dir_callback(input) " {{{
    let dirs = copy(w:chbuf_cache)

    for sub in split(a:input)
        call filter(dirs, printf('stridx(v:val, "%s") >= 0', escape(sub, '\')))
    endfor

    if len(dirs) == 0
        return {}
    endif

    return {'choice': dirs[0], 'possible': dirs, 'hint': join(dirs)}
endfunction " }}}

function! s:safe_chdir(dir) " {{{
    execute 'lcd' escape(a:dir, ' ')
endfunction " }}}

function! s:ch_seg(state, key) " {{{
    call s:safe_chdir(a:state.choice)
    let w:chbuf_cache = s:get_dirs()
    return {'state': a:state.transition('')}
endfunction " }}}

function! s:accept_dir(state, key) " {{{
    return {'result': a:state.choice}
endfunction " }}}

function! s:yank_dir(state, key) " {{{
    let full_path = getcwd() . s:escaped_path_seg_sep . a:state.choice
    call setreg(v:register, full_path)
    return {'final': a:state.config.separator . full_path}
endfunction " }}}

let s:chdir_key_handlers =
    \{ 'CTRL-I': s:make_ref('ch_seg')
    \, 'CTRL-S': s:make_ref('accept_dir')
    \, 'CTRL-V': s:make_ref('accept_dir')
    \, 'CTRL-T': s:make_ref('accept_dir')
    \, 'CTRL-M': s:make_ref('accept_dir')
    \, 'CTRL-Y': s:make_ref('yank_dir')
    \, ' ': s:make_ref('guarded_space')
    \}

function! chbuf#change_directory() " {{{
    let w:chbuf_cache = s:get_dirs()
    let result = getline#get_line_reactively_override_keys(s:make_ref('change_dir_callback'), s:chdir_key_handlers)
    unlet w:chbuf_cache
    if !has_key(result, 'value')
        return
    endif

    if result.key == 'CTRL-M'
        call s:safe_chdir(result.value)
    elseif result.key == 'CTRL-T'
        execute 'silent' 'tabedit' result.value
    elseif result.key == 'CTRL-S'
        execute 'silent' 'split' result.value
    elseif result.key == 'CTRL-V'
        execute 'silent' 'vsplit' result.value
    endif
endfunction " }}}
" }}}

" {{{ Data Source: External Tools
function! chbuf#spotlight_query_completion(arglead, cmdline, cursorpos) " {{{
    " https://developer.apple.com/library/mac/#documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html#//apple_ref/doc/uid/TP40001849-CJBEJBHH
    let keywords =
        \[ 'kMDItemFSName'
        \, 'kMDItemDisplayName'
        \, 'kMDItemFSCreationDate'
        \, 'kMDItemFSContentChangeDate'
        \, 'kMDItemContentTypeTree'
        \, 'kMDItemFSSize'
        \, '$time.now'
        \, '$time.today'
        \, '$time.yesterday'
        \, '$time.this_week'
        \, '$time.this_month'
        \, '$time.this_year'
        \, '$time.iso'
        \, 'InRange'
        \]
    return join(keywords, "\n")
endfunction " }}}

function! s:query_spotlight(query) " {{{
    let paths = split(system(printf("mdfind -onlyin %s '%s'", shellescape(getcwd()), escape(a:query, "'"))), "\n")
    return map(paths, 's:buffer_from_path(v:val)')
endfunction " }}}

function! chbuf#change_file_spotlight(query) " {{{
    return s:choose_path_interactively(s:query_spotlight(a:query))
endfunction " }}}
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
