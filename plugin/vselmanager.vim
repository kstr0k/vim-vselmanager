" Vim plugin for saving and restoring the visual selection
" Last Change:  2024-03-31
" Maintainer:   Alin Mr <almr.oss@outlook.com>
" License:      GPL 2: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

" Previous Maintainer: Iago-lito <iago.bonnici@gmail.com>

" see :help write-plugin "{{{
if exists('g:loaded_vselmanager')
    finish
endif
let g:loaded_vselmanager = 1

let s:save_cpo = &cpo
set cpo&vim
"}}}

" Utilities to persist a variable to a file "{{{
function! s:SaveVariable(val, file) abort
    " writefile() only takes lists, so wrap arg
    call writefile([json_encode(a:val)], a:file)
endfun
" And its other side: restore a variable from a file:
function! s:ReadVariable(file)
    " don't forget to unwrap it!
    let recover = readfile(a:file)[0]
    " watch out, it is so far just a string, make it what it should be:
    execute "let result = " . recover
    return result
endfun
" Cool, isn't it? Thank you VanLaser from the Stack!
" http://stackoverflow.com/q/31348782/3719101
"}}}

function! s:NonDefaultReg() abort
    return v:register is# '"' ? '' : v:register
endfun

function! s:ListToCompleter(ll) abort
    return { s1, s2, s3 -> join(a:ll, "\n") }
endfun

" Options & globals: "{{{
" Database location
if !exists('g:vselmanager_DBFile')
    let g:vselmanager_DBFile = $HOME .. '/.vim-vis-mark'
endif
if !exists('g:vselmanager_exitVModeAfterMarking')
    let g:vselmanager_exitVModeAfterMarking = 1
endif
let s:vselmanager_unnamedPrefix = ' " unnamed:'
"}}}

" the big dictionary itself:
" Its organization is simple:
"  - each *key* is the full path to a file
"  - each *value* is also a dictionary, for which:
"      - the *key* is a mark identifier
"      - the *value* is the position of the recorded selection, a list:
"           - [startLine, startColumn, endLine, endColumn]
" Dictionary ops: {{{
function! s:NoNameCanonName(bufnum) abort
    return s:vselmanager_unnamedPrefix .. a:bufnum
endfun
function! s:DBSave() abort
    call s:SaveVariable(g:vselmanagerDB, g:vselmanager_DBFile)
endfun
function! s:DBLoad() abort
    let g:vselmanagerDB = s:ReadVariable(g:vselmanager_DBFile)
endfun
function! s:DBReset() abort
    let g:vselmanagerDB = {}
    call s:DBSave()
endfun
function! s:DBLookup(fname, mark) abort
    let fdict = g:vselmanagerDB->get(a:fname, {})
    return fdict->get(a:mark, [])
endfun
function! s:DBAdd(fname, mark, val) abort
    if !has_key(g:vselmanagerDB, a:fname)
        let g:vselmanagerDB[a:fname] = {}
    endif
    let g:vselmanagerDB[a:fname][a:mark] = a:val
endfun
function! s:DBAddAndSave(fname, mark, val) abort
    call s:DBAdd(a:fname, a:mark, a:val)
    call s:DBSave()
endfun
function! s:DBRemove(fname, mark) abort  "{{{
    if ! has_key(g:vselmanagerDB, a:fname)
        return 0
    endif
    if empty(a:mark)
        call remove(g:vselmanagerDB, a:fname)
    else
        let fdict = g:vselmanagerDB[a:fname]
        if has_key (fdict, a:mark)
            call remove(fdict, a:mark)
            if empty(fdict)
                call remove(g:vselmanagerDB, a:fname)
            endif
        else
            return 0
        endif
    endif
    return 1
endfun  "}}}
function! s:DBRemoveAndSave(fname, mark) abort
    if s:DBRemove(a:fname, a:mark)
        call s:DBSave()
        return v:true
    endif
    return v:false
endfun
function! g:VselmanagerDBInit() abort
    if filereadable(g:vselmanager_DBFile)
        call s:DBLoad()
        " remove entries for unnamed buffers: their bufnr()s don't survive a Vim restart
        call filter(g:vselmanagerDB, { key -> key !~# ('^' .. s:vselmanager_unnamedPrefix) })
    else
        " create the file if it does not exist
        call s:DBReset()
    endif
endfun
"}}}

call g:VselmanagerDBInit()

" Map current buffer to a dictionary key:  "{{{
" This key is either the absolute path or a special prefix + the buffer id for
" NoName buffers. NoName entries are deleted from the dictionary on BufDelete.
function! g:VselmanagerBufCName(fname = '') abort
    return a:fname ?? expand('%:p') ?? s:NoNameCanonName(bufnr())
endfun
"}}}

function! g:VMarkNames(fname = g:VselmanagerBufCName()) abort
    return g:vselmanagerDB->get(a:fname, {})->keys()
endfun
function! s:MarkedFNames() abort
    return keys(g:vselmanagerDB)
endfun

" Remove NoName buffer selections on BufDelete so they aren't persisted.  "{{{
" WATCH OUT: during 'BufDelete', the '%'-pointed buffer might not be the one
" being deleted.. thus the <afile> and <abuf>
function! s:OnBufDeleted() abort
    if empty(expand('<afile>:p'))
        " buffer being deleted is unnamed: remove its entry from dictionary:
        let entry = s:NoNameCanonName(expand('<abuf>'))
        call s:DBRemoveAndSave(entry, '')
    endif
endfun
augroup Vselmanager_Cleanup
    autocmd!
    autocmd BufDelete * call s:OnBufDeleted()
augroup END
"}}}

let s:vmode_encode = { "\<C-v>": "\<C-v>", 'V': 'V', 'v': 'v' }
let s:vmode_decode = s:vmode_encode
function! s:VModeEncode(mode) abort
    return s:vmode_encode->get(a:mode, '')
endfun
function! s:VModeDecode(encmode) abort
    return s:vmode_decode->get(a:encmode, '')
endfun
function! s:IsVisualMode(mode) abort
    return has_key(s:vmode_encode, a:mode)
endfun

" User interaction  "{{{
function! s:ClearPrompt() abort
    echon "\r\r"
    echon
endfun

if exists('*popup_notification')
function! s:InfoMsg(hl, msg) abort
    call popup_notification(a:msg, { 'highlight': a:hl })
endfun
else
function! s:InfoMsg(hl, msg) abort
    execute 'echohl' a:hl | echomsg a:msg | echohl None
endfun
endif

function! s:InputFromList(prompt, opts) abort
    let Compl = s:ListToCompleter(a:opts)
    call inputsave()
    call feedkeys("\<Tab>", 't')  " 't' = as if typed
    let ans = input(a:prompt, '', 'custom,' .. string(Compl))
    call s:ClearPrompt()
    call inputrestore()
    return ans
endfun

function! s:InputChar(prompt) abort
    echohl Question | echon a:prompt | echohl None
    call inputsave()
    let ch = nr2char(getchar())
    call inputrestore()
    call s:ClearPrompt()
    return ch
endfun

" This is the function asking the user for a mark name.
function! s:AskVMark(prompt, val0 = '', existing = v:false, fname = g:VselmanagerBufCName(), vmarks = g:VMarkNames(a:fname)) abort "{{{
    if a:existing && empty(a:vmarks)
        call s:InfoMsg('WarningMsg', 'no selections saved for this buffer')
        return ''
    endif
    let mark = a:val0 ?? s:InputChar(a:prompt)
    if "\<Tab>" is# mark
        let mark = s:InputFromList('', a:vmarks)
    elseif a:existing && 0 > index(a:vmarks, mark)
        let mark = s:InputFromList('no such name; ' .. a:prompt, a:vmarks)
    endif
    if " " ># mark
        " bail out if empty, or control char at [0]
        return ''
    endif
    if a:existing && 0 > index(a:vmarks, mark)
        call s:InfoMsg('WarningMsg', 'buffer has no selection named: ' .. mark)
        let mark = ''
    endif
    return mark
endfun
"}}}
"}}}

function! s:TmpVMarkName(sfx) abort
    return "\<C-g>__" .. a:sfx
endfun

function! s:EnterLastVMode() abort  "{{{
    let vmode = s:VModeEncode(mode())
    if empty(vmode)
        normal! gv
        let vmode = s:VModeEncode(mode())
    endif
    return vmode
endfun  "}}}

" Function for saving a visual selection, called from visual mode.  "{{{
function! s:VMarkSave(mark = '') abort
    let mark = a:mark ?? s:AskVMark('save selection to: ')
    if empty(mark)
        return
    endif

    call s:SelectionSave(g:VselmanagerBufCName(), mark)

    if g:vselmanager_exitVModeAfterMarking
        execute "normal! \<esc>"
    endif
endfun

function! s:SelectionSave(fname, mark) abort
    let vmode = s:EnterLastVMode()
    if empty(vmode)
        throw 'no previous selection for this buffer'
    endif

    " retrieve selection start
    let [startLine, startCol, startOff] = getpos('v')[1:3]
    let startCol += startOff

    " retrieve selection end
    let [endLine, endCol, endOff] = getpos('.')[1:3]
    let endCol += endOff

    " update the dictionary
    call s:DBAddAndSave(a:fname, a:mark, [vmode, startLine, startCol, endLine, endCol])

endfun
"}}}

" Function for restoring a visual selection, called from normal mode.  "{{{
function! s:VMarkLoad(mark = '') abort
    let fname = g:VselmanagerBufCName()
    let mark = s:AskVMark('restore selection from: ', a:mark, v:true, fname)
    if empty(mark)
        return
    endif

    call s:SelectionLoad(fname, mark)
endfun

function! s:SelectionLoad(fname, mark) abort
    if s:IsVisualMode(mode())
        " exit previous visual mode
        execute "normal! \<Esc>"
    endif
    let coordinates = s:DBLookup(a:fname, a:mark)
    if empty(coordinates)
        throw 'selection does not exist for buffer: ' .. a:mark
    else
        let vmode = coordinates[0]
        "move to start pos; enter visual mode; go to the end pos
        " + recursively open folds, just enough to see the selection
        execute "normal! zv"
        call cursor(coordinates[1], coordinates[2])
        "enter visual mode to select the rest
        execute "normal! zv" .. s:VModeDecode(vmode)
        call cursor(coordinates[3], coordinates[4])
    endif
endfun
"}}}

function! s:SelectionLoadNext(delta = 1) abort  "{{{
    let fname = g:VselmanagerBufCName()
    let vmarks = g:VMarkNames(fname)
    let nvmarks = len(vmarks)
    if 0 is nvmarks
        call s:InfoMsg('WarningMsg', 'no selections defined yet for this buffer')
        return ''
    endif
    if ! exists('b:visualMarks_cycle_idx') || b:visualMarks_cycle_idx > nvmarks
        " set cycling state to a sane value
        let b:visualMarks_cycle_idx = 0
    endif
    " compute (non-negative) modulo (vim's '%' is actually a remainder)
    let b:visualMarks_cycle_idx = (b:visualMarks_cycle_idx + a:delta) % nvmarks
    let b:visualMarks_cycle_idx = b:visualMarks_cycle_idx < 0 ? (b:visualMarks_cycle_idx + nvmarks) : b:visualMarks_cycle_idx
    let vmark = vmarks[b:visualMarks_cycle_idx]
    call s:SelectionLoad(fname, vmark)
    return vmark
endfun  "}}}

function! s:VMarkSwapVisual(mark) abort  "{{{
    let fname = g:VselmanagerBufCName()
    let vmode = s:EnterLastVMode()
    let mark = s:AskVMark('swap visual with vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif

    let tmpmark1 = s:TmpVMarkName('swap1')  " initial gv position
    let tmpmark2 = s:TmpVMarkName('swap2')  " final   gv position
    let sv_reg = @"
    try
        call s:SelectionSave(fname, tmpmark1)
        normal! y
        call s:SelectionLoad(fname, mark)
        if vmode isnot mode()
            call s:InfoMsg('WarningMsg', 'mismatched visual modes')
            call s:SelectionLoad(fname, tmpmark1)
            return
        endif
        normal! p
        call s:SelectionSave(fname, tmpmark2)
        call s:SelectionLoad(fname, tmpmark1)
        normal! p
        call s:SelectionSave(fname, mark)
        call s:SelectionLoad(fname, tmpmark2)
    finally
        let @" = sv_reg
        call s:DBRemove(fname, tmpmark1)
        call s:DBRemove(fname, tmpmark2)
        call s:DBSave()
    endtry
endfun  "}}}

" Functions to delete marks  "{{{
function! s:VMarkDel(mark, fname = '') abort
    let fname = g:VselmanagerBufCName(a:fname)
    let mark = s:AskVMark('remove visual mark: ', a:mark, v:true, fname)
    if ! empty(mark)
        call s:DBRemoveAndSave(fname, mark)
    endif
endfun
function! s:VMarkDelAll(fname = '') abort
    let fname = g:VselmanagerBufCName(a:fname)
    if ! s:DBRemoveAndSave(fname, '')
        call s:InfoMsg('WarningMsg', 'no selections saved for buffer ' .. fname)
    endif
endfun
"}}}

" Mappings: "{{{
" Set the <Plug> specific maps
vnoremap <unique> <script> <Plug>VselmanagerVMarkSave <SID>VMarkSave
nnoremap <unique> <script> <Plug>VselmanagerVMarkLoad <SID>VMarkLoad
" Set the calls to the functions, local to this script
vnoremap <SID>VMarkSave    <esc>:call <SID>VMarkSave()<CR>
nnoremap <SID>VMarkLoad      :call <SID>VMarkLoad()<CR>
" And set the default maps! (without interfering with the user's preferences)
if !hasmapto("<Plug>VselmanagerVMarkSave")
    vmap <unique> m <Plug>VselmanagerVMarkSave
endif
if !hasmapto("<Plug>VselmanagerVMarkLoad")
    nmap <unique> < <Plug>VselmanagerVMarkLoad
endif
"}}}

" see :help write-plugin "{{{
let &cpo = s:save_cpo
unlet s:save_cpo
"}}}


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
