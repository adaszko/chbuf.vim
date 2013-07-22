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
                    \, 32: ' '
                    \, 33: '!'
                    \, 34: '"'
                    \, 35: '#'
                    \, 36: '$'
                    \, 37: '%'
                    \, 38: '&'
                    \, 39: "'"
                    \, 40: "("
                    \, 41: ")"
                    \, 42: "*"
                    \, 43: "+"
                    \, 44: ","
                    \, 45: "-"
                    \, 46: "."
                    \, 47: "/"
                    \, 48: "0"
                    \, 49: "1"
                    \, 50: "2"
                    \, 51: "3"
                    \, 52: "4"
                    \, 53: "5"
                    \, 54: "6"
                    \, 55: "7"
                    \, 56: "8"
                    \, 57: "9"
                    \, 58: ":"
                    \, 59: ";"
                    \, 60: "<"
                    \, 61: "="
                    \, 62: ">"
                    \, 63: "?"
                    \, 64: "@"
                    \, 127: 'CTRL-?'
                    \}

let s:key_from_str = { "\x80kb": "CTRL-H"
                    \, "\x80kD": "CTRL-?"
                    \}


function! s:num_chars(s) " {{{
    return strlen(substitute(a:s, '\v.', 'x', 'g'))
endfunction " }}}

function! s:without_last_word(string) " {{{
    let result = substitute(a:string, '\v(\S+)\s+\S+$', '\1', '')

    if result == a:string
        let result = ""
    endif

    return result
endfunction " }}}

function! s:transition_state(new_contents) dict " {{{
    let cmdwidth = &columns - g:getline_cmdwidth_fixup
    if len(self.config.prompt) + len(a:new_contents) > cmdwidth
        return self
    endif

    let candidates = self.config.callback(a:new_contents)
    if candidates == {}
        return self
    endif

    let new_state           = copy(self)
    let new_state.contents  = a:new_contents
    let new_state.choice    = candidates.choice
    let new_state.possible  = candidates.possible
    let new_state.hint      = candidates.hint
    return new_state
endfunction " }}}

function! s:truncate(line) dict " {{{
    let cmdwidth = &columns - g:getline_cmdwidth_fixup
    if s:num_chars(a:line) <= cmdwidth
        return a:line
    else
        return matchstr(a:line, printf('\v^.{,%s}', cmdwidth)) . self.config.cont
    endif
endfunction " }}}

function! s:show_state() dict " {{{
    if len(self.hint) > 0
        let line = self.config.prompt . self.contents . self.config.separator . self.hint
    else
        let line = self.config.prompt . self.contents
    endif

    return self.truncate(line)
endfunction " }}}

function! s:show_prompt_and_contents() dict " {{{
    return self.config.prompt . self.contents
endfunction " }}}

function! s:make_state(config) " {{{
    let candidates = a:config.callback("")
    if candidates == {}
        return {}
    endif

    let state                           = {}
    let state.config                    = a:config
    let state.contents                  = ""
    let state.choice                    = candidates.choice
    let state.possible                  = candidates.possible
    let state.hint                      = candidates.hint
    let state.transition                = s:make_ref('transition_state')
    let state.truncate                  = s:make_ref('truncate')
    let state.show                      = s:make_ref('show_state')
    let state.show_prompt_and_contents  = s:make_ref('show_prompt_and_contents')

    return state
endfunction " }}}

function! s:rubber(displayed) " {{{
    return "\r" . substitute(a:displayed, '.', ' ', 'g') . "\r"
endfunction! " }}}

function! s:without_last_char(s) " {{{
    return substitute(a:s, '\v.$', '', '')
endfunction " }}}

function! s:cancel(state, key) " {{{
    return {}
endfunction " }}}

function! s:accept(state, key) " {{{
    return {'result': a:state.choice}
endfunction " }}}

function! s:unix_line_discard(state, key) " {{{
    return {'state': a:state.transition('')}
endfunction " }}}

function! s:unix_word_rubout(state, key) " {{{
    return {'state': a:state.transition(s:without_last_word(a:state.contents))}
endfunction " }}}

function! s:nop(state, key) " {{{
    return {'state': a:state}
endfunction " }}}

function! s:backward_delete_char(state, key) " {{{
    if empty(a:state.contents)
        return {}
    else
        return {'state': a:state.transition(s:without_last_char(a:state.contents))}
    endif
endfunction " }}}

function! s:self_insert(state, key) " {{{
    return {'state': a:state.transition(a:state.contents . a:key)}
endfunction " }}}

function! s:get_script_id() " {{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_get_script_id$')
endfun " }}}

let s:script_id = s:get_script_id()

function! s:make_ref(name) " {{{
    return function(printf('<SNR>%s_%s', s:script_id, a:name))
endfunction " }}}

let s:transition_from_key =
    \{ 'CTRL-@': s:make_ref('nop')
    \, 'CTRL-A': s:make_ref('nop')
    \, 'CTRL-B': s:make_ref('nop')
    \, 'CTRL-C': s:make_ref('nop')
    \, 'CTRL-D': s:make_ref('nop')
    \, 'CTRL-E': s:make_ref('nop')
    \, 'CTRL-F': s:make_ref('nop')
    \, 'CTRL-G': s:make_ref('nop')
    \, 'CTRL-H': s:make_ref('backward_delete_char')
    \, 'CTRL-I': s:make_ref('nop')
    \, 'CTRL-J': s:make_ref('nop')
    \, 'CTRL-K': s:make_ref('nop')
    \, 'CTRL-L': s:make_ref('nop')
    \, 'CTRL-M': s:make_ref('accept')
    \, 'CTRL-N': s:make_ref('nop')
    \, 'CTRL-P': s:make_ref('nop')
    \, 'CTRL-Q': s:make_ref('nop')
    \, 'CTRL-R': s:make_ref('nop')
    \, 'CTRL-S': s:make_ref('nop')
    \, 'CTRL-T': s:make_ref('nop')
    \, 'CTRL-U': s:make_ref('unix_line_discard')
    \, 'CTRL-V': s:make_ref('nop')
    \, 'CTRL-W': s:make_ref('unix_word_rubout')
    \, 'CTRL-X': s:make_ref('nop')
    \, 'CTRL-Y': s:make_ref('nop')
    \, 'CTRL-Z': s:make_ref('nop')
    \, 'CTRL-[': s:make_ref('cancel')
    \, 'CTRL-\': s:make_ref('nop')
    \, 'CTRL-]': s:make_ref('nop')
    \, 'CTRL-^': s:make_ref('nop')
    \, 'CTRL-_': s:make_ref('nop')
    \, 'CTRL-?': s:make_ref('nop')
    \, ' ': s:make_ref('self_insert')
    \, '!': s:make_ref('self_insert')
    \, '"': s:make_ref('self_insert')
    \, '#': s:make_ref('self_insert')
    \, '$': s:make_ref('self_insert')
    \, '%': s:make_ref('self_insert')
    \, '&': s:make_ref('self_insert')
    \, "'": s:make_ref('self_insert')
    \, "(": s:make_ref('self_insert')
    \, ")": s:make_ref('self_insert')
    \, "*": s:make_ref('self_insert')
    \, "+": s:make_ref('self_insert')
    \, ",": s:make_ref('self_insert')
    \, "-": s:make_ref('self_insert')
    \, ".": s:make_ref('self_insert')
    \, "/": s:make_ref('self_insert')
    \, "0": s:make_ref('self_insert')
    \, "1": s:make_ref('self_insert')
    \, "2": s:make_ref('self_insert')
    \, "3": s:make_ref('self_insert')
    \, "4": s:make_ref('self_insert')
    \, "5": s:make_ref('self_insert')
    \, "6": s:make_ref('self_insert')
    \, "7": s:make_ref('self_insert')
    \, "8": s:make_ref('self_insert')
    \, "9": s:make_ref('self_insert')
    \, ":": s:make_ref('self_insert')
    \, ";": s:make_ref('self_insert')
    \, "<": s:make_ref('self_insert')
    \, "=": s:make_ref('self_insert')
    \, ">": s:make_ref('self_insert')
    \, "?": s:make_ref('self_insert')
    \, "@": s:make_ref('self_insert')
    \}

function! s:get_line_custom(config) " {{{
    let state = s:make_state(a:config)
    if state == {}
        echon a:config.empty
        return {}
    endif

    let displayed = state.show()
    echon displayed . "\r" . state.show_prompt_and_contents()

    while 1
        let key = getchar()

        if type(key) == type(0)
            if has_key(s:key_from_int, key)
                let name = s:key_from_int[key]
                let Trans = get(state.config.transitions, name, s:make_ref('self_insert'))
                let result = call(Trans, [state, name])
            else
                let name = ''
                " Just insert unknown keys --- this is so esp. for regional characters
                let new_contents = state.contents . nr2char(key)
                let result = {'state': state.transition(new_contents)}
            endif
        elseif type(key) == type("")
            if has_key(s:key_from_str, key)
                let name = s:key_from_str[key]
                let Trans = get(state.config.transitions, name, s:make_ref('self_insert'))
                let result = call(Trans, [state, name])
            else
                let name = ''
                let result = {'state': state}
            endif
        else
            throw "getline: getchar() returned value of unknown type"
        endif

        if result == {}
            echon s:rubber(displayed)
            return {'key': name}
        elseif has_key(result, 'result')
            echon s:rubber(displayed)
            return {'value': result.result, 'key': name}
        elseif has_key(result, 'state')
            let state = result.state
        elseif has_key(result, 'final')
            echon s:rubber(displayed)
            echon state.truncate(result.final)
            return {'key': name}
        else
            throw 'getline: Incorrect key handler return value'
        endif

        let previous = displayed
        let displayed = state.show()
        if displayed !=# previous
            echon s:rubber(displayed)
            echon displayed . "\r" . state.show_prompt_and_contents()
        endif
    endwhile
endfunction " }}}

function! getline#get_line_reactively_override_keys(callback, key_handlers) " {{{
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

    let config['callback'] = a:callback
    let merged = extend(copy(s:transition_from_key), a:key_handlers)
    let config['transitions'] = merged

    return s:get_line_custom(config)
endfunction " }}}

function! getline#get_line_reactively(callback) " {{{
    return getline#get_line_reactively_orderride_keys(a:callback, s:transition_from_key)
endfunction " }}}

function! s:id_callback(input) " {{{
    return {'choice': a:input}
endfunction " }}}

function! getline#get_line() " {{{
    return get(getline#get_line_reactively(function('s:id_callback')), 'value', '')
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo


" vim:foldmethod=marker
