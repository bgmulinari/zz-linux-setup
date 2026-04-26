vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "noctalia"

local palette = {
  bg = "{{colors.surface.default.hex}}",
  bg_alt = "{{colors.surface_container.default.hex}}",
  bg_high = "{{colors.surface_container_high.default.hex}}",
  bg_highest = "{{colors.surface_container_highest.default.hex}}",
  fg = "{{colors.on_surface.default.hex}}",
  fg_muted = "{{colors.on_surface_variant.default.hex}}",
  border = "{{colors.outline.default.hex}}",
  accent = "{{colors.primary.default.hex}}",
  accent_alt = "{{colors.secondary.default.hex}}",
  accent_third = "{{colors.tertiary.default.hex}}",
  error = "{{colors.error.default.hex}}",
  error_bg = "{{colors.error_container.default.hex}}",
  error_fg = "{{colors.on_error_container.default.hex}}",
  match = "{{colors.primary_container.default.hex}}",
  match_fg = "{{colors.on_primary_container.default.hex}}",
  add = "{{colors.tertiary_container.default.hex}}",
  add_fg = "{{colors.on_tertiary_container.default.hex}}",
  change = "{{colors.secondary_container.default.hex}}",
  change_fg = "{{colors.on_secondary_container.default.hex}}",
}

local set = vim.api.nvim_set_hl

local groups = {
  Normal = { fg = palette.fg, bg = palette.bg },
  NormalNC = { fg = palette.fg, bg = palette.bg },
  NormalFloat = { fg = palette.fg, bg = palette.bg_alt },
  FloatBorder = { fg = palette.border, bg = palette.bg_alt },
  FloatTitle = { fg = palette.accent, bg = palette.bg_alt, bold = true },
  CursorLine = { bg = palette.bg_alt },
  CursorLineNr = { fg = palette.accent, bg = palette.bg_alt, bold = true },
  LineNr = { fg = palette.fg_muted, bg = palette.bg },
  SignColumn = { fg = palette.fg_muted, bg = palette.bg },
  ColorColumn = { bg = palette.bg_alt },
  CursorColumn = { bg = palette.bg_alt },
  FoldColumn = { fg = palette.fg_muted, bg = palette.bg },
  Folded = { fg = palette.fg_muted, bg = palette.bg_alt },
  EndOfBuffer = { fg = palette.bg },
  VertSplit = { fg = palette.border, bg = palette.bg },
  WinSeparator = { fg = palette.border, bg = palette.bg },
  StatusLine = { fg = palette.fg, bg = palette.bg_high },
  StatusLineNC = { fg = palette.fg_muted, bg = palette.bg_alt },
  Pmenu = { fg = palette.fg, bg = palette.bg_alt },
  PmenuSel = { fg = palette.match_fg, bg = palette.match, bold = true },
  PmenuSbar = { bg = palette.bg_high },
  PmenuThumb = { bg = palette.border },
  Visual = { bg = palette.bg_highest },
  Search = { fg = palette.match_fg, bg = palette.match },
  IncSearch = { fg = palette.bg, bg = palette.accent, bold = true },
  CurSearch = { fg = palette.bg, bg = palette.accent, bold = true },
  MatchParen = { fg = palette.accent, bold = true },
  Directory = { fg = palette.accent, bold = true },
  Title = { fg = palette.accent, bold = true },
  Question = { fg = palette.accent_alt },
  Comment = { fg = palette.fg_muted, italic = true },
  Constant = { fg = palette.accent_alt },
  String = { fg = palette.accent },
  Character = { fg = palette.accent },
  Number = { fg = palette.accent_third },
  Boolean = { fg = palette.accent_third, bold = true },
  Float = { fg = palette.accent_third },
  Identifier = { fg = palette.fg },
  Function = { fg = palette.accent, bold = true },
  Statement = { fg = palette.accent_alt, bold = true },
  Conditional = { fg = palette.accent_alt, bold = true },
  Repeat = { fg = palette.accent_alt, bold = true },
  Label = { fg = palette.accent_alt },
  Operator = { fg = palette.accent_alt },
  Keyword = { fg = palette.accent_alt, italic = true },
  Exception = { fg = palette.error },
  PreProc = { fg = palette.accent_third },
  Include = { fg = palette.accent_alt },
  Define = { fg = palette.accent_alt },
  Macro = { fg = palette.accent_alt },
  Type = { fg = palette.accent_third, bold = true },
  StorageClass = { fg = palette.accent_third },
  Structure = { fg = palette.accent_third },
  Typedef = { fg = palette.accent_third },
  Special = { fg = palette.accent },
  SpecialChar = { fg = palette.accent },
  Tag = { fg = palette.accent_alt },
  Delimiter = { fg = palette.fg_muted },
  SpecialComment = { fg = palette.fg_muted, italic = true },
  Debug = { fg = palette.error },
  Underlined = { fg = palette.accent, underline = true },
  Error = { fg = palette.error_fg, bg = palette.error_bg, bold = true },
  Todo = { fg = palette.bg, bg = palette.accent_third, bold = true },
  DiagnosticError = { fg = palette.error },
  DiagnosticWarn = { fg = palette.accent_alt },
  DiagnosticInfo = { fg = palette.accent },
  DiagnosticHint = { fg = palette.accent_third },
  DiagnosticOk = { fg = palette.accent_third },
  DiagnosticUnderlineError = { undercurl = true, sp = palette.error },
  DiagnosticUnderlineWarn = { undercurl = true, sp = palette.accent_alt },
  DiagnosticUnderlineInfo = { undercurl = true, sp = palette.accent },
  DiagnosticUnderlineHint = { undercurl = true, sp = palette.accent_third },
  DiffAdd = { fg = palette.add_fg, bg = palette.add },
  DiffChange = { fg = palette.change_fg, bg = palette.change },
  DiffDelete = { fg = palette.error_fg, bg = palette.error_bg },
  DiffText = { fg = palette.match_fg, bg = palette.match, bold = true },
}

for name, opts in pairs(groups) do
  set(0, name, opts)
end

vim.g.terminal_color_0 = "{{colors.shadow.default.hex}}"
vim.g.terminal_color_1 = "{{colors.error.default.hex}}"
vim.g.terminal_color_2 = "{{colors.primary.default.hex}}"
vim.g.terminal_color_3 = "{{colors.secondary.default.hex}}"
vim.g.terminal_color_4 = "{{colors.primary_fixed_dim.default.hex}}"
vim.g.terminal_color_5 = "{{colors.secondary_fixed_dim.default.hex}}"
vim.g.terminal_color_6 = "{{colors.tertiary.default.hex}}"
vim.g.terminal_color_7 = "{{colors.on_surface.default.hex}}"
vim.g.terminal_color_8 = "{{colors.outline.default.hex}}"
vim.g.terminal_color_9 = "{{colors.error.default.hex | lighten 10}}"
vim.g.terminal_color_10 = "{{colors.primary.default.hex | lighten 10}}"
vim.g.terminal_color_11 = "{{colors.secondary.default.hex | lighten 10}}"
vim.g.terminal_color_12 = "{{colors.primary_fixed.default.hex}}"
vim.g.terminal_color_13 = "{{colors.secondary_fixed.default.hex}}"
vim.g.terminal_color_14 = "{{colors.tertiary_fixed.default.hex}}"
vim.g.terminal_color_15 = "{{colors.on_surface.default.hex | lighten 10}}"
