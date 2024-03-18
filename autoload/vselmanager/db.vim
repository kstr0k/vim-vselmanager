function! g:vselmanager#db#Lookup(fname, mark) abort
    let fdict = g:vselmanagerDB->get(a:fname, {})
    return fdict->get(a:mark, [])
endfun

function! g:vselmanager#db#Add(fname, mark, val) abort
    if !has_key(g:vselmanagerDB, a:fname)
        let g:vselmanagerDB[a:fname] = {}
    endif
    let g:vselmanagerDB[a:fname][a:mark] = a:val
endfun

function! g:vselmanager#db#Remove(fname, mark) abort  "{{{
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

function! g:vselmanager#db#AddAndSave(fname, mark, val) abort
    call g:vselmanager#db#Add(a:fname, a:mark, a:val)
    call g:VselmanagerDBSave()
endfun
function! g:vselmanager#db#RemoveAndSave(fname, mark) abort
    if g:vselmanager#db#Remove(a:fname, a:mark)
        call g:VselmanagerDBSave()
        return v:true
    endif
    return v:false
endfun

function! g:vselmanager#db#FNames() abort
    return keys(g:vselmanagerDB)
endfun


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
