" return if gui mode
function! multihighlight#env#ui_mode() abort
  if has('gui_running')
    return 'gui'
  endif
  if has('nvim') && exists('$NVIM_TUI_ENABLE_TRUE_COLOR') && !exists("+termguicolors")
    return 'gui'
  endif
  if has("termtruecolor") && &guicolors == 1
    return 'gui'
  endif
  if has("termguicolors") && &termguicolors == 1
    return 'gui'
  endif

  return 'cterm'
endfunction



