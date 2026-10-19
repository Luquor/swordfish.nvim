if vim.g.loaded_swordfish then
	return
end

vim.g.loaded_swordfish = true

require("swordfish").setup()
