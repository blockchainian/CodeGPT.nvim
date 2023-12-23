local Commands = require("codegpt.commands")
local CommandsList = require("codegpt.commands_list")
local Utils = require("codegpt.utils")
local CodeGptModule = {}

local function has_command_args(opts)
    local pattern = "%{%{command_args%}%}"
    return string.find(opts.user_message_template or "", pattern)
        or string.find(opts.system_message_template or "", pattern)
end

function CodeGptModule.get_status(...)
    return Commands.get_status(...)
end

function CodeGptModule.run_cmd(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local text_selection = Utils.get_selected_text(bufnr)
    local command_args = table.concat(opts.fargs, " ")

    local command = opts.fargs[1]

    if text_selection ~= "" and command_args ~= "" then
        local cmd_opts = CommandsList.get_cmd_opts(command)
        if cmd_opts ~= nil and has_command_args(cmd_opts) then
            command_args = table.concat(opts.fargs, " ", 2)
        elseif cmd_opts and 1 == #opts.fargs then
            command_args = ""
        else
            command = "code_edit"
        end
    elseif text_selection ~= "" and command_args == "" then
        command = "completion"
    elseif text_selection == "" and command_args ~= "" then
        command = "chat"
    end

    if command == nil or command == "" then
        vim.notify("No command or text selection provided", vim.log.levels.ERROR, {
            title = "CodeGPT",
        })
        return
    end

    Commands.run_cmd(command, command_args, text_selection)
end

return CodeGptModule
