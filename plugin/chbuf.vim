if exists('g:chbuf_plugin_loaded') || &compatible || v:version < 700
    finish
endif

let g:chbuf_plugin_loaded = 1

let s:save_cpo = &cpo
set cpo&vim


command! -nargs=* ChangeBuffer call chbuf#change_buffer('<args>')
command! -nargs=* ChangeMixed call chbuf#change_mixed('<args>')
command! ChangeFile call chbuf#change_file()
command! ChangeDirectory call chbuf#change_directory()
command! LocalChangeDirectory call chbuf#local_change_directory()


if has('mac')
    command! -nargs=+ -complete=custom,chbuf#spotlight_query_completion Spotlight call chbuf#change_file_spotlight('<args>')
endif



let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
