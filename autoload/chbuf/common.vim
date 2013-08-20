if exists('g:autoloaded_chbuf_common') || &compatible || v:version < 700
    finish
endif

let g:autoloaded_chbuf_common = 1

let s:save_cpo = &cpo
set cpo&vim


if !exists('+shellslash') || &shellslash
    let chbuf#common#unescaped_path_seg_sep = '/'
    let chbuf#common#escaped_path_seg_sep = '/'
else
    let chbuf#common#unescaped_path_seg_sep = '\'
    let chbuf#common#escaped_path_seg_sep = '\\'
endif

let s:script_name = expand('<sfile>')

function! s:is_file_system_case_sensitive() " {{{
    let ignores_case = filereadable(tolower(s:script_name)) && filereadable(toupper(s:script_name))
    return !ignores_case
endfunction " }}}

let chbuf#common#case_sensitive_file_system = s:is_file_system_case_sensitive()

function! chbuf#common#is_good_buffer(buffer) " {{{
    if !buflisted(a:buffer)
        return 0
    endif

    if !empty(getbufvar(a:buffer, 'buftype'))
        return 0
    endif

    if bufname(a:buffer) == ''
        return 0
    endif

    return 1
endfunction " }}}

function! s:is_recent_present(path, recents) " {{{
    for entry in a:recents
        let equal = g:chbuf#common#case_sensitive_file_system ? entry[1] ==# a:path : entry[1] ==? a:path
        if equal
            let entry[0] = localtime()
            return 1
        endif
    endfor

    return 0
endfunction " }}}

function! s:by_fst_elem(left, right) " {{{
    return a:right[0] - a:left[0]
endfunction " }}}

function! s:by_snd_elem_case_sens(left, right) " {{{
    if a:left[1] <# a:right[1]
        return -1
    endif

    if a:left[1] ># a:right[1]
        return 1
    endif

    return 0
endfunction " }}}

function! s:by_snd_elem_case_insens(left, right) " {{{
    if a:left[1] <? a:right[1]
        return -1
    endif

    if a:left[1] >? a:right[1]
        return 1
    endif

    return 0
endfunction " }}}

if !exists('g:chbuf_recents_limit')
    let g:chbuf_recents_limit = 100
endif

function! s:merge_recents(left, right) " {{{
    let save = &ignorecase
    let &ignorecase = !g:chbuf#common#case_sensitive_file_system
    let catted = sort(extend(a:left, a:right), g:chbuf#common#case_sensitive_file_system ? 's:by_snd_elem_case_sens' : 's:by_snd_elem_case_insens')

    if len(catted) == 0
        return []
    endif

    let prev = catted[0]
    let result = [prev]
    for entry in catted[1:]
        if entry[1] == prev[1]
            continue
        endif

        let prev = entry
        call add(result, [max([entry[0], prev[0]]), entry[1]])
    endfor
    let &ignorecase = save

    let result = sort(result, 's:by_fst_elem')
    return result[:g:chbuf_recents_limit - 1]
endfunction " }}}

function! chbuf#common#get_recents_file_path() " {{{
    let dotdir = simplify(expand($HOME . g:chbuf#common#unescaped_path_seg_sep . ".vim"))
    if !isdirectory(dotdir)
        call mkdir(dotdir)
    endif
    return simplify(dotdir . g:chbuf#common#unescaped_path_seg_sep . "recent.txt")
endfunction " }}}

function! chbuf#common#store_recents() " {{{
    if !exists("g:chbuf_recent_paths")
        return
    endif

    let recents_path = chbuf#common#get_recents_file_path()
    let loaded = chbuf#common#load_recents(recents_path)
    let merged = s:merge_recents(loaded, g:chbuf_recent_paths)
    let merged = map(merged, 'string(v:val)')
    call writefile(merged, recents_path)
endfunction " }}}

function! chbuf#common#load_recents(recents_path) " {{{
    if !filereadable(a:recents_path)
        return []
    endif

    let result = []
    for line in readfile(a:recents_path)
        let [timestamp, path] = eval(line)
        call add(result, [0+timestamp, path])
    endfor
    return result
endfunction " }}}

function! chbuf#common#add_recent(bufnr) " {{{
    if !chbuf#common#is_good_buffer(a:bufnr)
        return
    endif

    let path = simplify(resolve(fnamemodify(bufname(a:bufnr), ":p")))
    if !exists("g:chbuf_recent_paths")
        let g:chbuf_recent_paths = chbuf#common#load_recents(chbuf#common#get_recents_file_path())
    endif

    if s:is_recent_present(path, g:chbuf_recent_paths)
        return
    endif

    let g:chbuf_recent_paths = [[localtime(), path]] + g:chbuf_recent_paths
    if len(g:chbuf_recent_paths) > g:chbuf_recents_limit
        let g:chbuf_recent_paths = g:chbuf_recent_paths[:g:chbuf_recents_limit - 1]
    endif
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
