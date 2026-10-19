local M = {}

local namespace = vim.api.nvim_create_namespace("swordfish")

local function range_from_mark(mark)
	local details = mark[4]
	if not details or details.end_row == nil or details.end_col == nil then
		return nil
	end

	return {
		id = mark[1],
		row = mark[2],
		start_col = mark[3],
		end_row = details.end_row,
		end_col = details.end_col,
	}
end

local function ranges_overlap(first, second)
	return first.row == second.row
		and (first.end_row or first.row) == second.row
		and first.start_col < second.end_col
		and second.start_col < first.end_col
end

local function add_range(bufnr, range, highlight)
	if range.start_col >= range.end_col then
		return
	end

	vim.api.nvim_buf_set_extmark(bufnr, namespace, range.row, range.start_col, {
		end_row = range.row,
		end_col = range.end_col,
		hl_group = highlight,
		priority = 100,
	})
end

local function marks_for_buffer(bufnr)
	local marks = {}
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })) do
		local range = range_from_mark(mark)
		if range and range.row == range.end_row then
			marks[#marks + 1] = range
		end
	end

	return marks
end

local function subtract_ranges(source, cutters)
	local remaining = {
		{
			row = source.row,
			start_col = source.start_col,
			end_col = source.end_col,
		},
	}

	for _, cutter in ipairs(cutters) do
		local next_remaining = {}
		for _, piece in ipairs(remaining) do
			if not ranges_overlap(piece, cutter) then
				next_remaining[#next_remaining + 1] = piece
			else
				if piece.start_col < cutter.start_col then
					next_remaining[#next_remaining + 1] = {
						row = piece.row,
						start_col = piece.start_col,
						end_col = cutter.start_col,
					}
				end
				if cutter.end_col < piece.end_col then
					next_remaining[#next_remaining + 1] = {
						row = piece.row,
						start_col = cutter.end_col,
						end_col = piece.end_col,
					}
				end
			end
		end
		remaining = next_remaining
	end

	return remaining
end

---@param bufnr integer
---@return table[]
function M.ranges(bufnr)
	return marks_for_buffer(bufnr)
end

---@param bufnr integer
---@param ranges table[]
---@param highlight string
function M.strike(bufnr, ranges, highlight)
	local marks = marks_for_buffer(bufnr)

	for _, target in ipairs(ranges) do
		local additions = subtract_ranges(target, marks)
		for _, addition in ipairs(additions) do
			add_range(bufnr, addition, highlight)
			marks[#marks + 1] = addition
		end
	end
end

---@param bufnr integer
---@param ranges table[]
---@param highlight string
function M.unstrike(bufnr, ranges, highlight)
	local marks = marks_for_buffer(bufnr)

	for _, mark in ipairs(marks) do
		local replacements = subtract_ranges(mark, ranges)
		local changed = #replacements ~= 1
		if not changed and replacements[1].start_col ~= mark.start_col then
			changed = true
		end
		if not changed and replacements[1].end_col ~= mark.end_col then
			changed = true
		end

		if changed then
			vim.api.nvim_buf_del_extmark(bufnr, namespace, mark.id)
			for _, replacement in ipairs(replacements) do
				add_range(bufnr, replacement, highlight)
			end
		end
	end
end

---@param bufnr integer
---@param ranges table[]
---@param highlight string
function M.toggle(bufnr, ranges, highlight)
	if #ranges == 0 then
		return
	end

	local marks = marks_for_buffer(bufnr)
	local has_struck_text = false
	for _, target in ipairs(ranges) do
		for _, mark in ipairs(marks) do
			if ranges_overlap(mark, target) then
				has_struck_text = true
				break
			end
		end
		if has_struck_text then
			break
		end
	end

	if has_struck_text then
		M.unstrike(bufnr, ranges, highlight)
	else
		M.strike(bufnr, ranges, highlight)
	end
end

function M.clear(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
end

return M
