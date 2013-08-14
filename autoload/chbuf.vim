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

let s:script_name = expand('<sfile>')

function! s:is_file_system_case_sensitive() " {{{
    let ignores_case = filereadable(tolower(s:script_name)) && filereadable(toupper(s:script_name))
    return !ignores_case
endfunction " }}}

let s:case_sensitive_file_system = s:is_file_system_case_sensitive()

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

function! s:set_file_suffix(suffix) dict " {{{
    let self.suffix = a:suffix
endfunction " }}}

function! s:set_dir_suffx(suffix) dict " {{{
    let self.suffix = a:suffix . s:unescaped_path_seg_sep
endfunction " }}}

function! s:buffer_from_number(number, name) " {{{
    let path = expand('#' . a:number . ':p')

    if isdirectory(path)
        let path .= s:unescaped_path_seg_sep
        let set_suf_fn = 'set_dir_suffx'
    else
        let set_suf_fn = 'set_file_suffix'
    endif

    return { 'number':          a:number
          \, 'path':            path
          \, 'name':            a:name
          \, 'switch':          s:make_ref('switch_to_number')
          \, 'is_choosable':    s:make_ref('is_number_choosable')
          \, 'set_suffix':      s:make_ref(set_suf_fn)
          \}
endfunction " }}}

function! s:switch_to_path() dict " {{{
    execute 'silent' 'edit' self.path
endfunction " }}}

function! s:path_choosable() dict " {{{
    return filereadable(self.path) || isdirectory(self.path)
endfunction " }}}

function! s:buffer_from_path(path) " {{{
    let expanded = expand(a:path)

    if isdirectory(expanded)
        let expanded .= s:unescaped_path_seg_sep
        let set_suf_fn = 'set_dir_suffx'
    else
        let set_suf_fn = 'set_file_suffix'
    endif

    return { 'path':            expanded
          \, 'switch':          s:make_ref('switch_to_path')
          \, 'is_choosable':    s:make_ref('path_choosable')
          \, 'set_suffix':      s:make_ref(set_suf_fn)
          \}
endfunction " }}}

function! s:buffer_from_relative_path(relative) " {{{
    let absolute = join([getcwd(), a:relative], s:unescaped_path_seg_sep)

    if isdirectory(absolute)
        let absolute .= s:unescaped_path_seg_sep
        let set_suf_fn = 'set_dir_suffx'
    else
        let set_suf_fn = 'set_file_suffix'
    endif

    return { 'relative':        a:relative
          \, 'path':            absolute
          \, 'switch':          s:make_ref('switch_to_path')
          \, 'is_choosable':    s:make_ref('path_choosable')
          \, 'set_suffix':      s:make_ref(set_suf_fn)
          \}
endfunction " }}}

function! s:GlobList(wildcard, flags) " {{{
    if v:version < 704
        return split(glob(a:wildcard, a:flags), "\n")
    endif

    return glob(a:wildcard, a:flags, 1)
endfunction " }}}

function! s:get_glob_files() " {{{
    let paths = s:GlobList('**', 0)
    call filter(paths, 'getftype(v:val) =~# "\\v(file|link)"')
    call map(paths, 's:buffer_from_relative_path(v:val)')
    return paths
endfunction " }}}

function! s:get_old_files(ignored_pattern) " {{{
    let result = map(copy(v:oldfiles), "fnamemodify(v:val, ':p')")
    let result = map(result, 's:buffer_from_path(v:val)')

    if a:ignored_pattern == ""
        return result
    endif

    let escaped = escape(a:ignored_pattern, "'")
    return filter(result, printf("v:val.path !~ '%s'", escaped))
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
        if buf.path && buf.path =~ a:ignored_pattern
            continue
        endif

        call add(result, buf)
    endfor

    return result
endfunction " }}}

function! s:segmentwise_shortest_unique_prefix(cur, ref) " {{{
    let curlen = len(a:cur)
    let reflen = len(a:ref)

    let result = []
    for i in range(curlen)
        call add(result, a:cur[i])

        if i >= reflen
            break
        endif

        let equal = s:case_sensitive_file_system ? a:cur[i] ==# a:ref[i] : a:cur[i] ==? a:ref[i]
        if equal
            continue
        endif

        break
    endfor

    return result
endfunction " }}}

function! s:set_unique_segments_prefix(bufs) " {{{
    let bufslen = len(a:bufs)
    if bufslen == 0
        return []
    elseif bufslen == 1
        return [[a:bufs[0].segments[0]]]
    endif

    let result = [s:segmentwise_shortest_unique_prefix(a:bufs[0].segments, a:bufs[1].segments)]
    for i in range(1, bufslen-2)
        let left = s:segmentwise_shortest_unique_prefix(a:bufs[i].segments, a:bufs[i-1].segments)
        let right = s:segmentwise_shortest_unique_prefix(a:bufs[i].segments, a:bufs[i+1].segments)
        call add(result, len(left) > len(right) ? left : right)
    endfor
    call add(result, s:segmentwise_shortest_unique_prefix(a:bufs[-1].segments, a:bufs[-2].segments))

    return result
endfunction " }}}

function! g:by_segments(left, right) " {{{
    let less = s:case_sensitive_file_system ? a:left.segments <# a:right.segments : a:left.segments <? a:right.segments
    return less ? -1 : 1
endfunction " }}}

function! s:by_suffix_len(left, right) " {{{
    return strlen(a:left.suffix) - strlen(a:right.suffix)
endfunction " }}}

function! s:uniq_segments(buffers) " {{{
    if len(a:buffers) == 0
        return a:buffers
    endif

    let prev = a:buffers[0]
    let result = [prev]
    for i in range(1, len(a:buffers)-1)
        let equal = s:case_sensitive_file_system ? a:buffers[i].segments ==# prev.segments : a:buffers[i].segments ==? prev.segments
        if !equal
            call add(result, a:buffers[i])
        endif
        let prev = a:buffers[i]
    endfor

    return result
endfunction " }}}

function! s:set_segmentwise_shortest_unique_suffixes(buffers) " {{{
    let result = a:buffers

    let sep = printf('\V%s\+', s:escaped_path_seg_sep)
    for buf in result
        let buf.segments = join(reverse(split(buf.path, sep)), s:unescaped_path_seg_sep)
    endfor

    call sort(result, 'g:by_segments')
    let result = s:uniq_segments(result)

    for buf in result
        let buf.segments = split(buf.segments, sep)
    endfor

    let unique_segmentwise_prefixes = s:set_unique_segments_prefix(result)
    for i in range(len(result))
        call result[i].set_suffix(join(reverse(unique_segmentwise_prefixes[i]), s:unescaped_path_seg_sep))
        unlet result[i].segments
    endfor

    call sort(result, 's:by_suffix_len')

    return result
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

    return {'data': matching, 'hint': s:render_hint(matching)}
endfunction " }}}

function! s:accept(state, key) " {{{
    if a:state.data[0].is_choosable()
        return {'result': a:state.data[0]}
    endif

    if a:key == 'CTRL-N'
        return {'result': a:state.data[0]}
    endif

    return {'state': a:state}
endfunction " }}}

function! s:yank(state, key) " {{{
    call setreg(v:register, a:state.data[0].path)
    return {'final': a:state.config.separator . a:state.data[0].path}
endfunction " }}}

function! s:guarded_space(state, key) " {{{
    if len(a:state.contents) == 0
        return {'state': a:state}
    endif

    if a:state.contents =~ '\v\s$'
        return {'state': a:state}
    endif

    if len(a:state.data) <= 1
        return {'state': a:state}
    endif

    return {'state': a:state.transition(a:state.contents . a:key)}
endfunction " }}}

let s:key_handlers =
    \{ 'CTRL-S': s:make_ref('accept')
    \, 'CTRL-V': s:make_ref('accept')
    \, 'CTRL-T': s:make_ref('accept')
    \, 'CTRL-M': s:make_ref('accept')
    \, 'CTRL-N': s:make_ref('accept')
    \, 'CTRL-Y': s:make_ref('yank')
    \, ' ': s:make_ref('guarded_space')
    \}

function! s:prompt(buffers) " {{{
    let w:chbuf_cache = a:buffers
    let w:chbuf_cache = s:set_segmentwise_shortest_unique_suffixes(w:chbuf_cache)
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

    if key == 'CTRL-M' || key == 'CTRL-N'
        call buffer.switch()
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
    return s:choose_path_interactively(buffers)
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
    let segments = split(a:path, s:unescaped_path_seg_sep)

    if segments[-1] == '.'
        return 0
    endif

    if len(segments) != 1 && segments[-1] == '..'
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

function! s:append_path_seg_sep(dir) " {{{
    return a:dir . s:unescaped_path_seg_sep
endfunction " }}}

function! s:list_glob(glob) " {{{
    let dirs = s:GlobList(a:glob, 1)
    call filter(dirs, 's:good_dirs(v:val)')
    call map(dirs, 's:append_path_seg_sep(v:val)')
    return dirs
endfunction " }}}

function! s:get_dirs() " {{{
    let dirs = s:list_glob('**')
    call extend(dirs, s:list_glob('**/.*'))
    call sort(dirs, 's:by_len')
    return dirs
endfunction " }}}

function! s:change_dir_callback(input) " {{{
    let dirs = copy(w:chbuf_cache)

    for sub in split(a:input)
        call filter(dirs, printf('stridx(v:val, "%s") >= 0', escape(sub, '\')))
    endfor

    if len(dirs) == 0
        return {}
    endif

    return {'data': dirs, 'hint': join(dirs)}
endfunction " }}}

function! s:safe_chdir(cmd, dir) " {{{
    execute a:cmd escape(a:dir, ' ')
endfunction " }}}

function! s:ch_seg(state, key, cmd) " {{{
    call s:safe_chdir(a:cmd, a:state.data[0])
    let w:chbuf_cache = s:get_dirs()
    return {'state': a:state.transition('')}
endfunction " }}}

function! s:lcd_seg(state, key) " {{{
    return s:ch_seg(a:state, a:key, 'lcd')
endfunction " }}}

function! s:cd_seg(state, key) " {{{
    return s:ch_seg(a:state, a:key, 'cd')
endfunction " }}}

function! s:accept_dir(state, key) " {{{
    return {'result': a:state.data[0]}
endfunction " }}}

function! s:yank_dir(state, key) " {{{
    let full_path = getcwd() . s:unescaped_path_seg_sep . a:state.data[0]
    call setreg(v:register, full_path)
    return {'final': a:state.config.separator . full_path}
endfunction " }}}

let s:chdir_key_handlers =
    \{ 'CTRL-S': s:make_ref('accept_dir')
    \, 'CTRL-V': s:make_ref('accept_dir')
    \, 'CTRL-T': s:make_ref('accept_dir')
    \, 'CTRL-M': s:make_ref('accept_dir')
    \, 'CTRL-Y': s:make_ref('yank_dir')
    \, ' ': s:make_ref('guarded_space')
    \}

function! s:change_dir(cmd, key_handlers) " {{{
    let w:chbuf_cache = s:get_dirs()
    let result = getline#get_line_reactively_override_keys(s:make_ref('change_dir_callback'), a:key_handlers)
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

function! s:chdir(cmd, tabfn) " {{{
    let key_handlers = copy(s:chdir_key_handlers)
    let key_handlers['CTRL-I'] = s:make_ref(a:tabfn)
    call s:change_dir(a:cmd, key_handlers)
endfunction " }}}

function! chbuf#change_directory() " {{{
    call s:chdir('cd', 'cd_seg')
endfunction " }}}

function! chbuf#local_change_directory() " {{{
    call s:chdir('lcd', 'lcd_seg')
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
    let paths = split(system(printf("mdfind -onlyin %s %s", shellescape(getcwd()), shellescape(a:query))), "\n")
    return map(paths, 's:buffer_from_path(v:val)')
endfunction " }}}

function! chbuf#change_file_spotlight(query) " {{{
    return s:choose_path_interactively(s:query_spotlight(a:query))
endfunction " }}}
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
