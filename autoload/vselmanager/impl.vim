" Function for saving a visual selection, called from visual mode.  "{{{
function! g:vselmanager#impl#VMarkSave(mark = '') abort
    let mark = a:mark ?? g:vselmanager#lib#AskVMark('save selection to: ')
    if empty(mark)
        return
    endif

    let fname = g:VselmanagerBufCName()
    let vcoords = g:vselmanager#impl#SelectionSave(fname, mark)
    let vcoords1 = g:vselmanager#db#Lookup(fname, '0')
    if len(vcoords1)
        call g:vselmanager#db#Add(fname, '1', vcoords1)
    endif
    call g:vselmanager#db#Add(fname, '0', vcoords)
    call g:VselmanagerDBSave()

    if g:vselmanager_exitVModeAfterMarking
        execute "normal! \<esc>"
    endif
endfun

function! g:vselmanager#impl#SelectionSave(fname, mark) abort
    let vmode = vselmanager#vim#EnterLastVMode()
    if empty(vmode)
        throw 'no previous selection for this buffer'
    endif
    let vcoords = g:vselmanager#vcoords#Get(vmode)
    call g:vselmanager#db#Add(a:fname, a:mark, vcoords)
    return vcoords
endfun
"}}}

" Function for restoring a visual selection, called from normal mode.  "{{{
function! g:vselmanager#impl#VMarkLoad(mark = '') abort
    let fname = g:VselmanagerBufCName()
    let mark = g:vselmanager#lib#AskVMark('restore selection from: ', a:mark, v:true, fname)
    if empty(mark)
        return
    endif

    let vcoords = g:vselmanager#impl#SelectionLoad(fname, mark)
    call g:vselmanager#db#Add(fname, '`', vcoords)
endfun

function! g:vselmanager#impl#SelectionLoad(fname, mark) abort
    let coordinates = g:vselmanager#db#Lookup(a:fname, a:mark)
    call g:vselmanager#vcoords#Set(coordinates, v:true)
    return coordinates
endfun
"}}}

function! g:vselmanager#impl#SelectionLoadNext(delta = 1) abort  "{{{
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
    call g:vselmanager#impl#SelectionLoad(fname, vmark)
    return vmark
endfun  "}}}

" Extract selection contents  "{{{
function! g:vselmanager#impl#SelectionYank(fname, mark, reg) abort
    call g:vselmanager#vcoords#Yank(g:vselmanager#db#Lookup(a:fname, a:mark), a:reg)
endfun
function! g:vselmanager#impl#SelectionContents(fname, mark) abort
    let sv_reg = @"
    call g:vselmanager#impl#SelectionYank(fname, mark, '"')
    let res = @"
    let @" = sv_reg
    return res
endfun
"}}}

function! g:vselmanager#impl#VMarkYank(mark, reg) abort
    let fname = g:VselmanagerBufCName()
    let mark = g:vselmanager#lib#AskVMark('yank to @' .. a:reg .. ' vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif
    call g:vselmanager#impl#SelectionYank(fname, mark, a:reg)
endfun
function! g:vselmanager#impl#VMarkPut(mark, put_type) abort
    let fname = g:VselmanagerBufCName()
    let mark = g:vselmanager#lib#AskVMark('put (' .. a:put_type .. ') vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif
    let sv_reg = @"
    call g:vselmanager#impl#SelectionYank(fname, mark, '"')
    execute 'normal!' a:put_type
    let @" = sv_reg
endfun

function! g:vselmanager#impl#VMarkSwapVisual(mark) abort  "{{{
    let fname = g:VselmanagerBufCName()
    let vmode = vselmanager#vim#EnterLastVMode()
    let mark = g:vselmanager#lib#AskVMark('swap visual with vmark: ', a:mark, v:true, fname)
    if empty(mark) | return | endif

    let tmpmark1 = g:vselmanager#impl#TmpVMarkName('swap1')  " initial gv position
    let tmpmark2 = g:vselmanager#impl#TmpVMarkName('swap2')  " final   gv position
    let sv_reg = @"
    try
        call g:vselmanager#impl#SelectionSave(fname, tmpmark1)
        normal! y
        call g:vselmanager#impl#SelectionLoad(fname, mark)
        if vmode isnot mode()
            call g:vselmanager#vim#InfoMsg('WarningMsg', 'mismatched visual modes')
            call g:vselmanager#impl#SelectionLoad(fname, tmpmark1)
            return
        endif
        normal! p
        call g:vselmanager#impl#SelectionSave(fname, tmpmark2)
        call g:vselmanager#impl#SelectionLoad(fname, tmpmark1)
        normal! p
        call g:vselmanager#impl#SelectionSave(fname, mark)
        call g:vselmanager#impl#SelectionLoad(fname, tmpmark2)
    finally
        let @" = sv_reg
        call g:vselmanager#db#Remove(fname, tmpmark1)
        call g:vselmanager#db#Remove(fname, tmpmark2)
        call g:VselmanagerDBSave()
    endtry
endfun  "}}}

" Functions to delete marks  "{{{
function! g:vselmanager#impl#VMarkDel(mark, fname = '') abort
    let fname = g:VselmanagerBufCName(a:fname)
    let mark = g:vselmanager#lib#AskVMark('remove visual mark: ', a:mark, v:true, fname)
    if ! empty(mark)
        call g:vselmanager#db#RemoveAndSave(fname, mark)
    endif
endfun
function! g:vselmanager#impl#VMarkDelAll(fname = '') abort
    let fname = g:VselmanagerBufCName(a:fname)
    if ! g:vselmanager#db#RemoveAndSave(fname, '')
        call g:vselmanager#vim#InfoMsg('WarningMsg', 'no selections saved for buffer ' .. fname)
    endif
endfun
"}}}


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
