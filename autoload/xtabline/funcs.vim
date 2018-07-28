fun! xtabline#funcs#init()
  let s:X = g:xtabline
  let s:V = s:X.Vars
  let s:Tabs = s:X.Tabs
  let s:Sets = g:xtabline_settings
  let s:T =  { -> s:X.Tabs[tabpagenr()-1]               }
  let s:B =  { -> s:X.Tabs[tabpagenr()-1].buffers       }
  let s:vB = { -> s:X.Tabs[tabpagenr()-1].buffers.valid }
  let s:oB = { -> s:X.Tabs[tabpagenr()-1].buffers.order }
  return s:Funcs
endfun

let s:Funcs = {}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.check_tabs() dict
  """Create or remove tab dicts if necessary. Rearrange tabs list if order is wrong."""
  while len(s:Tabs) < tabpagenr("$") | call add(s:Tabs, xtabline#new_tab()) | endwhile
  while len(s:Tabs) > tabpagenr('$') | call remove(s:Tabs, -1)              | endwhile
  call self.check_index()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.msg(txt, ...) dict
  """Print a message with highlighting."""
  if type(a:txt) == v:t_string
    exe "echohl" a:1? "WarningMsg" : "Label"
    echon a:txt | echohl None
    return | endif

  for txt in a:txt
    exe "echohl ".txt[1]
    echon txt[0]
    echohl None
  endfor
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.invalid_buffer(buf) dict
  return !buflisted(a:buf) ||
        \ getbufvar(a:buf, "&buftype") == 'quickfix'
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.set_buffer_var(var, ...)
  """Init buffer variable in Tabs dict to 0 or a given value.
  """Return buffer dict if successful."""
  let B = bufnr('%')
  if index(s:vB(), B) < 0
    call s:F.msg ([[ "Invalid buffer.", 'WarningMsg']])
    return
  endif
  let bufs = s:B()
  if has_key(bufs, B)
    let bufs[B][a:var] = a:0? a:1 : 0
  else
    let bufs[B] = {a:var: a:0? a:1 : 0}
  endif
  return bufs[B]
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.update_buffers()
  let bufs = s:vB()
  let order = s:oB()
  let invalid = s:T().exclude

  for buf in bufs
    if index(order, buf) < 0
      call add(order, buf)
    endif
  endfor

  for buf in invalid
    let i = index(order, buf)
    if i >= 0
      call remove(order, i)
    endif
  endfor
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.sep() dict
  """OS-specific directory separator."""
  return exists('+shellslash') && &shellslash ? '\' : '/'
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.todo_path() dict
  return getcwd().self.sep().s:Sets.todo.file
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.tab_template(...) dict
  let mod = a:0? a:1 : {}
  return extend({'name':    '',
               \ 'cwd':     getcwd(),
               \ 'vimrc':   {},
               \ 'locked':  0,
               \ 'depth':   0,
               \ 'icon':   '',
               \}, mod)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.within_depth(path, depth) dict
  """If tab uses depth, verify if the path can be accepted."""

  if !a:depth | return 1 | endif

  let basedir = fnamemodify(a:path, ":p:h")
  let diff = substitute(fnamemodify(a:path, ":p:h"), getcwd(), '', '')

  "the number of dir separators in (basedir - cwd) must be <= depth
  return count(diff, self.sep()) < a:depth
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.check_index() dict
  """Ensure the current tab has the right index in the global dict."""
  let N = tabpagenr() - 1
  if s:Tabs[N].index != N
    call insert(s:Tabs, remove(s:Tabs, s:Tabs[N].index), N)
    let i = 0
    for t in s:Tabs
      let t.index = i
      let i += 1
    endfor
  endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:Funcs.tab_buffers() dict
  """Return a list of buffers names for this tab."""
  return map(copy(s:vB()), 'bufname(v:val)')
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.is_tab_buffer(...) dict
  """Verify that the buffer belongs to the tab."""
  return (index(s:vB(), a:1) != -1)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Funcs.bdelete(buf) dict
  """Delete buffer if unmodified."""
  if !getbufvar(a:buf, '&modified')
    exe "silent! bdelete ".a:buf
    call xtabline#filter_buffers()
  endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:Funcs.not_enough_buffers() dict
  """Just return if there aren't enough buffers."""
  let bufs = s:vB()

  if len(bufs) < 2
    if index(bufs, bufnr("%")) == -1
      return
    elseif !len(bufs)
      call self.msg ([[ "No available buffers for this tab.", 'WarningMsg' ]])
    else
      call self.msg ([[ "No other available buffers for this tab.", 'WarningMsg' ]])
    endif
    return 1
  endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:Funcs.refresh_tabline() dict
  """Invalidate old Airline tabline and force redraw."""
  if exists('g:loaded_airline')
    let g:airline#extensions#tabline#exclude_buffers = s:T().exclude
    call airline#extensions#tabline#buflist#invalidate()
  else
    set tabline=%!xtabline#render#buffers()
  endif
endfunction
