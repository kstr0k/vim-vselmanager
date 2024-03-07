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
let s:vselmanager_unnamedPrefix = 'unnamed:'
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

let s:vmode_encode = { "\<C-v>": 'blk_vis', 'V': 'line_vis', 'v': 'char_vis' }
let s:vmode_decode = { 'blk_vis': "\<C-v>", 'line_vis': 'V', 'char_vis': 'v' }
function! s:VModeEncode(mode) abort
    return s:vmode_encode->get(a:mode, '')
endfun
function! s:VModeDecode(encmode) abort
    return s:vmode_decode->get(a:encmode, '')
endfun
function! s:IsVisualMode(mode) abort
    return has_key(s:vmode_encode, a:mode)
endfun

" This is the function asking the user for a mark name.
function! s:AskVMark(prompt) abort "{{{
    echomsg a:prompt
    let mark = nr2char(getchar())
    if " " >=# mark
        "echomsg 'aborted'  " of little value, and annoying
        return ''
    endif
    return mark
endfun
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
    call s:DBAdd(a:fname, a:mark, [startLine, startCol, endLine, endCol, vmode])

endfun
"}}}

" Function for restoring a visual selection, called from normal mode.  "{{{
function! s:VMarkLoad(mark = '') abort
    let mark = a:mark ?? s:AskVMark('restore selection from: ')
    if empty(mark)
        return
    endif

    try
        call s:SelectionLoad(g:VselmanagerBufCName(), mark)
    catch /.*/
        echohl ErrorMsg | echomsg v:exception | echohl None
        return
    endtry
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
        let vmode = coordinates[4]
        "move to start pos; enter visual mode; go to the end pos
        " + recursively open folds, just enough to see the selection
        execute "normal! zv"
        call cursor(coordinates[0], coordinates[1])
        "enter visual mode to select the rest
        execute "normal! zv" .. s:VModeDecode(vmode)
        call cursor(coordinates[2], coordinates[3])
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
