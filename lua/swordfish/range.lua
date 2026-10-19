local M = {}

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

---Return the byte offset immediately after the character at `column`.
---@param line string
---@param column integer One-indexed byte column, as returned by getpos().
---@return integer
local function character_end(line, column)
	local byte_index = column - 1
	if byte_index >= #line then
		return #line
	end

	return math.min(#line, byte_index + utf8_char_width(line, byte_index))
end

local function ordered_positions(first, second)
	if first[2] < second[2] or (first[2] == second[2] and first[3] <= second[3]) then
		return first, second
	end

	return second, first
end

local function is_visual_mode(mode)
	return mode == "v" or mode == "V" or mode == "\22"
end

local function line_ranges(bufnr, start_row, end_row, start_col, end_col)
	local ranges = {}
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

	for row = start_row, end_row do
		local line = lines[row - start_row + 1] or ""
		local range_start = row == start_row and start_col or 0
		local range_end = row == end_row and end_col or #line

		range_start = math.max(0, math.min(range_start, #line))
		range_end = math.max(0, math.min(range_end, #line))

		if range_start < range_end then
			ranges[#ranges + 1] = {
				row = row,
				start_col = range_start,
				end_col = range_end,
			}
		end
	end

	return ranges
end

local function visual_ranges(bufnr, first, second, mode)
	if not is_visual_mode(mode) then
		return {}
	end

	local cursor, anchor = ordered_positions(first, second)
	local start_row = cursor[2] - 1
	local end_row = anchor[2] - 1

	if mode == "V" then
		return line_ranges(bufnr, start_row, end_row, 0, math.huge)
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

	if mode == "\22" then
		local block_start = math.min(cursor[3], anchor[3]) - 1
		local block_end = math.max(cursor[3], anchor[3])
		local ranges = {}

		for row = start_row, end_row do
			local line = lines[row - start_row + 1] or ""
			if block_start < #line then
				local range_end = #line
				if block_end <= #line then
					range_end = character_end(line, block_end)
				end

				if block_start < range_end then
					ranges[#ranges + 1] = {
						row = row,
						start_col = block_start,
						end_col = range_end,
					}
				end
			end
		end

		return ranges
	end

	local start_col = cursor[3] - 1
	local end_line = lines[#lines] or ""
	local end_col = character_end(end_line, anchor[3])
	return line_ranges(bufnr, start_row, end_row, start_col, end_col)
end

---@param bufnr integer
---@return table[]
function M.visual(bufnr)
	return visual_ranges(bufnr, vim.fn.getpos("."), vim.fn.getpos("v"), vim.fn.mode())
end

---@param bufnr integer
---@return table[]
function M.last_visual(bufnr)
	local first = vim.fn.getpos("'<")
	local second = vim.fn.getpos("'>")
	if first[2] == 0 or second[2] == 0 then
		return {}
	end

	return visual_ranges(bufnr, first, second, vim.fn.visualmode())
end

return M
