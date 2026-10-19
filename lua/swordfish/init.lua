---@class SwordfishConfig
---@field highlight string Highlight group used for struck text.
---@field highlight_opts table Additional options for the highlight group.
---@field commands boolean Whether to create Swordfish user commands.
---@field keymaps table|false Keymaps, or false to disable the defaults.

local M = {}

local export = require("swordfish.export")
local marks = require("swordfish.marks")
local range = require("swordfish.range")

local defaults = {
	highlight = "SwordfishStrikeThrough",
	highlight_opts = {},
	commands = true,
	keymaps = {
		normal = "<leader>co",
		visual = "<leader>co",
	},
}

local config = vim.deepcopy(defaults)
local installed_keymaps = {}
local installed_commands = {}

local function leave_visual_mode()
	local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
	vim.api.nvim_feedkeys(escape, "nx", false)
end

function M.toggle_visual()
	local bufnr = vim.api.nvim_get_current_buf()
	marks.toggle(bufnr, range.visual(bufnr), config.highlight)
	leave_visual_mode()
end

local function current_line_range(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

	return {
		{
			row = row,
			start_col = 0,
			end_col = #line,
		},
	}
end

function M.toggle_line()
	local bufnr = vim.api.nvim_get_current_buf()
	marks.toggle(bufnr, current_line_range(bufnr), config.highlight)
end

function M.strike_line()
	local bufnr = vim.api.nvim_get_current_buf()
	marks.strike(bufnr, current_line_range(bufnr), config.highlight)
end

function M.unstrike_line()
	local bufnr = vim.api.nvim_get_current_buf()
	marks.unstrike(bufnr, current_line_range(bufnr), config.highlight)
end

local function notify_no_selection()
	vim.notify("Swordfish: no previous visual selection", vim.log.levels.WARN)
end

function M.strike_visual()
	local bufnr = vim.api.nvim_get_current_buf()
	marks.strike(bufnr, range.visual(bufnr), config.highlight)
	leave_visual_mode()
end

function M.unstrike_visual()
	local bufnr = vim.api.nvim_get_current_buf()
	marks.unstrike(bufnr, range.visual(bufnr), config.highlight)
	leave_visual_mode()
end

function M.strike_selected()
	local bufnr = vim.api.nvim_get_current_buf()
	local ranges = range.last_visual(bufnr)
	if #ranges == 0 then
		notify_no_selection()
		return
	end

	marks.strike(bufnr, ranges, config.highlight)
end

function M.unstrike_selected()
	local bufnr = vim.api.nvim_get_current_buf()
	local ranges = range.last_visual(bufnr)
	if #ranges == 0 then
		notify_no_selection()
		return
	end

	marks.unstrike(bufnr, ranges, config.highlight)
end

local function delete_installed_keymaps()
	for _, mapping in ipairs(installed_keymaps) do
		pcall(vim.keymap.del, mapping.mode, mapping.lhs)
	end
	installed_keymaps = {}
end

local function install_keymap(mode, lhs, callback, description)
	if not lhs then
		return
	end

	vim.keymap.set(mode, lhs, callback, { desc = description })
	installed_keymaps[#installed_keymaps + 1] = { mode = mode, lhs = lhs }
end

local function delete_installed_commands()
	for _, name in ipairs(installed_commands) do
		pcall(vim.api.nvim_del_user_command, name)
	end
	installed_commands = {}
end

local function create_command(name, callback, description, options)
	local command_options = vim.tbl_extend("force", {
		desc = description,
		force = true,
	}, options or {})
	vim.api.nvim_create_user_command(name, callback, command_options)
	installed_commands[#installed_commands + 1] = name
end

---@param opts SwordfishConfig|nil
function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

	local highlight_opts = vim.tbl_deep_extend("force", {
		default = true,
		strikethrough = true,
	}, config.highlight_opts)
	vim.api.nvim_set_hl(0, config.highlight, highlight_opts)

	delete_installed_keymaps()
	delete_installed_commands()

	if config.commands then
		create_command("SwordfishStrike", M.strike_line, "Strike the current line")
		create_command("SwordfishUnstrike", M.unstrike_line, "Remove strikethrough from the current line")
		create_command("SwordfishStrikeSelected", M.strike_selected, "Strike the last visual selection", { range = true })
		create_command("SwordfishUnstrikeSelected", M.unstrike_selected, "Remove strikethrough from the last visual selection", { range = true })
		create_command("SwordfishWrite", export.write, "Write a struck-through text version to a file", {
			bang = true,
			complete = "file",
			nargs = "?",
		})
	end

	if config.keymaps then
		install_keymap("n", config.keymaps.normal, M.toggle_line, "Toggle strikethrough")
		install_keymap("x", config.keymaps.visual, M.toggle_visual, "Toggle strikethrough")
	end
end

return M
