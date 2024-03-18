function! g:vselmanager#vcoords#Get(vmode = '') abort
    return [ a:vmode ?? mode(), getpos('v')[1:3], getcurpos()[1:4] ]
endfun
function! g:vselmanager#vcoords#Set(coordinates, open_folds) abort  "{{{
    if empty(a:coordinates)
        throw 'trying to load inexistent vmark'
    endif
    let zv = a:open_folds ? '' : 'normal! zv'
    let old_mode = mode()
    let old_coords = g:vselmanager#vcoords#Get(old_mode)
    let mode = a:coordinates[0]
    let [ c1, c2 ] = [ a:coordinates[1], a:coordinates[2] ]
    let vmode = vselmanager#vim#VModeFilter(mode)  " empty if new mode not visual
    if ! empty(vmode)
        if vselmanager#vim#IsVMode(old_mode)
            " exit previous visual mode
            execute "normal! \<Esc>"
        endif
        call setpos('.',  [ 0 ] + c1)
        execute zv
        execute 'normal!' vmode
    " else ignore bogus c1 in non-visual coordinates
    endif
    call setpos('.', [ 0 ] + c2)
    if v:maxcol is c2[3]
        " ragged past-eol visual block; setpos() apparently not enough
        normal! $
    endif
    execute zv
    return old_coords
endfun
"}}}

function! g:vselmanager#vcoords#Yank(coords, reg) abort
    let sv_win = winsaveview()
    let old_coords = g:vselmanager#vcoords#Set(a:coords, v:false)
    silent execute 'normal!' ('"' .. a:reg .. 'y')
    " cleanup
    call g:vselmanager#vcoords#Set(old_coords, v:false)
    call winrestview(sv_win)
endfun


" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
