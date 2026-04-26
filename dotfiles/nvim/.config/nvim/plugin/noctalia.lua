vim.o.termguicolors = true

local function apply_noctalia()
  pcall(vim.cmd.colorscheme, "noctalia")
end

apply_noctalia()

local signal = vim.uv and vim.uv.new_signal() or nil
if signal then
  signal:start(
    "sigusr1",
    vim.schedule_wrap(function()
      package.loaded["colors.noctalia"] = nil
      apply_noctalia()
    end)
  )
end
