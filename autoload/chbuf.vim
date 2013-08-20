if exists('g:autoloaded_chbuf') || &compatible || v:version < 700
    finish
endif

let g:autoloaded_chbuf = 1

let s:save_cpo = &cpo
set cpo&vim


" {{{ Data Source: Internal
function! s:get_script_id() " {{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_get_script_id$')
endfun " }}}

let s:script_id = s:get_script_id()

function! s:make_ref(name) " {{{
    return function(printf('<SNR>%s_%s', s:script_id, a:name))
endfunction " }}}

function! s:change_to_number() dict " {{{
    execute 'silent' 'buffer' self.number
endfunction " }}}

function! s:is_number_choosable() dict " {{{
    return 1
endfunction " }}}

function! s:set_file_suffix(suffix) dict " {{{
    let self.suffix = a:suffix
endfunction " }}}

function! s:set_dir_suffix(suffix) dict " {{{
    let self.suffix = a:suffix . g:chbuf#common#unescaped_path_seg_sep
endfunction " }}}

function! s:ensure_ends_with_seg_sep(path) " {{{
    if strpart(a:path, strlen(a:path) - 1) ==# g:chbuf#common#unescaped_path_seg_sep
        return a:path
    endif

    return a:path . g:chbuf#common#unescaped_path_seg_sep
endfunction " }}}

function! s:file_dir() dict " {{{
    return fnamemodify(self.path, ':h')
endfunction " }}}

function! s:dir_dir() dict " {{{
    return self.path
endfunction " }}}

function! s:cd_buffer() dict " {{{
    execute 'silent' 'cd' fnameescape(self.dir())
endfunction " }}}

function! s:lcd_buffer() dict " {{{
    execute 'silent' 'lcd' fnameescape(self.dir())
endfunction " }}}

function! s:buffer_from_number(number, name) " {{{
    let path = expand('#' . a:number . ':p')

    if isdirectory(path)
        let path = s:ensure_ends_with_seg_sep(path)
        let set_suf_fn = 'set_dir_suffix'
        let dir_fn = 'dir_dir'
    else
        let set_suf_fn = 'set_file_suffix'
        let dir_fn = 'file_dir'
    endif

    return { 'number':          a:number
          \, 'path':            path
          \, 'name':            a:name
          \, 'change':          s:make_ref('change_to_number')
          \, 'is_choosable':    s:make_ref('is_number_choosable')
          \, 'set_suffix':      s:make_ref(set_suf_fn)
          \, 'dir':             s:make_ref(dir_fn)
          \, 'cd':              s:make_ref('cd_buffer')
          \, 'lcd':             s:make_ref('lcd_buffer')
          \}
endfunction " }}}

function! s:change_to_path() dict " {{{
    execute 'silent' 'edit' fnameescape(self.path)
endfunction " }}}

function! s:path_choosable() dict " {{{
    return filereadable(self.path) || isdirectory(self.path)
endfunction " }}}

function! s:buffer_from_path(path) " {{{
    let expanded = expand(a:path)

    if isdirectory(expanded)
        let expanded = s:ensure_ends_with_seg_sep(expanded)
        let set_suf_fn = 'set_dir_suffix'
        let dir_fn = 'dir_dir'
    else
        let set_suf_fn = 'set_file_suffix'
        let dir_fn = 'file_dir'
    endif

    return { 'path':            expanded
          \, 'change':          s:make_ref('change_to_path')
          \, 'is_choosable':    s:make_ref('path_choosable')
          \, 'set_suffix':      s:make_ref(set_suf_fn)
          \, 'dir':             s:make_ref(dir_fn)
          \, 'cd':              s:make_ref('cd_buffer')
          \, 'lcd':             s:make_ref('lcd_buffer')
          \}
endfunction " }}}

function! s:buffer_from_relative_path(relative) " {{{
    let absolute = join([getcwd(), a:relative], g:chbuf#common#unescaped_path_seg_sep)

    if isdirectory(absolute)
        let absolute = s:ensure_ends_with_seg_sep(absolute)
        let set_suf_fn = 'set_dir_suffix'
        let dir_fn = 'dir_dir'
    else
        let set_suf_fn = 'set_file_suffix'
        let dir_fn = 'file_dir'
    endif

    return { 'relative':        a:relative
          \, 'path':            absolute
          \, 'change':          s:make_ref('change_to_path')
          \, 'is_choosable':    s:make_ref('path_choosable')
          \, 'set_suffix':      s:make_ref(set_suf_fn)
          \, 'dir':             s:make_ref(dir_fn)
          \, 'cd':              s:make_ref('cd_buffer')
          \, 'lcd':             s:make_ref('lcd_buffer')
          \}
endfunction " }}}

function! s:glob_list(wildcard, flags) " {{{
    if v:version < 704
        return split(glob(a:wildcard, a:flags), "\n")
    endif

    return glob(a:wildcard, a:flags, 1)
endfunction " }}}

function! s:is_file_system_object(path) " {{{
    let type = getftype(a:path)
    if type == 'file' || type == 'dir'
        return 1
    elseif type == 'link'
        let resolved = getftype(resolve(a:path))
        return resolved == 'file' || resolved == 'dir'
    endif

    return 0
endfunction " }}}

function! s:get_glob_objects(glob_pattern) " {{{
    let paths = s:glob_list(a:glob_pattern, 0)
    call filter(paths, 's:is_file_system_object(v:val)')
    call map(paths, 's:buffer_from_relative_path(v:val)')
    return paths
endfunction " }}}

function! s:get_recents(ignored_pattern) " {{{
    if !exists("g:chbuf_recent_paths")
        let g:chbuf_recent_paths = chbuf#common#load_recents(chbuf#common#get_recents_file_path())
    endif

    let result = map(copy(g:chbuf_recent_paths), 's:buffer_from_path(v:val[1])')

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

        if !chbuf#common#is_good_buffer(buffer)
            continue
        endif

        if buffer == bufnr('%')
            continue
        endif

        let buf = s:buffer_from_number(buffer, bufname(buffer))
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

        let equal = g:chbuf#common#case_sensitive_file_system ? a:cur[i] ==# a:ref[i] : a:cur[i] ==? a:ref[i]
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

function! s:by_segments(left, right) " {{{
    let less = g:chbuf#common#case_sensitive_file_system ? a:left.segments <# a:right.segments : a:left.segments <? a:right.segments
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
        let equal = g:chbuf#common#case_sensitive_file_system ? a:buffers[i].segments ==# prev.segments : a:buffers[i].segments ==? prev.segments
        if !equal
            call add(result, a:buffers[i])
        endif
        let prev = a:buffers[i]
    endfor

    return result
endfunction " }}}

function! s:set_segmentwise_shortest_unique_suffixes(buffers, attrib) " {{{
    let result = a:buffers

    let sep = printf('\V%s\+', g:chbuf#common#escaped_path_seg_sep)
    for buf in result
        let buf.segments = join(reverse(split(get(buf, a:attrib), sep)), g:chbuf#common#unescaped_path_seg_sep)
    endfor

    call sort(result, 's:by_segments')
    let result = s:uniq_segments(result)

    for buf in result
        let buf.segments = split(buf.segments, sep)
    endfor

    let unique_segmentwise_prefixes = s:set_unique_segments_prefix(result)
    for i in range(len(result))
        call result[i].set_suffix(join(reverse(unique_segmentwise_prefixes[i]), g:chbuf#common#unescaped_path_seg_sep))
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

function! s:chdir(state, key) " {{{
    let result = a:state.data[0]
    if a:key == 'CTRL-I'
        call result.cd()
        return {'final': ':cd ' . result.dir()}
    elseif a:key == 'CTRL-L'
        call result.lcd()
        return {'final': ':lcd ' . result.dir()}
    else
        throw 'Unhandled key: ' . a:key
    endif
endfunction " }}}

let s:key_handlers =
    \{ 'CTRL-S': s:make_ref('accept')
    \, 'CTRL-V': s:make_ref('accept')
    \, 'CTRL-T': s:make_ref('accept')
    \, 'CTRL-M': s:make_ref('accept')
    \, 'CTRL-Y': s:make_ref('yank')
    \, 'CTRL-L': s:make_ref('chdir')
    \, 'CTRL-I': s:make_ref('chdir')
    \, ' ': s:make_ref('guarded_space')
    \}

function! s:prompt(buffers) " {{{
    let w:chbuf_cache = a:buffers
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
        call buffer.change()
    elseif key == 'CTRL-T'
        execute 'tabnew'
        call buffer.change()
    elseif key == 'CTRL-S'
        execute 'split'
        call buffer.change()
    elseif key == 'CTRL-V'
        execute 'vsplit'
        call buffer.change()
    endif
endfunction " }}}

function! s:choose_path_interactively(path_objects) " {{{
    return s:change(s:prompt(a:path_objects))
endfunction " }}}

function! chbuf#change_buffer(ignored_pattern) " {{{
    let buffers = s:get_buffers(a:ignored_pattern)
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#change_mixed(ignored_pattern) " {{{
    let buffers = extend(s:get_buffers(a:ignored_pattern), s:get_recents(a:ignored_pattern))
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#change_current(glob_pattern) " {{{
    let buffers = s:get_glob_objects(a:glob_pattern)
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'relative')
    return s:choose_path_interactively(buffers)
endfunction " }}}
" }}}

" {{{ Data Source: External
function! chbuf#spotlight_query_completion(arglead, cmdline, cursorpos) " {{{
    " https://developer.apple.com/library/mac/#documentation/Carbon/Conceptual/SpotlightQuery/Concepts/QueryFormat.html
    let keywords =
        \[ 'kMDItemFSName'
        \, 'kMDItemDisplayName'
        \, 'kMDItemFSCreationDate'
        \, 'kMDItemFSContentChangeDate'
        \, 'kMDItemContentType'
        \, 'kMDItemContentTypeTree'
        \, 'kMDItemFSSize'
        \, 'kMDItemFSInvisible'
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

function! s:error(msg) " {{{
    echohl ErrorMsg
    echo a:msg
    echohl None
endfunction " }}}

function! chbuf#spotlight_current(query) " {{{
    let output = system(printf("mdfind -onlyin %s %s", shellescape(getcwd()), shellescape(a:query)))
    if v:shell_error > 0
        call s:error("mdfind: " . substitute(output, "\\v\n*$", "", ""))
        return
    endif
    let paths = map(split(output, "\n"), 'fnamemodify(v:val, ":.")')
    let buffers = map(paths, 's:buffer_from_relative_path(v:val)')
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'relative')
    return s:choose_path_interactively(buffers)
endfunction " }}}

function! chbuf#spotlight(query) " {{{
    let output = system(printf("mdfind %s", shellescape(a:query)))
    if v:shell_error > 0
        call s:error("mdfind: " . substitute(output, "\\v\n*$", "", ""))
        return
    endif
    let buffers = map(split(output, "\n"), 's:buffer_from_path(v:val)')
    let buffers = s:set_segmentwise_shortest_unique_suffixes(buffers, 'path')
    return s:choose_path_interactively(buffers)
endfunction " }}}
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
