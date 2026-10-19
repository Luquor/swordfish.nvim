local M = {}

-- U+0336 COMBINING LONG STROKE OVERLAY, used only in exported text.
local strike_overlay = "\xCC\xB6"

local function utf8_char_width(line, byte_index)
	local byte = line:byte(byte_index + 1)
	if not byte then
		return 0
	end

	if byte < 0x80 then
		return 1
	elseif byte < 0xE0 then
		return 2
	elseif byte < 0xF0 then
		return 3
	end

	return 4
end

local function render_line(line, ranges)
	if #ranges == 0 or line == "" then
		return line
	end

	table.sort(ranges, function(first, second)
		return first.start_col < second.start_col
	end)

	local output = {}
	local range_index = 1
	local byte_index = 0

	while byte_index < #line do
		while range_index <= #ranges and ranges[range_index].end_col <= byte_index do
			range_index = range_index + 1
		end

		local width = utf8_char_width(line, byte_index)
		local character = line:sub(byte_index + 1, byte_index + width)
		local current_range = ranges[range_index]
		local struck = current_range
			and current_range.start_col <= byte_index
			and byte_index < current_range.end_col

		output[#output + 1] = character
		if struck then
			output[#output + 1] = strike_overlay
		end

		byte_index = byte_index + width
	end

	return table.concat(output)
end

---@param bufnr integer
---@return string[]
function M.render(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local ranges_by_row = {}

	for _, range in ipairs(require("swordfish.marks").ranges(bufnr)) do
		if range.row == range.end_row then
			ranges_by_row[range.row] = ranges_by_row[range.row] or {}
			ranges_by_row[range.row][#ranges_by_row[range.row] + 1] = range
		end
	end

	for row, ranges in pairs(ranges_by_row) do
		lines[row + 1] = render_line(lines[row + 1] or "", ranges)
	end

	return lines
end

---@param opts table User-command options.
function M.write(opts)
	local filename = opts.args ~= "" and vim.fn.expand(opts.args) or vim.api.nvim_buf_get_name(0)
	if filename == "" then
		error("Swordfish: provide a filename to :SwordfishWrite")
	end

	if not opts.bang and vim.fn.filereadable(filename) == 1 then
		error("Swordfish: file exists; use :SwordfishWrite! to overwrite it")
	end

	local result = vim.fn.writefile(M.render(vim.api.nvim_get_current_buf()), filename, "b")
	if result ~= 0 then
		error("Swordfish: could not write " .. filename)
	end

	vim.notify("Swordfish: wrote " .. filename, vim.log.levels.INFO)
end

return M
