if exists('g:chbuf_plugin_loaded') || &compatible || v:version < 700
    finish
endif

let g:chbuf_plugin_loaded = 1

let s:save_cpo = &cpo
set cpo&vim



if has('mac')
    command! -nargs=+ -complete=custom,chbuf#SpotlightQueryCompletion Spotlight call chbuf#ChangeQuerySpotlight("<args>")
endif



let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
