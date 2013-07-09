if exists('g:autoloaded_getline') || &compatible || v:version < 700
    finish
endif

let g:autoloaded_getline = 1


let s:save_cpo = &cpo
set cpo&vim


" This accounts for 'showcmd'.  Is there a way to calculate it?
let g:getline_cmdwidth_fixup = 15

let s:key_from_int = { 0: 'CTRL-@'
                    \, 1: 'CTRL-A'
                    \, 2: 'CTRL-B'
                    \, 3: 'CTRL-C'
                    \, 4: 'CTRL-D'
                    \, 5: 'CTRL-E'
                    \, 6: 'CTRL-F'
                    \, 7: 'CTRL-G'
                    \, 8: 'CTRL-H'
                    \, 9: 'CTRL-I'
                    \, 10: 'CTRL-J'
                    \, 11: 'CTRL-K'
                    \, 12: 'CTRL-L'
                    \, 13: 'CTRL-M'
                    \, 14: 'CTRL-N'
                    \, 15: 'CTRL-O'
                    \, 16: 'CTRL-P'
                    \, 17: 'CTRL-Q'
                    \, 18: 'CTRL-R'
                    \, 19: 'CTRL-S'
                    \, 20: 'CTRL-T'
                    \, 21: 'CTRL-U'
                    \, 22: 'CTRL-V'
                    \, 23: 'CTRL-W'
                    \, 24: 'CTRL-X'
                    \, 25: 'CTRL-Y'
                    \, 26: 'CTRL-Z'
                    \, 27: 'CTRL-['
                    \, 28: 'CTRL-\'
                    \, 29: 'CTRL-]'
                    \, 30: 'CTRL-^'
                    \, 31: 'CTRL-_'
                    \, 127: 'CTRL-?'
                    \}

let s:key_from_str = { "\x80kb": "CTRL-H"
                    \, "\x80kD": "CTRL-?"
                    \}


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

function! s:TransitionState(new_contents) dict " {{{
    let candidates = self.config.GetChoicesFor(a:new_contents)
    if len(candidates) == 0
        return self
    endif

    let new_state = copy(self)
    let new_state.contents = a:new_contents
    let [new_state.choice, new_state.possible] = candidates
    return new_state
endfunction " }}}

function! s:ShowState() dict " {{{
    let cmdwidth = &columns - g:getline_cmdwidth_fixup
    let line = self.config.prompt . self.contents . self.config.separator . self.possible
    if s:NumChars(line) <= cmdwidth
        return line
    else
        return strpart(line, 0, cmdwidth - s:NumChars(self.config.cont)) . self.config.cont
    endif
endfunction " }}}

function! s:ShowPromptAndContents() dict " {{{
    return self.config.prompt . self.contents
endfunction " }}}

function! s:MakeState(config) " {{{
    let state = {}
    let state.config = a:config
    let state.contents = ""
    let candidates = a:config.GetChoicesFor(state.contents)
    if len(candidates) == 0
        return {}
    endif

    let [state.choice, state.possible] = candidates
    let state.Transition = function('s:TransitionState')
    let state.Show = function('s:ShowState')
    let state.ShowPromptAndContents = function('s:ShowPromptAndContents')
    return state
endfunction " }}}

function! s:Rubber(displayed) " {{{
    return "\r" . substitute(a:displayed, '.', ' ', 'g') . "\r"
endfunction! " }}}

function! s:WithoutLastChar(s) " {{{
    return substitute(a:s, '\v.$', '', '')
endfunction " }}}

function! s:Cancel(state) " {{{
    return {}
endfunction " }}}

function! s:Accept(state) " {{{
    if !a:state.choice.IsChoosable()
        return {'state': a:state}
    endif

    return {'result': 'CTRL-M'}
endfunction " }}}

function! s:UnixLineDiscard(state) " {{{
    return {'state': a:state.Transition('')}
endfunction " }}}

function! s:UnixWordRubout(state) " {{{
    return {'state': a:state.Transition(s:WithoutLastWord(a:state.contents)}
endfunction " }}}

function! s:Yank(state) " {{{
    call setreg(v:register, a:state.choice.path)
    return {}
endfunction " }}}

function! s:Nop(state) " {{{
    return {'state': a:state}
endfunction " }}}

function! s:BackwardDeleteChar(state) " {{{
    if empty(a:state.contents)
        return {}
    else
        return {'state': a:state.Transition(s:WithoutLastChar(a:state.contents))}
    endif
endfunction " }}}

function! s:SID() " {{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun " }}}

let s:sid = s:SID()

function! s:MakeRef(name) " {{{
    return function(printf('<SNR>%s_%s', s:sid, a:name))
endfunction " }}}

let s:transition_from_key =
    \{ 'CTRL-@': s:MakeRef('Nop')
    \, 'CTRL-A': s:MakeRef('Nop')
    \, 'CTRL-B': s:MakeRef('Nop')
    \, 'CTRL-C': s:MakeRef('Nop')
    \, 'CTRL-D': s:MakeRef('Nop')
    \, 'CTRL-E': s:MakeRef('Nop')
    \, 'CTRL-F': s:MakeRef('Nop')
    \, 'CTRL-G': s:MakeRef('Nop')
    \, 'CTRL-H': s:MakeRef('BackwardDeleteChar')
    \, 'CTRL-I': s:MakeRef('Nop')
    \, 'CTRL-J': s:MakeRef('Nop')
    \, 'CTRL-K': s:MakeRef('Nop')
    \, 'CTRL-L': s:MakeRef('Nop')
    \, 'CTRL-M': s:MakeRef('Accept')
    \, 'CTRL-N': s:MakeRef('Nop')
    \, 'CTRL-P': s:MakeRef('Nop')
    \, 'CTRL-Q': s:MakeRef('Nop')
    \, 'CTRL-R': s:MakeRef('Nop')
    \, 'CTRL-S': s:MakeRef('Nop')
    \, 'CTRL-T': s:MakeRef('Nop')
    \, 'CTRL-U': s:MakeRef('UnixLineDiscard')
    \, 'CTRL-V': s:MakeRef('Nop')
    \, 'CTRL-W': s:MakeRef('UnixWordRubout')
    \, 'CTRL-X': s:MakeRef('Nop')
    \, 'CTRL-Y': s:MakeRef('Yank')
    \, 'CTRL-Z': s:MakeRef('Nop')
    \, 'CTRL-[': s:MakeRef('Cancel')
    \, 'CTRL-\': s:MakeRef('Nop')
    \, 'CTRL-]': s:MakeRef('Nop')
    \, 'CTRL-^': s:MakeRef('Nop')
    \, 'CTRL-_': s:MakeRef('Nop')
    \, 'CTRL-?': s:MakeRef('Nop')
    \}

function! s:GetLineCustom(config) " {{{
    let state = s:MakeState(a:config)
    if state == {}
        echon a:config.empty
        return {}
    endif

    let displayed = state.Show()
    echon displayed . "\r" . state.ShowPromptAndContents()

    while 1
        let key = getchar()
        if type(key) == type(0)
            if has_key(s:key_from_int, key)
                let name = s:key_from_int[key]
                let Trans = get(state.config.transitions, name, s:MakeRef('Nop'))
                let result = call(Trans, [state])
            else
                let new_contents = state.contents . nr2char(key)
                let result = {'state': state.Transition(new_contents)}
            endif
        elseif type(key) == type("")
            if has_key(s:key_from_str, key)
                let name = s:key_from_str[key]
                let Trans = get(state.config.transitions, name, s:MakeRef('Nop'))
                let result = call(Trans, [state])
            endif
        endif

        if result == {}
            echon s:Rubber(displayed)
            return {}
        elseif has_key(result, 'result')
            echon s:Rubber(displayed)
            return {'choice': state.choice, 'method': result.result}
        elseif has_key(result, 'state')
            let state = result.state
        else
            throw 'getline: Incorrect key handler return value'
        endif

        echon s:Rubber(displayed)
        let displayed = state.Show()
        echon displayed . "\r" . state.ShowPromptAndContents()
    endwhile
endfunction " }}}

function! getline#GetLine(GetChoicesCallback, key_handlers) " {{{
    let config = {}

    if has('unix') && (&termencoding ==# 'utf-8' || &encoding ==# 'utf-8')
        let config['prompt'] = '∷ '
        let config['separator'] = ' ↦ '
        let config['cont'] = '…'
        let config['empty'] = '∅'
    else
        let config['prompt'] = ':: '
        let config['separator'] = ' => '
        let config['cont'] = '...'
        let config['empty'] = '{}'
    endif

    let config['GetChoicesFor'] = a:GetChoicesCallback
    let merged = extend(copy(s:transition_from_key), a:key_handlers)
    let config['transitions'] = merged

    return s:GetLineCustom(config)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
