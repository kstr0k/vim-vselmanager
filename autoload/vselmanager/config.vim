let s:save_cpo = &cpo
set cpo&vim

let s:config_buf = -1

function! s:FocusBuffer(nr) abort
  let w = bufwinnr(a:nr)  " only in current tab
  if w < 0
    " buffer numbers take precedence over identical filenames
    execute 'sbuffer' a:nr
  else
    execute 'normal!' (w .. "\<C-w>w")
  endif
endfun

function! s:QuoteVal(v) abort
  if type(a:v) == 0
    return '' .. a:v
  else
    return string(a:v)
  endif
endfun

function! vselmanager#config#ShowBuf()
  try
    let sv_reg = @"
    if bufexists(s:config_buf) && bufloaded(s:config_buf)  " for initial -1: won't exist
      call s:FocusBuffer(s:config_buf)
      return
    endif
    new vselmanager:config
    setlocal buftype=nofile bufhidden=wipe noswapfile
    let s:config_buf = bufnr()
    let LetVar = { _, o -> 'let ' .. o .. ' = ' .. s:QuoteVal(eval(o)) }
    call append(0, [
          \ '" vselmanager: plugin settings',
          \ '" <CR>: execute line; ,,: edit in command line; ,q: close',
          \ '" NOTE: this buffer will be wiped out when hidden',
          \ '' ] +
          \ map(copy(g:vselmanager_option_names), LetVar)
          \ )
    normal! {
    nnoremap <buffer> ,q ZQ
    nnoremap <buffer> <CR> <Cmd>execute getline('.')<CR>
    noremap  <buffer> ,, :<C-\>e getline('.')<CR>
    ounmap   <buffer> ,,
  finally
    let @" = sv_reg
  endtry
endfun

let &cpo = s:save_cpo
unlet s:save_cpo
finish

" vim: set ts=8 sts=4 sw=4 expandtab foldmethod=marker :
