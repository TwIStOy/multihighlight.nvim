" --------------------------------------------------------------------
" This plugin was inspired and based on Steve Losh's interesting words
" .vimrc config https://www.youtube.com/watch?v=xZuy4gBghho
" --------------------------------------------------------------------
function! s:getmatch(mid) abort
  return filter(getmatches(), 'v:val.id==a:mid')[0]
endfunction

function! WordNavigation(direction)
endfunction


function! UncolorAllWords()
  for word in s:interestingWords
    " check that word is actually a String since '0' is falsy
    if (type(word) == 1)
      call UncolorWord(word)
    endif
  endfor
endfunction

function! RecolorAllWords()
  let i = 0
  for word in s:interestingWords
    if (type(word) == 1)
      let mode = s:interestingModes[i]
      let mid = s:mids[word]
      call s:apply_color_to_word(i, word, mode, mid)
    endif
    let i += 1
  endfor
endfunction

if !exists('g:interestingWordsDefaultMappings')
    let g:interestingWordsDefaultMappings = 1
endif

if !hasmapto('<Plug>InterestingWords')
    nnoremap <silent> <leader>k :call InterestingWords('n')<cr>
    vnoremap <silent> <leader>k :call InterestingWords('v')<cr>
    nnoremap <silent> <leader>K :call UncolorAllWords()<cr>

    nnoremap <silent> n :call WordNavigation(1)<cr>
    nnoremap <silent> N :call WordNavigation(0)<cr>
endif

if g:interestingWordsDefaultMappings
   try
      nnoremap <silent> <unique> <script> <Plug>InterestingWords
               \ :call InterestingWords('n')<cr>
      vnoremap <silent> <unique> <script> <Plug>InterestingWords
               \ :call InterestingWords('v')<cr>
      nnoremap <silent> <unique> <script> <Plug>InterestingWordsClear
               \ :call UncolorAllWords()<cr>
      nnoremap <silent> <unique> <script> <Plug>InterestingWordsForeward
               \ :call WordNavigation(1)<cr>
      nnoremap <silent> <unique> <script> <Plug>InterestingWordsBackward
               \ :call WordNavigation(0)<cr>
   catch /E227/
   endtry
endif

