local M = {}

-- This dictionary maps filenames to tables that keep track of active previews.
M.previews = {}

function M.startPreview()
	local filename = vim.api.nvim_buf_get_name(0)
	local preview = M.previews[filename] or {
		TempfilePath = vim.fn.tempname(),
	}

	local processorCmd = M.processors[vim.bo.filetype](preview.TempfilePath, vim.bo.filetype)
	if type(processorCmd) ~= "table" then
		vim.api.nvim_echo({
			{ "No processor is defined for the current filetype." },
		}, false, { err = true })
		return
	end

	local previewerCmd = M.previewers[vim.bo.filetype](preview.TempfilePath, vim.bo.filetype)
	if type(previewerCmd) ~= "table" then
		vim.api.nvim_echo({
			{ "No previewer is defined for the current filetype." },
		}, false, { err = true })
		return
	end

	M.previews[filename] = preview

	preview.ProcessorObj = vim.system(processorCmd, {
		text = true,
		stdin = vim.api.nvim_buf_get_lines(0, 0, -1, false),
	})

	local function processorFail()
		-- Don't clean up if processing fails but the previewer is (presumably) running.
		if not preview.PreviewerObj then
			os.remove(preview.TempfilePath)
			M.previews[filename] = nil
		end
	end

	local processorResult = preview.ProcessorObj:wait()
	preview.ProcessorObj = nil

	if processorResult.code ~= 0 then
		vim.api.nvim_echo({
			{ "Preview processor failed or terminated." },
		}, false, { err = true })
		processorFail()
		return
	end

	if vim.fn.filereadable(preview.TempfilePath) == 0 then
		vim.api.nvim_echo({
			{ "Preview output missing or unreadable." },
		}, false, { err = true })
		processorFail()
		return
	end

	if preview.PreviewerObj then
		print("Preview file refreshed.")
	else
		preview.PreviewerObj = vim.system(previewerCmd, {})
	end
end

function M.stopPreview()
	local filename = vim.api.nvim_buf_get_name(0)
	local preview = M.previews[filename]

	if not preview then
		vim.api.nvim_echo({
			{ "No preview is active for this buffer." },
		}, false, { err = true })
		return
	end

	if preview.ProcessorObj then
		preview.ProcessorObj:kill(15)
	end

	os.remove(preview.TempfilePath)

	M.previews[filename] = nil

	print("Preview file cleaned up.")
end

function M.stopAllPreviews()
	local count = 0

	for filename, preview in pairs(M.previews) do
		if preview.ProcessorObj then
			preview.ProcessorObj:kill(15)
		end

		os.remove(preview.TempfilePath)

		M.previews[filename] = nil
		count = count + 1
	end

	print(string.format("%d preview file(s) cleaned up.", count))
end

function M.setup(opts)
	opts = opts or {}

	local defaultHandlingMetatable = {
		__index = function(self, index)
			local default = rawget(self, "")

			if not default then
				function default()
					return nil
				end
				rawset(self, "", default)
			end

			rawset(self, index, default)
			return default
		end,
	}

	M.processors = setmetatable(opts.processors or {
		["markdown"] = function(outputPath, _)
			return { "pandoc", "-f", "commonmark_x", "-t", "html", "-o", outputPath }
		end,
		["rst"] = function(outputPath, _)
			return { "pandoc", "-f", "rst", "-t", "html", "-o", outputPath }
		end,

		[""] = function(outputPath, filetype)
			if filetype == "make" then
				filetype = "makefile"
			end
			return { "highlight", "-S", filetype, "-O", "html", "-k", "monospace", "-o", outputPath }
		end,
	}, defaultHandlingMetatable)

	M.previewers = setmetatable(opts.previewers or {
		[""] = function(outputPath, _)
			return { vim.env.BROWSER, outputPath }
		end,
	}, defaultHandlingMetatable)

	opts.keymaps = opts.keymaps or {}

	vim.keymap.set({ "n", "v" }, opts.keymaps.start or "+", M.startPreview)
	vim.keymap.set({ "n", "v" }, opts.keymaps.stop or "-", M.stopPreview)
	vim.keymap.set({ "n", "v" }, opts.keymaps.stopAll or "_", M.stopAllPreviews)

	vim.api.nvim_create_autocmd("BufDelete", {
		callback = function(event)
			local filename = vim.api.nvim_buf_get_name(event.buf)
			local preview = M.previews[filename]

			if not preview then
				return
			end

			if preview.ProcessorObj then
				preview.ProcessorObj:kill(15)
			end

			os.remove(preview.TempfilePath)

			M.previews[filename] = nil
		end,
	})
end

return M
