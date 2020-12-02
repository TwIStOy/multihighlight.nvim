module('multihighlight.match', package.seeall)

require('math')

local v = vim.api

function nearest_match(direction) -- {{{
  local search_flag = 'nc'
  if direction == 0 then
    search_flag = search_flag .. 'b'
  end

  -- (1, 0)-indexed cursor position
  local current_cursor = v.nvim_win_get_cursor(0)
  local current_line = current_cursor[1]
  local current_col = current_cursor[2]

  -- print('[search_flag]: ', search_flag)

  local n_matched_line = -1
  local n_matched_col = -1
  local n_matched_word = ''
  local n_matched_under_cursor = 0

  function update_nearest_match(line, pattern, word) -- {{{
    if n_matched_under_cursor == 1 then
      return
    end

    local col = find_word_in_line(line, pattern, word, direction)
    local special_match_col = find_word_in_line(line, pattern, word, direction, 1)

    -- print('[under_cursor check] line: ' .. line .. ', current_line: '
    --   .. current_line .. ', current_col: ', current_col .. ', #word: '
    --   .. #word .. ', col: ' .. special_match_col)

    if line == current_line and special_match_col <= current_col
      and #word + special_match_col > current_col then
      -- matched word under cursor
      -- print('[match under cursor!], word:', word)
      n_matched_under_cursor = 1
      n_matched_line = line
      n_matched_col = special_match_col
      n_matched_word = word
      return
    end

    if n_matched_line == -1 then
      -- first match
      if col ~= -1 then
        n_matched_line = line
        n_matched_col = col
        n_matched_word = word
      end
      return
    end

    if n_matched_line == line then
      if col ~= -1 then
        if line == current_line then
          -- same line
          if math.abs(col - current_col) < math.abs(col - n_matched_col) then
            n_matched_col = col
            n_matched_word = word
          end
        else
          if direction == 1 then
            if col < n_matched_col then
              n_matched_col = col
              n_matched_word = word
            end
          else
            if col > n_matched_col then
              n_matched_col = col
              n_matched_word = word
            end
          end
        end
      end
      return
    end

    if direction == 1 then
      -- direction 1
      -- print('check', line, 'vs', n_matched_line)
      if (line >= current_line and n_matched_line >= current_line)
        or (line <= current_line and n_matched_line <= current_line) then
        -- same side, select the smaller one
        -- print('[same side]')
        if line < n_matched_line then
          -- print('[try smaller]', col)
          if col ~= -1 then
            n_matched_line = line
            n_matched_col = col
            n_matched_word = word
          end
        end
      else
        -- different side, select the bigger one
        if line > n_matched_line then
          if col ~= -1 then
            n_matched_line = line
            n_matched_col = col
            n_matched_word = word
          end
        end
      end
    else
      -- direction 0
      if (line >= current_line and n_matched_line >= current_line)
        or (line <= current_line and n_matched_line <= current_line) then
        -- same side, select the bigger one
        if line > n_matched_line then
          if col ~= -1 then
            n_matched_line = line
            n_matched_col = col
            n_matched_word = word
          end
        end
      else
        -- different side, select the smaller one
        if line < n_matched_line then
          if col ~= -1 then
            n_matched_line = line
            n_matched_col = col
            n_matched_word = word
          end
        end
      end
    end
  end -- }}}

  for i, item in ipairs(v.nvim_call_function('getmatches', {})) do
    local word = ''
    for w, id in pairs(v.nvim_get_var('multihighlight#matches_id')) do
      if id == item.id and type(w) == "string" then
        word = w
        break
      end
    end

    if #word > 0 then
      local pattern = item.pattern

      local matched_line = v.nvim_call_function('search', {
          pattern, search_flag
        })

      -- print('matched_line: ', matched_line)

      if matched_line ~= 0 then
        update_nearest_match(matched_line, pattern, word)

        if n_matched_under_cursor == 1 then
          break
        end
      end
    end
  end

  -- print(n_matched_line, n_matched_col)
  return {
    line = n_matched_line,
    col = n_matched_col,
    word = n_matched_word
  }
end -- }}}

function find_word_in_line(line, pattern, word, direction, match_cursor) -- {{{
  match_cursor = match_cursor or 0
  -- (1, 0)-indexed cursor position
  local current_cursor = v.nvim_win_get_cursor(0)
  local current_line = current_cursor[1]
  local current_col = current_cursor[2]
  -- print(current_line, current_col)
  local content = v.nvim_call_function('getline', { line })

  if current_line ~= line then
    -- if cursor not in this line
    --    direction 1: first match
    --    direction 0: last match
    if direction == 1 then
      -- print('[different line][first match]')
      return v.nvim_call_function('match', {
          content, pattern
        })
    else
      -- print('[different line][last match]')
      local last_match = -1
      local cnt = 1
      local tmp = v.nvim_call_function('match', {
          content, pattern, 0, cnt
        })
      while tmp ~= -1 do
        last_match = tmp
        cnt = cnt + 1
        tmp = v.nvim_call_function('match', {
            content, pattern, 0, cnt
          })
      end

      return last_match
    end
  end

  -- if cursor in this line
  --   direction 1: next match
  --   direction 0: previous match
  if direction == 1 then
    -- print('[same line][next match]')
    -- next match
    local res = v.nvim_call_function('match', {
        content, pattern, current_col
      })

    -- print('content: "' .. content .. '"' .. ', pattern:' .. pattern)
    -- print('current_col: ' .. current_col .. ', match_cursor:', match_cursor
    --   .. ', res: ' .. res)

    if res == current_col and match_cursor == 0 then
      return v.nvim_call_function('match', {
          content, pattern, current_col + 1
        })
    else
      return res
    end
  else
    -- print('[same line][previous match]')
    -- previous match
    local selected = -1
    local cnt = 1
    local pos = v.nvim_call_function('match', {
        content, pattern, 0, cnt
      })
    while pos < current_col and current_col <= pos + len(word) do
      selected = pos
      cnt = cnt + 1
      pos = v.nvim_call_function('match', {
          content, pattern, 0, cnt
        })
    end

    return selected
  end
end -- }}}

-- vim: fdm=marker
