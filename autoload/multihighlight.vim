" This plugin was inspired and based on
" https://github.com/lfv89/vim-interestingwords

" global variables (states) {{{

let s:default_gui_colors = [ '#aeee00', '#ff0000',
      \                      '#0000ff', '#b88823', '#ffa724', '#ff2c4b'
      \                    ]
let s:default_terms_colors = [ '154', '121', '211', '137', '214', '222' ]
let s:highlight_prefix = 'MultiHighlight'
let s:has_built = 0

let g:multihighlight#gui_colors = get(g:,
      \ 'multihighlight_gui_colors', s:default_gui_colors)
let g:multihighlight#term_colors = get(g:,
      \ 'multihighlight_term_colors', s:default_terms_colors)

" color_id -> word
let g:multihighlight#highlighting_words = get(g:,
      \ 'multihighlight#highlighting_words', [])
" color_id -> mode
let g:multihighlight#highlighting_modes = get(g:,
      \ 'multihighlight#highlighting_modes', [])
" word -> match_id
let g:multihighlight#matches_id = get(g:,
      \ 'multihighlight#matches_id', {})
" color_id[s]
let g:multihighlight#recently_used = get(g:,
      \ 'multihighlight#recently_used', [])

" }}}

function! multihighlight#new_highlight(mode) range abort " {{{
  if a:mode == 'v'
    let current_word = multihighlight#utils#virtual_selection()
  else
    let current_word = expand('<cword>') . ''
  endif
  if !(len(current_word))
    return
  endif

  if s:case_ignored(current_word)
    let current_word = tolower(current_word)
  endif
  if index(g:multihighlight#highlighting_words, current_word) == -1
    call multihighlight#highlight_word(current_word, a:mode)
  else
    call multihighlight#nohighlight_word(current_word)
  endif
endfunction " }}}

function! multihighlight#toggle_highlight(mode) range abort " {{{
  call multihighlight#new_highlight(a:mode)
endfunction
" }}}

function! multihighlight#nohighlight_all() abort " {{{
  for word in g:multihighlight#highlighting_words
    if type(word) == v:t_string
      call multihighlight#nohighlight_word(word)
    endif
  endfor
endfunction " }}}

function! multihighlight#highlight_word(word, mode) abort " {{{
  call s:build_colors()

  let n = index(g:multihighlight#highlighting_words, 0)
  if n == -1
    if get('g:', 'multihighlight_cycle_usage', 1)
      let n = g:multihighlight#recently_used[0]
      call multihighlight#nohighlight_word(
            \ g:multihighlight#highlighting_words[n]
      )
    else
      echom "[MultiHighlight]: max number of highlight groups reached"
      return
    endif
  endif

  let mid = 595129 + n
  let g:multihighlight#highlighting_words[n] = a:word
  let g:multihighlight#highlighting_modes[n] = a:mode
  let g:multihighlight#matches_id[a:word] = mid

  call s:apply_color(n, a:word, a:mode, mid)

  call s:mark_recently_used(n)
endfunction " }}}

function! multihighlight#nohighlight_word(word) abort " {{{
  let index = index(g:multihighlight#highlighting_words, a:word)

  if index > -1
    let mid = g:multihighlight#matches_id[a:word]

    windo silent! call matchdelete(mid)
    let g:multihighlight#highlighting_words[index] = 0
    unlet g:multihighlight#matches_id[a:word]
  endif
endfunction " }}}

function! multihighlight#navigation(direction) abort " {{{
  let current_word = s:nearest_group_at_cursor()

  if s:case_ignored(current_word)
    let current_word = tolower(current_word)
  endif

  if index(g:multihighlight#highlighting_words, current_word) > -1
    let l:index = index(g:multihighlight#highlighting_words, current_word)
    let l:mode = g:multihighlight#highlighting_modes[index]
    let case = s:case_ignored(current_word) ? '\c' : '\C'
    if l:mode == 'v'
      let pat = case . '\V\zs' . escape(current_word, '\') . '\ze'
    else
      let pat = case . '\V\<' . escape(current_word, '\') . '\>'
    endif
    let searchFlag = ''
    if !(a:direction)
      let searchFlag = 'b'
    endif
    call search(pat, searchFlag)
  else
    try
      if (a:direction)
        normal! n
      else
        normal! N
      endif
    catch /E486/
      echohl WarningMsg | echomsg "E486: Pattern not found: " . @/
    endtry
  endif
endfunction " }}}

" utility function {{{
function! s:case_ignored(word) abort
  if exists('g:multihighlight_ignore_case')
    return g:multihighlight_ignore_case
  endif

  " if smartcase is on, check if the word contains uppercase char
  return &ignorecase && (!&smartcase || (match(a:word, '\u') == -1))
endfunction

function! s:apply_color(n, word, mode, mid) abort
  let case = s:case_ignored(a:word) ? '\c' : '\C'
  if a:mode == 'v'
    let pat = case . '\V\zs' . escape(a:word, '\') . '\ze'
  else
    let pat = case . '\V\<' . escape(a:word, '\') . '\>'
  endif

  let settings = { 'window': 1 }
  for w in range(1, winnr('$'))
    let settings.window = w
    call matchadd(s:highlight_prefix . (a:n + 1), pat, 1, a:mid, settings)
  endfor
endfunction

function! s:add_all_existing_maches() abort
  for i in range(len(g:multihighlight#highlighting_words))
    if type(g:multihighlight#highlighting_words[i]) == v:t_string
      let l:word = g:multihighlight#highlighting_words[i]
      let case = s:case_ignored(l:word) ? '\c' : '\C'
      if g:multihighlight#highlighting_modes[i] == 'v'
        let pat = case . '\V\zs' . escape(l:word, '\') . '\ze'
      else
        let pat = case . '\V\<' . escape(l:word, '\') . '\>'
      endif

      call matchadd(s:highlight_prefix . (i + 1), pat, 1,  595129 + i)
    endif
  endfor
endfunction

function! s:nearest_group_at_cursor() abort
  let l:matches = {}
  for l:match_item in getmatches()
    let l:mids = filter(items(g:multihighlight#matches_id),
                      \ 'v:val[1] == l:match_item.id')
    if len(l:mids) == 0
      continue
    endif
    let l:word = l:mids[0][0]
    let l:position = match(getline('.'), l:match_item.pattern)
    if l:position > -1
      if col('.') > l:position && col('.') <= l:position + len(l:word)
        return l:word
      endif
    endif
  endfor
  return ''
endfunction

function! s:build_colors() abort
  if s:has_built
    return
  endif

  let ui = multihighlight#env#ui_mode()
  let word_colors = (ui == 'gui') ? g:multihighlight#gui_colors :
        \ g:multihighlight#term_colors

  " TODO(hawtian): remove shuffle

  " select ui type
  " highlight group indexed from 1
  let currentIndex = 1
  for word_color in word_colors
    execute 'hi! def ' .. s:highlight_prefix . currentIndex .
          \ ' ' . ui . 'bg=' . word_color . ' ' . ui . 'fg=Black'
    call add(g:multihighlight#highlighting_words, 0)
    call add(g:multihighlight#highlighting_modes, 'n')
    call add(g:multihighlight#recently_used, currentIndex-1)
    let currentIndex += 1
  endfor

  augroup MultihighlightAutohighlihgt
    autocmd!
    autocmd WinEnter * call s:add_all_existing_maches()
  augroup END

  let s:has_built = 1
endfunc

function! s:mark_recently_used(n) abort
  let index = index(g:multihighlight#recently_used, a:n)
  call remove(g:multihighlight#recently_used, index)
  call add(g:multihighlight#recently_used, a:n)
endfunction
" }}}

" vim: fdm=marker
