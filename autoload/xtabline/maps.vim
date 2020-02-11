""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mappings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:xtabline_base_mappings() abort
  if !hasmapto('<Plug>(XT-Select-Buffer)')
    silent! nmap <BS> <Plug>(XT-Select-Buffer)
  endif

  fun! s:mapkey_(keys, cmd) abort
    let cmd = ':<c-u>XTab'.a:cmd.'<CR>'
    if maparg(a:keys, 'n') == ''
      silent! execute 'nnoremap <silent><unique>' a:keys cmd
    endif
  endfun

  fun! s:mapkeyc(keys, cmd) abort
    let cmd = ':<c-u>XTab'.a:cmd.' <C-r>=v:count1<CR><CR>'
    if maparg(a:keys, 'n') == ''
      silent! execute 'nnoremap <silent><unique>' a:keys cmd
    endif
  endfun

  fun! s:mapkey0(keys, cmd) abort
    let cmd = ':<c-u>XTab'.a:cmd.' <C-r>=v:count<CR><CR>'
    if maparg(a:keys, 'n') == ''
      silent! execute 'nnoremap <silent><unique>' a:keys cmd
    endif
  endfun

  fun! s:mapkeys(keys, cmd) abort
    let cmd = ':<c-u>XTab'.a:cmd.'<Space>'
    if maparg(a:keys, 'n') == ''
      silent! execute 'nnoremap <unique>' a:keys cmd
    endif
  endfun

  call s:mapkey_('<F5>', ' cycle_mode')
  call s:mapkeyc(']b',   ' next_buffer')
  call s:mapkeyc('[b',   ' prev_buffer')
  call s:mapkey0('cdc',  'CD')
  call s:mapkey_('cdw',  'WD')
  call s:mapkey_('cd?',  ' info')
  call s:mapkey_('cdl',  'LD')

  if exists(':tcd') == 2
    call s:mapkey_('cdt',  'TD')
  endif
endfun


fun! s:xtabline_prefix_mappings() abort
  let S = g:xtabline_settings
  let X = substitute(S.map_prefix, '<leader>', get(g:, 'mapleader', '\'), 'g')

  call s:mapkey_(X.'q',  ' close_buffer')
  call s:mapkey_(X.'a',  ' list_tabs')
  call s:mapkey_(X.'z',  ' list_buffers')
  call s:mapkey_(X.'x',  ' purge')
  call s:mapkey_(X.'\',  ' last')
  call s:mapkey_(X.'u',  ' reopen')
  call s:mapkey_(X.'p',  ' pin_buffer')
  call s:mapkeyc(X.'m',  ' move_buffer')
  call s:mapkeyc(X.']',  ' move_buffer_next')
  call s:mapkeyc(X.'[',  ' move_buffer_prev')
  call s:mapkey_(X.'h',  ' hide_buffer')
  call s:mapkey_(X.'k',  ' clean_up')
  call s:mapkey_(X.'K',  '! clean_up')
  call s:mapkey_(X.'d',  ' todo')
  call s:mapkey_(X.'.',  ' toggle_labels')
  call s:mapkey_(X.'/',  ' filtering')
  call s:mapkey0(X.'+',  ' paths')
  call s:mapkey0(X.'-',  '! paths')
  call s:mapkey_(X.'?',  ' menu')
  call s:mapkeys(X.'T',  ' theme')
  call s:mapkey_(X.'tr', ' reset_tab')
  call s:mapkeys(X.'ti', 'IconTab')
  call s:mapkeys(X.'tn', ' name_tab')
  call s:mapkeys(X.'bi', 'IconBuffer')
  call s:mapkeys(X.'bn', ' name_buffer')
  call s:mapkey_(X.'br', ' reset_buffer')
  call s:mapkey_(X.'bd', ' delete_buffers')
  call s:mapkey_(X.'tl', ' load_tab')
  call s:mapkey_(X.'ts', ' save_tab')
  call s:mapkey_(X.'td', ' delete_tab')
  call s:mapkey_(X.'sl', ' load_session')
  call s:mapkey_(X.'ss', ' save_session')
  call s:mapkey_(X.'sd', ' delete_session')
  call s:mapkey_(X.'sn', ' new_session')

  exe 'nnoremap' X '<Nop>'
  call feedkeys(X)
endfun


function! xtabline#maps#init()
  nnoremap <unique> <silent> <expr> <Plug>(XT-Select-Buffer) v:count
        \ ? xtabline#cmds#select_buffer(v:count-1)
        \ : ":\<C-U>".g:xtabline_settings.select_buffer_alt_action."\<cr>"
  if g:xtabline_settings.enable_mappings
    call s:xtabline_base_mappings()
    let x = g:xtabline_settings.map_prefix
    if empty(mapcheck(x, 'n'))
      exe 'nnoremap <silent>' x ':<c-u>call <sid>xtabline_prefix_mappings()<cr>'
    endif
  endif
endfunction


fun! xtabline#maps#menu() abort
  let basic = [
        \['<F5>', 'Cycle mode'],
        \[']b',   'Next Buffer'],
        \['[b',   'Prev Buffer'],
        \]

  let cd = [
        \['cdw',  'Working directory'],
        \['cd?',  'Directory info'],
        \['cdl',  'Window-local directory'],
        \['cdc',  'Cd to current directory'],
        \]

  let leader = [
        \['\',    'Go to last tab'],
        \['+',    'Paths format (+)'],
        \['/',    'Toggle filtering'],
        \['-',    'Paths format (-)'],
        \['.',    'Toggle user labels'],
        \['', ''],
        \['', ''],
        \['', ''],
        \['a',    'List tabs'],
        \[']',    'Move buffer forwards'],
        \['z',    'List buffers'],
        \['[',    'Move buffer backwards'],
        \['', ''],
        \['', ''],
        \['m',    'Move buffer to...'],
        \['h',    'Hide buffer'],
        \['q',    'Close buffer'],
        \['u',    'Reopen last tab'],
        \['p',    'Pin buffer'],
        \['d',    'Tab todo'],
        \['', ''],
        \['', ''],
        \['k',    'Clean up tabs'],
        \['x',    'Purge tab'],
        \['K',    'Clean up! tabs'],
        \['T',    'Select theme'],
        \]

  let manage = [
        \['bd',   'Delete tab buffers'],
        \['bi',   'Change buffer icon'],
        \['bn',   'Name buffer'],
        \['br',   'Reset buffer'],
        \['', ''],
        \['', ''],
        \['sd',   'Delete session'],
        \['sl',   'Load session'],
        \['sn',   'New session'],
        \['ss',   'Save session'],
        \['', ''],
        \['', ''],
        \['td',   'Delete tab'],
        \['ti',   'Change tab icon'],
        \['tl',   'Load tab'],
        \['tn',   'Name tab'],
        \['tr',   'Reset tab'],
        \['ts',   'Save tab'],
        \]

  if exists(':tcd') == 2
    call insert(cd, ['cdt', 'Tab-local directory', "XTab td"], 1)
  endif

  let X = substitute(g:xtabline_settings.map_prefix, '<leader>', get(g:, 'mapleader', '\'), 'g')
  vnew +setlocal\ bt=nofile\ bh=wipe\ noswf\ nobl
  80wincmd |
  file xtabline mappings
  let text = []
  for group in [[basic, 'basic'], [cd, 'cd'], [leader, X], [manage, X.' tabs/buffer/session']]
    let i = 1
    call add(text, "\n" . group[1] . " mappings:\n")
    for m in group[0]
      if i % 2
        call add(text, printf("%-25s%-10s", m[1], m[0]))
      else
        let text[-1] .= printf("%-25s%-10s", m[1], m[0])
      endif
      let i += 1
    endfor
  endfor
  silent put =text
  silent normal! gg2"_dd
  syntax match XtablineMappings '^.*:$'
  hi default link XtablineMappings Title
endfun


" vim: et sw=2 ts=2 sts=2 fdm=indent fdn=1
