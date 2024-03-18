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

" Command helpers: "{{{
function! s:VMarkComplete(Arg, Cmd, Pos) abort
    return join(g:vselmanager#lib#VMarkNames(), "\n")
endfun
function! s:MarkedFNameComplete(Arg, Cmd, Pos) abort
    return join(g:vselmanager#db#FNames(), "\n")
endfun
"}}}

" Commands: "{{{
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerLoad call g:vselmanager#impl#VMarkLoad(<q-args>)
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerSave call g:vselmanager#impl#VMarkSave(<q-args>)
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerPutA call g:vselmanager#impl#VMarkPut(<q-args>, 'p')
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerPutB call g:vselmanager#impl#VMarkPut(<q-args>, 'P')
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerDel  call g:vselmanager#impl#VMarkDel(<q-args>)
command! VselmanagerDelAll call g:vselmanager#impl#VMarkDelAll('')
command! -nargs=1 -complete=custom,s:MarkedFNameComplete VselmanagerForgetFile call g:vselmanager#impl#VMarkDelAll(<q-args>)
command! -nargs=1 VselmanagerHistForward call g:vselmanager#impl#SelectionLoadNext(<args>)
command! -count=1 VselmanagerHistNext call g:vselmanager#impl#SelectionLoadNext(<count>)
command! -count=1 VselmanagerHistPrev call g:vselmanager#impl#SelectionLoadNext(- <count>)
command! -nargs=1 -complete=custom,s:VMarkComplete VselmanagerSwapVisual call g:vselmanager#impl#VMarkSwapVisual(<q-args>)
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
    let M = { mm, plug, to, tosfx -> s:MapSIDPlugCmd(mm, plug, 'call g:vselmanager#impl#' .. to .. 'g:vselmanager#vim#NoUnnamedReg()' .. tosfx) }
    call M( 'v', 'VselmanagerSaveVMark',      'VMarkSave(', ')')
    call M('nv', 'VselmanagerLoadVMark',      'VMarkLoad(', ')')
    call M( 'n', 'VselmanagerDelVMark',       'VMarkDel(', ')')
    call M('nv', 'VselmanagerPutAVMark',      'VMarkPut(', ', "p")')
    call M('nv', 'VselmanagerPutBVMark',      'VMarkPut(', ', "P")')
    let M = { mm, plug, to -> s:MapSIDPlugCmd(mm, plug, to) }
    call M('nv', 'VselmanagerYankVMark',      'call g:vselmanager#impl#VMarkYank("", v:register)')
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
