-- Colorscheme generated from the terminal's own palette.
--
-- pywal writes ~/.cache/wal/colors.json alongside the wallpaper, so reading
-- that file keeps the editor on the same 16 colors foot draws. Backgrounds are
-- `none` (foot runs at alpha 0.95); surfaces that must stay legible over other
-- text (floats, the completion menu, the statusline) are mixed from the
-- palette. Text colors are picked by measuring WCAG contrast, not by
-- hardcoding a slot: the palette is regenerated per wallpaper, and a slot that
-- clears 4.5:1 on one background can sit under it on the next.

local M = {}

local COLORS = vim.fn.expand('~/.cache/wal/colors.json')

-- Used when pywal has never run here. Same 16 slots, so nothing below needs a
-- second code path.
local FALLBACK = {
  background = '#1c1c1c', foreground = '#d0d0d0',
  color0 = '#1c1c1c', color1 = '#af5f5f', color2 = '#5faf5f', color3 = '#afaf5f',
  color4 = '#5f87af', color5 = '#af5faf', color6 = '#5fafaf', color7 = '#d0d0d0',
  color8 = '#6c6c6c', color9 = '#ff8787', color10 = '#87ff87', color11 = '#ffff87',
  color12 = '#87afff', color13 = '#ff87ff', color14 = '#87ffff', color15 = '#ffffff',
}

local function components(color)
  local r, g, b = color:match('^#?(%x%x)(%x%x)(%x%x)$')
  if not r then return nil end
  return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

-- WCAG relative luminance, 0 (black) to 1 (white).
local function luminance(color)
  local r, g, b = components(color)
  if not r then return 0 end
  local function linear(c)
    c = c / 255
    return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

-- WCAG contrast ratio. 4.5:1 is the AA floor for text, 3:1 for borders and
-- other non-text shapes.
local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- t = 0 returns `a`, t = 1 returns `b`.
local function mix(a, b, t)
  local ar, ag, ab = components(a)
  local br, bg, bb = components(b)
  local function byte(v) return math.floor(math.min(255, math.max(0, v)) + 0.5) end
  return string.format('#%02x%02x%02x', byte(ar + (br - ar) * t), byte(ag + (bg - ag) * t), byte(ab + (bb - ab) * t))
end

-- The first candidate that clears `min` on this background, otherwise the one
-- closest to clearing it. Palette slots carry no lightness ordering, so a
-- fixed slot cannot be assumed readable.
local function readable(candidates, background, min)
  min = min or 4.5
  local pick, best = candidates[1], contrast(candidates[1], background)
  for _, candidate in ipairs(candidates) do
    local ratio = contrast(candidate, background)
    if ratio >= min then return candidate end
    if ratio > best then pick, best = candidate, ratio end
  end
  return pick
end

-- pywal writes colors.json in one shot, but a half-written file should not
-- take the editor down: anything that is not 18 valid hex colors returns nil
-- and the caller falls back. Every name is checked explicitly, because pairs()
-- walks only present keys and a palette missing half its slots would look
-- complete.
local function complete(palette)
  for _, name in ipairs({ 'background', 'foreground' }) do
    local value = palette[name]
    if type(value) ~= 'string' or not components(value) then return false end
  end
  for i = 0, 15 do
    local value = palette['color' .. i]
    if type(value) ~= 'string' or not components(value) then return false end
  end
  return true
end

function M.palette(path)
  local file = io.open(path or COLORS, 'r')
  if not file then return nil end
  local raw = file:read('*a')
  file:close()

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= 'table' or type(data.colors) ~= 'table' then return nil end

  local palette = {
    background = type(data.special) == 'table' and data.special.background or nil,
    foreground = type(data.special) == 'table' and data.special.foreground or nil,
  }
  for i = 0, 15 do palette['color' .. i] = data.colors['color' .. i] end

  if not complete(palette) then return nil end
  return palette
end

function M.apply(path)
  local p = M.palette(path) or FALLBACK
  -- The palette that is on screen. A reload compares against this so it can
  -- tell a real wallpaper change from a focus event that changed nothing.
  M.active = p

  local bg, fg = p.background, p.foreground
  local c = {}
  for i = 0, 15 do c[i] = p['color' .. i] end

  vim.o.background = luminance(bg) < 0.5 and 'dark' or 'light'

  local bar = mix(bg, fg, 0.10)        -- statusline
  local surface = mix(bg, fg, 0.07)    -- floats, completion menu
  local line = mix(bg, fg, 0.05)       -- cursorline, colorcolumn
  local selection = mix(bg, fg, 0.22)

  -- The palette's own foreground, held to the AA floor against the background.
  -- pywal picks it from the wallpaper and can land under the floor: a plain
  -- light image yields #999999 background with #e5e5e5 foreground (2.3:1), and
  -- every plain-text group draws with it. `--contrast` does not help, because it
  -- deliberately skips slots 0 and 15. Pulling the foreground towards black or
  -- white keeps the tint while clearing the floor; a palette that already
  -- clears it is unchanged. The extreme is picked by contrast, not luminance:
  -- white on #999999 is 2.9:1 while black is 7.4:1.
  local ink_far = contrast('#000000', bg) >= contrast('#ffffff', bg) and '#000000' or '#ffffff'
  fg = readable({ fg, mix(fg, ink_far, 0.5), mix(fg, ink_far, 0.75), ink_far }, bg)

  -- Words and symbols that carry meaning: 4.5:1, measured against `bar`, the
  -- lightest surface text can land on. The last candidate is the foreground
  -- itself, so the picker can never return a dim color.
  local function text(color)
    return readable({ color, mix(color, fg, 0.35), mix(color, fg, 0.65), fg }, bar)
  end

  -- Borders, separators, indent guides: 3:1, the non-text floor. Floats and the
  -- statusline are filled, the editor around them is transparent.
  local function shape(background)
    return readable({ c[8], mix(bg, fg, 0.4), mix(bg, fg, 0.6), fg }, background, 3)
  end

  local border = shape(bg)
  local surface_border = shape(bar)
  local comment = text(c[8])
  local red, green, yellow = text(c[1]), text(c[2]), text(c[3])
  local blue, magenta, cyan = text(c[4]), text(c[5]), text(c[6])

  -- Ink for text on a filled surface (mode badge, search hits, selected menu
  -- row). Palette extremes first, then pure black and white: a mid-range slot
  -- can leave nothing that clears AA on either side.
  local function ink(background)
    return readable({ bg, c[0], '#000000', c[15], c[7], fg, '#ffffff' }, background)
  end

  local function hl(group, spec) vim.api.nvim_set_hl(0, group, spec) end
  local function link(group, target) vim.api.nvim_set_hl(0, group, { link = target }) end

  vim.cmd('highlight clear')
  if vim.fn.exists('syntax_on') == 1 then vim.cmd('syntax reset') end
  vim.g.colors_name = 'terminal'

  -- :terminal buffers get the same palette rather than nvim's defaults.
  for i = 0, 15 do vim.g['terminal_color_' .. i] = c[i] end

  -- Base
  hl('Normal', { fg = fg, bg = 'none' })
  hl('NormalNC', { fg = fg, bg = 'none' })
  hl('NormalFloat', { fg = fg, bg = surface })
  hl('FloatBorder', { fg = surface_border, bg = surface })
  hl('FloatTitle', { fg = blue, bg = surface, bold = true })
  hl('Cursor', { fg = ink(fg), bg = fg })
  hl('CursorLine', { bg = line })
  hl('ColorColumn', { bg = line })
  hl('LineNr', { fg = comment })
  hl('CursorLineNr', { fg = blue, bold = true })
  hl('SignColumn', { bg = 'none' })
  hl('FoldColumn', { fg = border, bg = 'none' })
  -- On the cursor line the sign and fold columns are drawn with CursorLineSign
  -- and CursorLineFold (:help hl-CursorLineSign). Both default to linking at
  -- SignColumn / FoldColumn, whose background is 'none' here, so the cursor
  -- line's highlight stopped at the sign column and the stripe looked cut off.
  -- Give them the cursor line's own background instead.
  hl('CursorLineSign', { bg = line })
  hl('CursorLineFold', { fg = border, bg = line })
  hl('Folded', { fg = comment, bg = line })
  -- Deliberately under the 3:1 shape floor: on a transparent background the
  -- alternative is a bright column of tildes.
  hl('EndOfBuffer', { fg = line })
  hl('WinSeparator', { fg = border, bg = 'none' })
  link('VertSplit', 'WinSeparator')
  hl('NonText', { fg = border })
  hl('SpecialKey', { fg = comment })
  hl('Whitespace', { fg = comment })
  hl('Conceal', { fg = comment })
  hl('Directory', { fg = blue })
  hl('Title', { fg = blue, bold = true })
  hl('Question', { fg = green })
  hl('MoreMsg', { fg = green })
  hl('WarningMsg', { fg = yellow })
  hl('ErrorMsg', { fg = red })
  hl('ModeMsg', { fg = fg, bold = true })
  hl('MatchParen', { fg = magenta, bold = true, underline = true })

  -- Menus, bars, selection. A filled group inverts the pair the picker
  -- measured (foreground on the accent), so the same ratio holds.
  hl('StatusLine', { fg = fg, bg = bar })
  hl('StatusLineNC', { fg = comment, bg = line })
  hl('TabLine', { fg = comment, bg = 'none' })
  hl('TabLineSel', { fg = fg, bg = 'none', bold = true })
  hl('TabLineFill', { bg = 'none' })
  hl('Pmenu', { fg = fg, bg = surface })
  -- The border is drawn because pumborder is set; without its own color it
  -- links to Pmenu and disappears against the menu.
  hl('PmenuBorder', { fg = surface_border, bg = surface })
  hl('PmenuSel', { fg = ink(blue), bg = blue, bold = true })
  hl('PmenuKind', { fg = comment, bg = surface })
  hl('PmenuExtra', { fg = comment, bg = surface })
  hl('PmenuSbar', { bg = line })
  hl('PmenuThumb', { bg = comment })
  hl('WildMenu', { fg = ink(blue), bg = blue })
  hl('Visual', { bg = selection })
  hl('VisualNOS', { bg = selection })
  hl('Search', { fg = ink(yellow), bg = yellow })
  hl('IncSearch', { fg = ink(blue), bg = blue })
  link('CurSearch', 'IncSearch')
  hl('Substitute', { fg = ink(red), bg = red })
  hl('QuickFixLine', { bg = line })

  -- Statusline segments; lua/statusline.lua names these groups.
  hl('StlBar', { fg = fg, bg = bar })
  hl('StlFile', { fg = fg, bg = bar, bold = true })
  hl('StlGit', { fg = blue, bg = bar })
  hl('StlInfo', { fg = comment, bg = bar })
  hl('StlPos', { fg = fg, bg = bar })
  hl('StlSep', { fg = surface_border, bg = bar })
  -- The badge is a filled block, so its background has to stand off the bar by
  -- 3:1 or the mode stops reading as a block when the accent sits near the
  -- bar's mix. The text on it is measured against that fill, not the accent.
  local function badge(accent)
    return readable({ accent, mix(accent, fg, 0.35), mix(accent, fg, 0.65), fg, '#000000', '#ffffff' }, bar, 3)
  end
  for name, accent in pairs({
    Normal = c[4], Insert = c[2], Visual = c[5],
    Replace = c[1], Command = c[3], Terminal = c[6],
  }) do
    local fill = badge(accent)
    hl('StlMode' .. name, { fg = ink(fill), bg = fill, bold = true })
  end

  -- Spelling
  hl('SpellBad', { sp = red, undercurl = true })
  hl('SpellCap', { sp = yellow, undercurl = true })
  hl('SpellLocal', { sp = cyan, undercurl = true })
  hl('SpellRare', { sp = magenta, undercurl = true })

  -- Added/Changed/Removed are builtin (runtime/syntax/diff.vim links diffAdded
  -- to Added), so `:diffthis` and `git diff` buffers color from here.
  hl('DiffAdd', { bg = mix(bg, green, 0.18) })
  hl('DiffChange', { bg = mix(bg, yellow, 0.18) })
  hl('DiffDelete', { bg = mix(bg, red, 0.18) })
  hl('DiffText', { bg = mix(bg, blue, 0.30) })
  hl('Added', { fg = green })
  hl('Changed', { fg = yellow })
  hl('Removed', { fg = red })

  -- Diagnostics
  for name, color in pairs({ Error = red, Warn = yellow, Info = blue, Hint = cyan, Ok = green }) do
    hl('Diagnostic' .. name, { fg = color })
    hl('DiagnosticSign' .. name, { fg = color })
    hl('DiagnosticVirtualText' .. name, { fg = color })
    hl('DiagnosticFloating' .. name, { fg = color, bg = surface })
    hl('DiagnosticUnderline' .. name, { sp = color, undercurl = true })
  end
  hl('DiagnosticUnnecessary', { fg = comment })
  hl('DiagnosticDeprecated', { fg = comment, strikethrough = true })
  hl('LspInlayHint', { fg = comment, italic = true })
  hl('LspCodeLens', { fg = comment })
  hl('LspReferenceText', { bg = line })
  hl('LspReferenceRead', { bg = line })
  hl('LspReferenceWrite', { bg = line, underline = true })

  -- Legacy syntax groups: plugins and the LSP semantic token map link to these
  -- names.
  hl('Comment', { fg = comment, italic = true })
  hl('SpecialComment', { fg = comment, italic = true })
  hl('Delimiter', { fg = comment })
  hl('Constant', { fg = yellow })
  hl('String', { fg = green })
  hl('Character', { fg = green })
  hl('Number', { fg = yellow })
  hl('Boolean', { fg = yellow })
  hl('Float', { fg = yellow })
  hl('Identifier', { fg = fg })
  hl('Function', { fg = blue })
  hl('Statement', { fg = magenta })
  hl('Conditional', { fg = magenta })
  hl('Repeat', { fg = magenta })
  hl('Label', { fg = magenta })
  hl('Keyword', { fg = magenta })
  hl('Exception', { fg = magenta })
  hl('Operator', { fg = fg })
  hl('PreProc', { fg = red })
  hl('Include', { fg = red })
  hl('Define', { fg = red })
  hl('Macro', { fg = red })
  hl('PreCondit', { fg = red })
  hl('Special', { fg = red })
  hl('SpecialChar', { fg = red })
  hl('Debug', { fg = red })
  hl('Type', { fg = cyan })
  hl('StorageClass', { fg = cyan })
  hl('Structure', { fg = cyan })
  hl('Typedef', { fg = cyan })
  hl('Tag', { fg = cyan })
  hl('Underlined', { fg = blue, underline = true })
  hl('Ignore', { fg = comment })
  hl('Error', { fg = red })
  hl('Todo', { fg = ink(yellow), bg = yellow, bold = true })

  -- Treesitter captures, grouped by the color they take.
  local paint = {
    comment = { fg = comment, italic = true },
    punctuation = { fg = comment },
    string = { fg = green },
    special = { fg = red },
    constant = { fg = yellow },
    keyword = { fg = magenta },
    ['function'] = { fg = blue },
    type = { fg = cyan },
    variable = { fg = fg },
    -- Language-provided names (self, vim, True) read as builtins, not data.
    builtin = { fg = magenta, italic = true },
  }

  local captures = {
    comment = { '@comment', '@comment.documentation', '@comment.note', '@punctuation.delimiter', '@punctuation.bracket', '@punctuation.special' },
    punctuation = { '@punctuation' },
    string = { '@string', '@string.regexp', '@string.documentation', '@character', '@markup.raw', '@markup.raw.block' },
    special = { '@string.escape', '@string.special', '@string.special.symbol', '@character.special', '@string.special.url', '@comment.error', '@comment.warning' },
    constant = { '@constant', '@number', '@number.float', '@boolean' },
    keyword = {
      '@keyword', '@keyword.coroutine', '@keyword.function', '@keyword.operator',
      '@keyword.import', '@keyword.type', '@keyword.modifier', '@keyword.repeat',
      '@keyword.return', '@keyword.debug', '@keyword.exception', '@keyword.conditional',
      '@keyword.directive',
    },
    ['function'] = {
      '@function', '@function.call', '@function.macro', '@function.method',
      '@function.method.call', '@constructor', '@module',
    },
    type = { '@type', '@type.definition', '@attribute', '@tag', '@tag.builtin' },
    variable = { '@variable', '@variable.parameter', '@variable.member', '@property', '@field' },
    builtin = {
      '@variable.builtin', '@constant.builtin', '@function.builtin',
      '@type.builtin', '@module.builtin',
    },
  }
  for kind, groups in pairs(captures) do
    for _, group in ipairs(groups) do hl(group, paint[kind]) end
  end

  -- Markdown and diff captures that are not plain foreground colors.
  hl('@markup.heading', { fg = blue, bold = true })
  for level = 1, 6 do hl('@markup.heading.' .. level, { fg = blue, bold = true }) end
  hl('@markup.strong', { fg = fg, bold = true })
  hl('@markup.italic', { italic = true })
  hl('@markup.strikethrough', { strikethrough = true })
  hl('@markup.underline', { underline = true })
  hl('@markup.quote', { fg = comment, italic = true })
  hl('@markup.math', { fg = yellow })
  hl('@markup.link', { fg = cyan, underline = true })
  hl('@markup.link.label', { fg = cyan })
  hl('@markup.link.url', { fg = comment, underline = true })
  hl('@markup.list', { fg = magenta })
  hl('@markup.list.checked', { fg = green })
  hl('@markup.list.unchecked', { fg = comment })
  hl('@diff.plus', { fg = green })
  hl('@diff.delta', { fg = yellow })
  hl('@diff.minus', { fg = red })
  hl('@tag.delimiter', { fg = comment })
  hl('@tag.attribute', { fg = cyan })
  hl('@label', { fg = magenta })

  -- nvim-tree sidebar. The tree keeps the transparent background; the vertical
  -- separator and the statusline are what mark it as a panel.
  hl('NvimTreeNormal', { fg = fg, bg = 'none' })
  hl('NvimTreeNormalNC', { fg = comment, bg = 'none' })
  hl('NvimTreeWinSeparator', { fg = border, bg = 'none' })
  hl('NvimTreeEndOfBuffer', { fg = line, bg = 'none' })
  hl('NvimTreeCursorLine', { bg = line })
  hl('NvimTreeCursorLineNr', { fg = comment, bg = line })
  hl('NvimTreeLineNr', { fg = comment, bg = 'none' })
  hl('NvimTreeSignColumn', { bg = 'none' })
  hl('NvimTreeStatusLine', { fg = fg, bg = bar })
  hl('NvimTreeStatusLineNC', { fg = comment, bg = line })
  hl('NvimTreeRootFolder', { fg = blue, bold = true })
  hl('NvimTreeFolderIcon', { fg = blue })
  hl('NvimTreeFolderName', { fg = fg })
  hl('NvimTreeOpenedFolderName', { fg = blue, bold = true })
  hl('NvimTreeEmptyFolderName', { fg = comment })
  hl('NvimTreeOpenedFile', { fg = blue, bold = true })
  hl('NvimTreeFileIcon', { fg = comment })
  hl('NvimTreeSpecialFile', { fg = cyan, underline = true })
  hl('NvimTreeSymlink', { fg = cyan })
  hl('NvimTreeExecFile', { fg = green, bold = true })
  hl('NvimTreeImageFile', { fg = magenta })
  hl('NvimTreeIndentMarker', { fg = border })
  -- The plugin's group for filtered-out names is NvimTreeHiddenDisplay, not
  -- NvimTreeHiddenByFilter.
  hl('NvimTreeHiddenDisplay', { fg = comment })
  hl('NvimTreeGitDirty', { fg = yellow })
  hl('NvimTreeGitStaged', { fg = green })
  hl('NvimTreeGitRenamed', { fg = cyan })
  hl('NvimTreeGitNew', { fg = green })
  hl('NvimTreeGitDeleted', { fg = red })
  hl('NvimTreeGitMerge', { fg = magenta })
  hl('NvimTreeGitIgnored', { fg = comment })
  hl('NvimTreeDiagnosticErrorIcon', { fg = red })
  hl('NvimTreeDiagnosticWarnIcon', { fg = yellow })
  hl('NvimTreeDiagnosticInfoIcon', { fg = blue })
  hl('NvimTreeDiagnosticHintIcon', { fg = cyan })
  hl('NvimTreeNormalFloat', { fg = fg, bg = surface })
  hl('NvimTreeNormalFloatBorder', { fg = surface_border, bg = surface })
  hl('NvimTreePopup', { fg = fg, bg = surface })
  hl('NvimTreeLiveFilterPrefix', { fg = yellow, bold = true })
  hl('NvimTreeLiveFilterValue', { fg = fg, bold = true })
  hl('NvimTreeWindowPicker', { fg = ink(blue), bg = blue, bold = true })

  -- `highlight clear` above dropped every group, plugin-owned ones included. A
  -- real colorscheme gets this event from `:colorscheme`; called as a function,
  -- this one has to fire it so the plugins that hook it (mini.icons,
  -- mini.starter, which-key) put their groups back. fzf-lua polls
  -- vim.g.colors_name instead and needs the explicit call, but only once
  -- loaded (not at startup, where it registers its own groups right after).
  vim.api.nvim_exec_autocmds('ColorScheme', {})
  if package.loaded['fzf-lua'] then require('fzf-lua').setup_highlights() end
end

-- Re-read the palette on focus, so a wallpaper change reaches an open editor.
-- pywal has no post-run hook, so the file is the only signal (~0.2ms to read).
-- `apply` runs only when the file differs from what is on screen, so a no-op
-- focus event costs one read and no redraw.
function M.reload()
  local p = M.palette()
  if not p then return end
  if M.active and p.background == M.active.background and p.foreground == M.active.foreground
    and (function()
      for i = 0, 15 do
        if p['color' .. i] ~= M.active['color' .. i] then return false end
      end
      return true
    end)()
  then
    return
  end
  M.apply()
end

vim.api.nvim_create_autocmd('FocusGained', {
  desc = 'Re-read the terminal palette when the terminal regains focus',
  group = vim.api.nvim_create_augroup('user_theme_reload', { clear = true }),
  callback = function()
    local ok, err = pcall(M.reload)
    if not ok then
      -- A bad palette should never surface as an error on every focus.
      vim.notify('theme reload failed: ' .. tostring(err), vim.log.levels.WARN)
    end
  end,
})

M.apply()

return M
