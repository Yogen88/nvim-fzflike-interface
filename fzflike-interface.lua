local M = {}

local winnr = -1
local buffsize = 0
local setcursor = false
local lines = {}

function M.moveup()
		if vim.api.nvim_win_get_cursor(winnr)[1] > 1 then
			vim.api.nvim_win_set_cursor(winnr, {vim.api.nvim_win_get_cursor(winnr)[1]-1,0})
			vim.cmd [[ redraw! ]]
		end
end

function M.movedown()
		if vim.api.nvim_win_get_cursor(winnr)[1] < buffsize then
			vim.api.nvim_win_set_cursor(winnr, {vim.api.nvim_win_get_cursor(winnr)[1]+1,0})
			vim.cmd [[ redraw! ]]
		end
end

function M.open()
		vim.cmd [[ above new ]]
		vim.api.nvim_command('edit '..lines[vim.api.nvim_win_get_cursor(winnr)[1]])
end

function M.test()
	local log_buf = vim.api.nvim_create_buf(true, true)
	local edit_buf = vim.api.nvim_create_buf(true, true)
	local lastjob = -1

	vim.cmd [[ below new ]]
	winnr = vim.fn.win_getid()
	vim.api.nvim_set_current_buf(log_buf)
	vim.cmd [[ setlocal cursorline ]]
	vim.cmd [[ below new ]]
	vim.cmd [[ resize 1 ]]
	vim.api.nvim_set_current_buf(edit_buf)
	vim.cmd [[ startinsert ]]

  	local opts = { noremap=true, silent=true, nowait=true }
	vim.api.nvim_buf_set_keymap(edit_buf, "i", "<Down>", '<Cmd>lua require"async_cout".movedown()<cr>', opts)
	vim.api.nvim_buf_set_keymap(edit_buf, "i", "<Up>", '<Cmd>lua require"async_cout".moveup()<cr>', opts)
	vim.api.nvim_buf_set_keymap(edit_buf, "i", "<CR>", '<Cmd>lua require"async_cout".open()<cr>', opts)

	Clear = function()
		vim.api.nvim_buf_set_lines(log_buf, 0, -1, true, { '' })
	end

	run = function(inlines)
		lines = {}
		buffsize = 0
		setcursor = false
		local function on_event(job_id, data, event)
			if event == "stdout" or event == "stderr" then
				if data then
					for k, v in ipairs(data) do
						if v ~= "" and v ~= "\r" and v~=nil then
							local n = string.gsub(v, "\r", "")
							if(n ~= nil) then
								table.insert(lines, n)
							end
						end
					end
					if job_id == lastjob then
						vim.api.nvim_buf_set_lines(log_buf, 0, -1, true, lines)
						buffsize = table.getn(lines)
					end
					if setcursor == false then
						vim.api.nvim_win_set_cursor(winnr, {1,0})
						setcursor = true
					end
				end
			end

			if event == "exit" then
			end
		end

		lastjob =
		vim.fn.jobstart(
		"es -path . " .. table.concat(inlines, " "),
		{
			on_stderr = on_event,
			on_stdout = on_event,
			on_exit = on_event
		})
	end


	local callback = function(_, _, tick, firstline, lastline, new_lastline, _, _, _)
		local editlines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, true)

		local to_schedule = function()
			if lastjob ~= -1 then
				vim.fn.jobstop(lastjob)
			end
			run(editlines)
		end
		vim.schedule(to_schedule)
	end

	vim.api.nvim_buf_attach(edit_buf, false, { on_lines = callback })

end

return M
