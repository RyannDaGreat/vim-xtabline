""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Script variables
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:X    = g:xtabline
let s:v    = s:X.Vars
let s:F    = s:X.Funcs
let s:Sets = g:xtabline_settings

let s:v.tab_properties = {}                     "if not empty, newly created tab will inherit them
let s:v.buffer_properties = {}                  "if not empty, newly created tab will inherit them
let s:v.filtering      = 1                      "whether bufline filtering is active
let s:v.custom_tabs    = 1                      "tabline shows custom names/icons
let s:v.showing_tabs   = 0                      "tabline or bufline?
let s:v.halt           = 0                      "used to temporarily halt some functions
let s:v.auto_set_cwd   = 0                      "used to temporarily allow auto cwd detection

let s:T  = { -> s:X.Tabs[tabpagenr()-1] }       "current tab
let s:B  = { -> s:X.Buffers             }       "customized buffers
let s:vB = { -> s:T().buffers.valid     }       "valid buffers for tab
let s:eB = { -> s:T().buffers.extra     }       "extra buffers for tab
let s:pB = { -> s:X.pinned_buffers      }       "pinned buffers list
let s:oB = { -> s:T().buffers.order     }       "ordered buffers for tab
let s:rB = { -> s:T().buffers.recent    }       "recent buffers for tab

let s:invalid    = { b -> !buflisted(b) || getbufvar(b, "&buftype") == 'quickfix' }
let s:is_special = { b -> s:F.has_win(b) && s:B()[b].special }
let s:is_open    = { b -> s:F.has_win(b) && getbufvar(b, "&ma") }
let s:ready      = { -> !(exists('g:SessionLoad') || s:v.halt) }

let s:new_tab_created = 0
let s:v.slash         = exists('+shellslash') && !&shellslash ? '\' : '/'

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Init functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! xtabline#init() abort
  set showtabline=2
  let s:X.Funcs = xtabline#funcs#init()
  let s:F = s:X.Funcs
  call xtabline#maps#init()

  if exists('g:loaded_webdevicons')
    let extensions = g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols
    let exact = g:WebDevIconsUnicodeDecorateFileNodesExactSymbols
    let patterns = g:WebDevIconsUnicodeDecorateFileNodesPatternSymbols
    let s:X.devicons = {'extensions': extensions, 'exact': exact, 'patterns': patterns}
  endif

  call xtabline#tab#check_all()
  call xtabline#update()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! xtabline#update_obsession() abort
  let string = 'let g:xtabline = get(g:, "xtabline", {})'.
        \' | try | if empty(g:xtabline) | call xtabline#init#start() | endif'.
        \' | let g:xtabline.Tabs = '.string(s:X.Tabs).
        \' | let g:xtabline.Buffers = '.string(s:X.Buffers).
        \' | let g:xtabline.pinned_buffers = '.string(s:X.pinned_buffers).
        \' | call xtabline#session_loaded() | catch | endtry'
  if !exists('g:obsession_append')
    let g:obsession_append = [string]
  else
    for i in g:obsession_append
      if match(i, "^let g:xtabline") >= 0
        call remove(g:obsession_append, i)
        break
      endif
    endfor
    call add(g:obsession_append, string)
  endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! xtabline#session_loaded() abort
  for i in range(len(s:X.Tabs))
    let s:X.Tabs[i] = extend(xtabline#tab#new(), s:X.Tabs[i])
  endfor
  call xtabline#tab#check_all()
  for buf in s:X.pinned_buffers
    let i = index(s:X.pinned_buffers, buf)
    if s:invalid(buf)
      call remove(s:X.pinned_buffers, i)
    endif
  endfor
  for buf in keys(s:X.Buffers) " restored buffers may be mismatched
    if s:invalid(buf) || s:X.Buffers[buf].path != s:F.fullpath(buf)
      unlet s:X.Buffers[buf]
    endif
  endfor

  cd `=s:X.Tabs[tabpagenr()-1].cwd`
  let s:v.force_update = 1
  call xtabline#tab#check()
  call xtabline#update()
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! xtabline#refresh() abort
  """Perform a full tabline refresh. This should only be called manually.
  for buf in range(1, bufnr("$"))
    if s:existing(buf) | continue | endif
    call xtabline#buffer#update(buf)
  endfor
  call xtabline#update()
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! xtabline#update(...) abort
  let s:v.time_to_update = 1
  if s:v.showing_tabs
    set tabline=%!xtabline#render#tabs()
  else
    set tabline=%!xtabline#render#buffers()
  endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Filter buffers
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" This function is called by xtabline#render#buffers(), every time the tabline
" is updated. It won't always run, though: xtabline#update() will set the flag

fun! xtabline#filter_buffers(...) abort
  """Filter buffers so that only valid buffers for this tab will be shown.

  if      exists('s:v.force_update')          | unlet s:v.force_update
  elseif  !s:ready()                          | return
  elseif  get(g:xtabline, 'version', 0) < 0.1 | call xtabline#session_loaded()
  endif

  " 'valid' is a list of buffer numbers that belong to the tab, either because:
  "     - their path is valid for this tab
  "     - tab is locked and buffers are included
  " 'extra' are buffers that have been purposefully added by other means to the tab
  "     - not a dynamic list, elements are manually added or removed
  "     - they aren't handled here, they are handled at render time

  let T = xtabline#tab#check()

  if s:v.showing_tabs && has_key(T, 'init')
    set tabline=%!xtabline#render#tabs()
    return
  endif

  let T.buffers.valid = T.locked? T.buffers.valid : []
  let use_files = !empty(get(T, 'files', []))

  " /////////////////// ITERATE BUFFERS //////////////////////

  for buf in range(1, bufnr("$"))
    if !bufexists(buf) | continue | endif
    let B = xtabline#buffer#get(buf)

    " if special, buffer will be handled by the render script
    " if tab is locked, there's no filtering to do

    if s:is_special(buf)   | continue
    elseif s:invalid(buf)  | continue
    elseif !T.locked

      if !s:v.filtering
        let valid = 1

      elseif use_files
        " to be accepted, buffer's path must be among valid files
        let valid = index(T.files, B.path) >= 0

      else
        " to be accepted, buffer's path must be valid for this tab
        let valid = B.path =~ '^' . ( has_key(T, 'dir') ? T.dir : T.cwd )
      endif

      if valid
        call add(T.buffers.valid, buf)
        if index(T.buffers.recent, buf) < 0
          call add(T.buffers.recent, buf)
        endif
      endif
    endif
  endfor

  " //////////////////////////////////////////////////////////

  call s:ordered_buffers()
  call xtabline#update_obsession()
endfun


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:ordered_buffers() abort
  let B = s:T().buffers

  " if list of recent buffers is still empty, set it to current valid buffers
  if empty(B.recent)
    let B.recent = copy(B.valid)
  endif

  "clean up ordered/recent buffers list
  call filter(B.order, 'index(B.valid, v:val) >= 0 || index(B.extra, v:val) >= 0')
  call filter(B.recent, 'index(B.valid, v:val) >= 0')
  " call s:F.uniq(B.order)
  call s:F.uniq(B.extra)

  " add missing entries in ordered list
  for buf in B.valid
    call s:F.add_ordered(buf)
  endfor
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:set_new_tab_cwd(N) abort
  """Find suitable cwd for the new tab. Only runs after XT commands."""
  let s:new_tab_created = 0 | let T = s:X.Tabs[a:N]

  " empty tab sets cwd to ~, non-empty tab looks for a .git dir
  if empty(bufname("%"))
    let T.cwd = s:F.fullpath(getcwd())
  elseif T.cwd == '~' || s:F.fullpath("%") !~ s:F.fullpath(T.cwd)
    let T.cwd = s:F.find_suitable_cwd()
  endif
  cd `=T.cwd`
  call xtabline#update()
  call s:F.delay(200, 'g:xtabline.Funcs.msg([[ "CWD set to ", "Label" ], [ "'.T.cwd.'", "Directory" ]])')
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:existing(buf) abort
  """Check if buffer exists, clean up the buffers dict if not.
  if bufexists(a:buf)            | return 1                 | endif
  if has_key(s:X.Buffers, a:buf) | unlet s:X.Buffers[a:buf] | endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Autocommand Functions
" Inspired by TabPageCd
" Copyright (C) 2012-2013 Kana Natsuno <http://whileimautomaton.net/>
" License: MIT License
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:Do(action, ...)
  if exists('g:SessionLoad') || empty(g:xtabline.Tabs) | return | endif

  let X = g:xtabline | let F = X.Funcs | let V = X.Vars
  let N = tabpagenr() - 1
  let B = bufnr(str2nr(expand('<abuf>')))

  """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  if a:action == 'new'

    call insert(X.Tabs, xtabline#tab#new(), N)
    if V.auto_set_cwd && s:ready()
      let s:new_tab_created = 1
    endif

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  elseif a:action == 'bufenter'

    call xtabline#buffer#add(B)
    call xtabline#tab#recent_buffers(B)
    if s:new_tab_created
      call s:set_new_tab_cwd(N)
    endif
    call xtabline#update()

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  elseif a:action == 'bufwrite'

    call xtabline#buffer#update(B)
    call xtabline#update()

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  elseif a:action == 'enter'

    call xtabline#tab#check_all()
    call xtabline#tab#check()
    let T = X.Tabs[N]

    if F.cd(T.cwd) | return | endif

    call xtabline#vimrc#exe(T)
    call xtabline#update()

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  elseif a:action == 'leave'

    let V.last_tab = N
    if !haslocaldir()
      let X.Tabs[N].cwd = F.fullpath(getcwd())
    endif

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

  elseif a:action == 'close'

    if index(X.closed_cwds, X.Tabs[V.last_tab].cwd) < 0
      call add(X.closed_tabs, copy(X.Tabs[V.last_tab]))
      call add(X.closed_cwds, X.Tabs[V.last_tab].cwd)
    endif
    call remove(X.Tabs, V.last_tab)

  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

augroup plugin-xtabline
  autocmd!

  autocmd TabNew        * call s:Do('new')
  autocmd TabEnter      * call s:Do('enter')
  autocmd TabLeave      * call s:Do('leave')
  autocmd TabClosed     * call s:Do('close')
  autocmd BufEnter      * call s:Do('bufenter')
  autocmd BufWritePost  * call s:Do('bufwrite')
  autocmd BufDelete     * call xtabline#update()

  autocmd ColorScheme   * if s:ready() | call xtabline#hi#update_theme() | endif
augroup END

