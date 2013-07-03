let s:save_cpo = &cpo
set cpo&vim


" This accounts for 'showcmd'.  Is there a way to calculate it?
let g:getline_cmdwidth_fixup = 15


function! s:NumChars(s) " {{{
    return strlen(substitute(a:s, '\v.', 'x', 'g'))
endfunction " }}}

function! s:WithoutLastWord(string) " {{{
    let result = substitute(a:string, '\v(\S+)\s+\S+$', '\1', '')

    if result == a:string
        let result = ""
    endif

    return result
endfunction " }}}

function! s:InitialState(config) " {{{
    let state = {}
    let state.contents = ""
    let candidates = a:config.GetChoicesFor(state.contents)
    if len(candidates) == 0
        return {}
    endif

    let [state.choice, state.possible] = candidates
    return state
endfunction " }}}

function! s:StateTransition(state, config, newContents) " {{{
    let candidates = a:config.GetChoicesFor(a:newContents)
    if len(candidates) == 0
        return a:state
    endif

    let a:state.contents = a:newContents
    let [a:state.choice, a:state.possible] = candidates
    return a:state
endfunction " }}}

function! s:ShowState(state, config) " {{{
    let cmdwidth = &columns - g:getline_cmdwidth_fixup
    let line = a:config.prompt . a:state.contents . a:config.separator . a:state.possible
    if s:NumChars(line) <= cmdwidth
        return line
    else
        return strpart(line, 0, cmdwidth - s:NumChars(a:config.continuation)) . a:config.continuation
    endif
endfunction " }}}

function! s:ShowPromptContents(state, config) " {{{
    return a:config.prompt . a:state.contents
endfunction " }}}

function! s:Rubber(displayed) " {{{
    return "\r" . substitute(a:displayed, '.', ' ', 'g') . "\r"
endfunction! " }}}

function! s:WithoutLastChar(s) " {{{
    return substitute(a:s, '\v.$', '', '')
endfunction " }}}

function! s:GetLineCustom(config) " {{{
    let state = s:InitialState(a:config)
    if state == {}
        return []
    endif

    let displayed = s:ShowState(state, a:config)
    echon displayed . "\r" . s:ShowPromptContents(state, a:config)

    while 1
        let c = getchar()
        if c == 27 " <Esc>
            echon s:Rubber(displayed)
            return []
        endif

        if type(c) == type(0)
            if c == 13 " <Enter>
                if state.choice.IsChoosable()
                    echon s:Rubber(displayed)
                    return [state.choice, '<CR>']
                endif
            elseif c == 21 " <C-U>
                let state = s:StateTransition(state, a:config, "")
            elseif c == 23 " <C-W>
                let state = s:StateTransition(state, a:config, s:WithoutLastWord(state.contents))
            elseif c == 1 " <C-a>
                continue
            elseif c == 4 " <C-d>
                continue
            elseif c == 5 " <C-e>
                continue
            elseif c == 8 " <C-h>
                if empty(state.contents)
                    echon s:Rubber(displayed)
                    return []
                else
                    let state = s:StateTransition(state, a:config, s:WithoutLastChar(state.contents))
                endif
            elseif c == 9
                if state.choice.IsChoosable()
                    echon s:Rubber(displayed)
                    return [state.choice, '<Tab>']
                endif
            elseif c == 19 " <C-s>
                if state.choice.IsChoosable()
                    echon s:Rubber(displayed)
                    return [state.choice, '<C-S>']
                endif
            elseif c == 20 " <C-t>
                if state.choice.IsChoosable()
                    echon s:Rubber(displayed)
                    return [state.choice, '<C-T>']
                endif
            elseif c == 22 " <C-v>
                if state.choice.IsChoosable()
                    echon s:Rubber(displayed)
                    return [state.choice, '<C-V>']
                endif
            else
                let newContents = state.contents . nr2char(c)
                let state = s:StateTransition(state, a:config, newContents)
            endif
        elseif type(c) == type("")
            if c == "\x80kb" " <BS>
                if empty(state.contents)
                    echon s:Rubber(displayed)
                    return []
                else
                    let state = s:StateTransition(state, a:config, s:WithoutLastChar(state.contents))
                endif
            endif
        endif

        echon s:Rubber(displayed)
        let displayed = s:ShowState(state, a:config)
        echon displayed . "\r" . s:ShowPromptContents(state, a:config)
    endwhile
endfunction " }}}

function! getline#GetLine(GetChoicesCallback) " {{{
    let config = {}

    if has('unix') && (&termencoding ==# 'utf-8' || &encoding ==# 'utf-8')
        let config['prompt'] = '∷ '
        let config['separator'] = ' ↦ '
        let config['continuation'] = '…'
    else
        let config['prompt'] = ':: '
        let config['separator'] = ' => '
        let config['continuation'] = '...'
    endif

    let config['GetChoicesFor'] = a:GetChoicesCallback

    return s:GetLineCustom(config)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
