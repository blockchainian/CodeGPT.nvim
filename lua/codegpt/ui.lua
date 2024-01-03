local Popup = require("nui.popup")
local Split = require("nui.split")
local event = require("nui.utils.autocmd").event

local Ui = {}

local popup
local split

local function get_offset(bufnr)
    local last_row = vim.api.nvim_buf_line_count(bufnr)
    if last_row == 0 then
        return 0, 0
    end
    local last_line = vim.api.nvim_buf_get_lines(bufnr, last_row - 1, last_row, true)[1]
    return last_row - 1, #last_line
end

local function setup_ui_element(type, lines, filetype, bufnr, start_row, start_col, end_row, end_col, ui_elem, cancel)
    -- mount/open the component
    ui_elem:mount()

    ui_elem:map("n", vim.g["codegpt_ui_commands"].cancel, function()
        if cancel then
            cancel()
        end
    end, { noremap = true, silent = true })

    ui_elem:map("n", vim.g["codegpt_ui_commands"].quit, function()
        if cancel then
            cancel()
        end
        ui_elem:unmount()
    end, { noremap = true, silent = true })

    -- set content
    local row, col = get_offset(ui_elem.bufnr)
    vim.api.nvim_buf_set_option(ui_elem.bufnr, "filetype", filetype)

    -- strip leading blank lines
    if row == 0 and col == 0 then
        while #lines > 0 and lines[1]:match("^%s*$") do
            table.remove(lines, 1)
        end
    end

    -- add section header per response
    if type == 'text_popup' then
        if row == 0 and col == 0 and #lines > 0 then -- first
            lines[1] = '# ' .. lines[1]
        elseif #lines == 1 and #lines[1] == 0 then   -- subsequent
            lines = { '', '', '# ' }
        end
    end

    vim.api.nvim_buf_set_text(ui_elem.bufnr, row, col, row, col, lines)

    -- move cursor
    row, col = get_offset(ui_elem.bufnr)
    local first_line = vim.fn.line('w0')
    local last_line = vim.fn.line('w$')
    local visible_lines = last_line - first_line + 1

    if row < visible_lines then
        -- (1,0)-based indexing
        vim.api.nvim_win_set_cursor(ui_elem.winid, { row + 1, math.max(col - 1, 0) })
    end

    vim.api.nvim_command('redraw')

    -- replace lines when ctrl-o pressed
    ui_elem:map("n", vim.g["codegpt_ui_commands"].use_as_output, function()
        local lines = vim.api.nvim_buf_get_lines(ui_elem.bufnr, 0, -1, false)
        Utils.fix_indentation(bufnr, start_row, end_row, lines)
        vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
        ui_elem:unmount()
    end)

    -- selecting all the content when ctrl-i is pressed
    -- so the user can proceed with another API request
    ui_elem:map("n", vim.g["codegpt_ui_commands"].use_as_input, function()
        vim.api.nvim_feedkeys("ggVG:Chat ", "n", false)
    end, { noremap = false })

    -- mapping custom commands
    for _, command in ipairs(vim.g.codegpt_ui_custom_commands) do
        ui_elem:map(command[1], command[2], command[3], command[4])
    end
end

local function create_horizontal()
    if not split then
        split = Split({
            relative = "editor",
            position = "bottom",
            size = vim.g["codegpt_horizontal_popup_size"],
        })
    end

    return split
end

local function create_vertical()
    if not split then
        split = Split({
            relative = "editor",
            position = "right",
            size = vim.g["codegpt_vertical_popup_size"],
        })
    end

    return split
end

local function create_popup(type)
    if not popup then
        local window_options

        if type == "code_popup" then
            window_options = vim.g["codegpt_code_popup_window_options"]
        else
            window_options = vim.g["codegpt_text_popup_window_options"]
        end
        if window_options == nil then
            window_options = {}
        end

        -- check the old wrap config variable and use it if it's not set
        if window_options["wrap"] == nil then
            window_options["wrap"] = vim.g["codegpt_wrap_popup_text"]
        end

        popup = Popup({
            enter = true,
            focusable = true,
            border = vim.g["codegpt_popup_border"],
            position = "50%",
            size = {
                width = "80%",
                height = "60%",
            },
            win_options = window_options,
        })
    end

    popup:update_layout(vim.g["codegpt_popup_options"])

    return popup
end

function Ui.popup(lines, type, filetype, bufnr, start_row, start_col, end_row, end_col, cancel)
    local popup_type = vim.g["codegpt_popup_type"]
    local ui_elem = nil
    if popup_type == "horizontal" then
        ui_elem = create_horizontal()
    elseif popup_type == "vertical" then
        ui_elem = create_vertical()
    else
        ui_elem = create_popup(type)
    end
    setup_ui_element(type, lines, filetype, bufnr, start_row, start_col, end_row, end_col, ui_elem, cancel)
end

return Ui
