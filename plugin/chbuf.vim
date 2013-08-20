if exists('g:chbuf_plugin_loaded') || &compatible || v:version < 700
    finish
endif

let g:chbuf_plugin_loaded = 1

let s:save_cpo = &cpo
set cpo&vim


command! -nargs=* ChangeBuffer call chbuf#change_buffer(<q-args>)
command! -nargs=* ChangeMixed call chbuf#change_mixed(<q-args>)
command! -nargs=? ChangeFileSystem call chbuf#change_current(<q-args>)


if has('mac')
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion Spotlight call chbuf#spotlight(<q-args>)
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion SpotlightCurrent call chbuf#spotlight_current(<q-args>)
endif


augroup chbuf
    autocmd!
    autocmd BufAdd,BufEnter,BufLeave,BufWritePost * call chbuf#common#add_recent(0 + expand('<abuf>'))
    autocmd VimLeavePre * call chbuf#common#store_recents()
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
