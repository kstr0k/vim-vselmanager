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
function! s:ReadVariable(file) abort
    " unwrap list returned by readfile() from single-line file
    return json_decode(readfile(a:file)[0])
endfun
"}}}

" Options & globals: "{{{
let g:vselmanager_option_names = [ 'g:vselmanager_DBFile', 'g:vselmanager_mapPrefix', 'g:vselmanager_exitVModeAfterMarking' ]

" Database location
if !exists('g:vselmanager_DBFile')
    let g:vselmanager_DBFile = fnamemodify('~/', ':p') .. '.vim-vselmanager.json'
endif
if !exists('g:vselmanager_mapPrefix')
    let g:vselmanager_mapPrefix = v:none
endif
if !exists('g:vselmanager_exitVModeAfterMarking')
    let g:vselmanager_exitVModeAfterMarking = 1
endif
let s:vselmanager_unnamedPrefix = ' " unnamed:'
"}}}

function! s:NoNameCanonName(bufnum) abort
    return s:vselmanager_unnamedPrefix .. a:bufnum
endfun

" The in-memory vmark database
" Database organization: a dictionary  "{{{
"  - each *key* is the full path to a file
"  - each *value* is a dictionary, for which:
"      - the *key* is a vmark identifier
"      - the *value* is a list describing the visual selection:
"           - [ mode, startPosList, endPosList ]
"}}}
" DB ops: {{{
function! g:VselmanagerDBSave() abort
    call s:SaveVariable(g:vselmanagerDB, g:vselmanager_DBFile)
endfun
function! s:DBLoad() abort
    let g:vselmanagerDB = s:ReadVariable(g:vselmanager_DBFile)
endfun
function! s:DBReset() abort
    let g:vselmanagerDB = {}
    call g:VselmanagerDBSave()
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

" Remove NoName buffer selections on BufDelete so they aren't persisted.  "{{{
" WATCH OUT: during 'BufDelete', the '%'-pointed buffer might not be the one
" being deleted.. thus the <afile> and <abuf>
function! s:OnBufDeleted() abort
    if empty(expand('<afile>:p'))
        " buffer being deleted is unnamed: remove its entry from dictionary:
        let entry = s:NoNameCanonName(expand('<abuf>'))
        call g:vselmanager#db#RemoveAndSave(entry, '')
    endif
endfun
augroup Vselmanager_Cleanup
    autocmd!
    autocmd BufDelete * call s:OnBufDeleted()
augroup END
"}}}

" Function for saving a visual selection, called from visual mode.  "{{{
function! s:VMarkSave(mark = '') abort
    let mark = a:mark ?? g:vselmanager#lib#AskVMark('save selection to: ')
    if empty(mark)
        return
    endif

    call s:SelectionSave(g:VselmanagerBufCName(), mark)

    if g:vselmanager_exitVModeAfterMarking
        execute "normal! \<esc>"
    endif
endfun

function! s:SelectionSave(fname, mark) abort
    let vmode = vselmanager#vim#EnterLastVMode()
    if empty(vmode)
        throw 'no previous selection for this buffer'
    endif
    call g:vselmanager#db#AddAndSave(a:fname, a:mark, g:vselmanager#vcoords#Get(vmode))
endfun
"}}}

" Function for restoring a visual selection, called from normal mode.  "{{{
function! s:VMarkLoad(mark = '') abort
    let fname = g:VselmanagerBufCName()
    let mark = g:vselmanager#lib#AskVMark('restore selection from: ', a:mark, v:true, fname)
    if empty(mark)
        return
    endif

    call s:SelectionLoad(fname, mark)
endfun

function! s:SelectionLoad(fname, mark) abort
    let coordinates = g:vselmanager#db#Lookup(a:fname, a:mark)
    call g:vselmanager#vcoords#Set(coordinates, v:true)
endfun
"}}}

function! s:SelectionLoadNext(delta = 1) abort  "{{{
    let fname = g:VselmanagerBufCName()
    let vmarks = g:vselmanager#lib#VMarkNames(fname)
    let nvmarks = len(vmarks)
    if 0 is nvmarks
        call g:vselmanager#vim#InfoMsg('WarningMsg', 'no selections defined yet for this buffer')
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

" Extract selection contents  "{{{
function! s:SelectionYank(fname, mark, reg) abort
    call g:vselmanager#vcoords#Yank(g:vselmanager#db#Lookup(a:fname, a:mark), a:reg)
endfun
function! s:SelectionContents(fname, mark) abort
    let sv_reg = @"
    call s:SelectionYank(fname, mark, '"')
    let res = @"
    let @" = sv_reg
    return res
endfun
"}}}

function! s:VMarkYank(mark, reg) abort
    let fname = g:VselmanagerBufCName()
    let mark = g:vselmanager#lib#AskVMark('yank to @' .. a:reg .. ' vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif
    call s:SelectionYank(fname, mark, a:reg)
endfun
function! s:VMarkPut(mark, put_type) abort
    let fname = g:VselmanagerBufCName()
    let mark = g:vselmanager#lib#AskVMark('put (' .. a:put_type .. ') vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif
    let sv_reg = @"
    call s:SelectionYank(fname, mark, '"')
    execute 'normal!' a:put_type
    let @" = sv_reg
endfun

function! s:VMarkSwapVisual(mark) abort  "{{{
    let fname = g:VselmanagerBufCName()
    let vmode = vselmanager#vim#EnterLastVMode()
    let mark = g:vselmanager#lib#AskVMark('swap visual with vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif

    let tmpmark1 = s:TmpVMarkName('swap1')  " initial gv position
    let tmpmark2 = s:TmpVMarkName('swap2')  " final   gv position
    let sv_reg = @"
    try
        call s:SelectionSave(fname, tmpmark1)
        normal! y
        call s:SelectionLoad(fname, mark)
        if vmode isnot mode()
            call g:vselmanager#vim#InfoMsg('WarningMsg', 'mismatched visual modes')
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
        call g:vselmanager#db#Remove(fname, tmpmark1)
        call g:vselmanager#db#Remove(fname, tmpmark2)
        call g:VselmanagerDBSave()
    endtry
endfun  "}}}

" Functions to delete marks  "{{{
function! s:VMarkDel(mark, fname = '') abort
    let fname = g:VselmanagerBufCName(a:fname)
    let mark = g:vselmanager#lib#AskVMark('remove visual mark: ', a:mark, v:true, fname)
    if ! empty(mark)
        call g:vselmanager#db#RemoveAndSave(fname, mark)
    endif
endfun
function! s:VMarkDelAll(fname = '') abort
    let fname = g:VselmanagerBufCName(a:fname)
    if ! g:vselmanager#db#RemoveAndSave(fname, '')
        call g:vselmanager#vim#InfoMsg('WarningMsg', 'no selections saved for buffer ' .. fname)
    endif
endfun

" Command helpers: "{{{
function! s:VMarkComplete(Arg, Cmd, Pos) abort
    return join(g:vselmanager#lib#VMarkNames(), "\n")
endfun
function! s:MarkedFNameComplete(Arg, Cmd, Pos) abort
    return join(g:vselmanager#db#FNames(), "\n")
endfun
"}}}
"}}}


" Commands: "{{{
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerLoad call s:VMarkLoad(<q-args>)
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerSave call s:VMarkSave(<q-args>)
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerPutA call s:VMarkPut(<q-args>, 'p')
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerPutB call s:VMarkPut(<q-args>, 'P')
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerDel  call s:VMarkDel(<q-args>)
command! VselmanagerDelAll call s:VMarkDelAll('')
command! -nargs=1 -complete=custom,s:MarkedFNameComplete VselmanagerForgetFile call s:VMarkDelAll(<q-args>)
command! -nargs=1 VselmanagerHistForward call s:SelectionLoadNext(<args>)
command! -count=1 VselmanagerHistNext call s:SelectionLoadNext(<count>)
command! -count=1 VselmanagerHistPrev call s:SelectionLoadNext(- <count>)
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerSwapVisual call s:VMarkSwapVisual(<q-args>)
command! -nargs=1 -complete=custom,s:MarkedFNameComplete VselmanagerEditFile execute 'edit' <q-args>
command! VselmanagerEditDB execute 'edit' g:vselmanager_DBFile
"}}}

" Mappings: "{{{
" Mapping utils:  "{{{
function! s:MapInModes(map_in, rec, mod, k, to) abort
    if a:map_in is# 'nv'
        " per help: map for all three, unmap for o
        execute (a:rec .. 'map') a:mod a:k a:to
        execute 'ounmap' a:k
    else
        execute (a:map_in .. a:rec .. 'map') a:mod a:k a:to
    endif
endfun
function! s:MapSIDPlug(map_in, plug, to)
    " <SID> mappings for hygiene, see help or
    " https://www.reddit.com/r/vim/comments/9djp9t/question_about_using_sid_and_plug_in_mappings/
    call s:MapInModes(a:map_in, 'nore', '<unique> <script>', '<Plug>' .. a:plug, '<SID>' .. a:plug)
    call s:MapInModes(a:map_in, 'nore', '',                  '<SID>'  .. a:plug,  a:to)
endfun
function! s:MapSIDPlugCmd(mapcmd, plug, tocmd)
    return s:MapSIDPlug(a:mapcmd, a:plug, '<Cmd>' .. a:tocmd .. '<CR>')
endfun
"}}}
" Set the <Plug> specific maps  "{{{
function! s:SetPlugMappings()
    let M = { mm, plug, to, tosfx -> s:MapSIDPlugCmd(mm, plug, 'call <SID>' .. to .. 'g:vselmanager#vim#NoUnnamedReg()' .. tosfx) }
    call M( 'v', 'VselmanagerSaveVMark',      'VMarkSave(', ')')
    call M('nv', 'VselmanagerLoadVMark',      'VMarkLoad(', ')')
    call M( 'n', 'VselmanagerDelVMark',       'VMarkDel(', ')')
    call M('nv', 'VselmanagerPutAVMark',      'VMarkPut(', ', "p")')
    call M('nv', 'VselmanagerPutBVMark',      'VMarkPut(', ', "P")')
    let M = { mm, plug, to -> s:MapSIDPlugCmd(mm, plug, to) }
    call M('nv', 'VselmanagerYankVMark',      'call <SID>VMarkYank("", v:register)')
    call M('nv', 'VselmanagerHistMR',         '0 VselmanagerHistNext')
    call M('nv', 'VselmanagerHistNext',       'VselmanagerHistForward   v:count ?? 1')
    call M('nv', 'VselmanagerHistPrev',       'VselmanagerHistForward -(v:count ?? 1)')
endfun
call s:SetPlugMappings()
"}}}
function! g:VselmanagerSetDefaultMaps(pfx, ignore_mapped = v:true, uniq = v:true) abort  "{{{
    let unique = a:uniq ? '<unique>' : ''
    let Avail = { to -> a:ignore_mapped || ! hasmapto( to ) }
    let M = { mm, k, to -> Avail('<Plug>' .. to) ? s:MapInModes(mm, '', unique, a:pfx .. k, '<Plug>' .. to ) : v:false }

    call M( 'v', 'm',          'VselmanagerSaveVMark')
    call M('nv', '`',          'VselmanagerLoadVMark')
    call M( 'n', 'd',          'VselmanagerDelVMark')
    call M('nv', 'p',          'VselmanagerPutAVMark')
    call M('nv', 'P',          'VselmanagerPutBVMark')
    call M('nv', 'y',          'VselmanagerYankVMark')
    call M('nv', '<C-I>',      'VselmanagerHistNext')
    call M('nv', '<C-O>',      'VselmanagerHistPrev')
    call M( 'n', 'gv',         'VselmanagerHistMR')
endfun  "}}}

if v:none isnot g:vselmanager_mapPrefix
    call g:VselmanagerSetDefaultMaps(g:vselmanager_mapPrefix, v:false)
endif
"}}}

" see :help write-plugin "{{{
let &cpo = s:save_cpo
unlet s:save_cpo
"}}}


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
