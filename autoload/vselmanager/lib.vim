function! g:vselmanager#lib#VMarkNames(fname = g:VselmanagerBufCName()) abort
    return reverse(sort(g:vselmanagerDB->get(a:fname, {})->keys()))
endfun

" User interaction  "{{{
" This is the function asking the user for a mark name.
function! g:vselmanager#lib#AskVMark(prompt, val0 = '', existing = v:false, fname = g:VselmanagerBufCName(), vmarks = g:vselmanager#lib#VMarkNames(a:fname)) abort "{{{
    if a:existing && empty(a:vmarks)
        call g:vselmanager#vim#InfoMsg('WarningMsg', 'no selections saved for this buffer')
        return ''
    endif
    let mark = a:val0 ?? g:vselmanager#vim#InputChar(a:prompt)
    if "\<Tab>" is# mark
        let mark = g:vselmanager#vim#InputFromList('', a:vmarks)
    elseif a:existing && 0 > index(a:vmarks, mark)
        let mark = g:vselmanager#vim#InputFromList('no such name; ' .. a:prompt, a:vmarks)
    endif
    if " " ># mark
        " bail out if empty, or control char at [0]
        return ''
    endif
    if a:existing && 0 > index(a:vmarks, mark)
        call g:vselmanager#vim#InfoMsg('WarningMsg', 'buffer has no selection named: ' .. mark)
        let mark = ''
    endif
    return mark
endfun
"}}}
"}}}

function! g:vselmanager#lib#TmpVMarkName(sfx) abort
    return "\<C-g>__" .. a:sfx
endfun


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
