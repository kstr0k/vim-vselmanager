function! g:vselmanager#vim#NoUnnamedReg() abort
    return v:register is# '"' ? '' : v:register
endfun

let s:vmode_dict = { "\<C-v>": "\<C-v>", 'V': 'V', 'v': 'v' }
let s:vmodes = keys(s:vmode_dict)
function! g:vselmanager#vim#VModeFilter(mode) abort
    return s:vmode_dict->get(a:mode, '')
endfun
function! g:vselmanager#vim#IsVMode(mode) abort
    return has_key(s:vmode_dict, a:mode)
endfun
function! vselmanager#vim#EnterLastVMode() abort  "{{{
    let vmode = vselmanager#vim#VModeFilter(mode())
    if empty(vmode)
        normal! gv
        let vmode = vselmanager#vim#VModeFilter(mode())
    endif
    return vmode
endfun  "}}}


" User interaction  "{{{
if exists('*popup_notification')
function! g:vselmanager#vim#InfoMsg(hl, msg) abort
    call popup_notification(a:msg, { 'highlight': a:hl })
endfun
else
function! g:vselmanager#vim#InfoMsg(hl, msg) abort
    execute 'echohl' a:hl | echomsg a:msg | echohl None
endfun
endif

function! g:vselmanager#vim#ListToCompleter(ll) abort
    return { s1, s2, s3 -> join(a:ll, "\n") }
endfun

function! g:vselmanager#vim#ClearPrompt() abort
    echon "\r\r"
    echon
endfun

function! g:vselmanager#vim#InputFromList(prompt, opts) abort
    let Compl = g:vselmanager#vim#ListToCompleter(a:opts)
    call inputsave()
    call feedkeys("\<Tab>", 't')  " 't' = as if typed
    let ans = input(a:prompt, '', 'custom,' .. string(Compl))
    call g:vselmanager#vim#ClearPrompt()
    call inputrestore()
    return ans
endfun

function! g:vselmanager#vim#InputChar(prompt) abort
    echohl Question | echon a:prompt | echohl None
    call inputsave()
    let ch = nr2char(getchar())
    call inputrestore()
    call g:vselmanager#vim#ClearPrompt()
    return ch
endfun
"}}}


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
