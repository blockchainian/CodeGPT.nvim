local Utils = require("codegpt.utils")

local Render = {}

local function get_language()
    local filetype = Utils.get_filetype()
    if filetype == "cpp" then
        return "C++"
    elseif filetype == 'javascriptreact' then
        return "JSX"
    elseif filetype == 'typescriptreact' then
        return "TSX"
    else
        return filetype
    end
end

local function safe_replace(template, key, value)
    if value == nil then
        return template:gsub(key, "")
    end

    if type(value) == "table" then
        value = table.concat(value, "\n")
    end
    return template:gsub(key, value)
end

function Render.render(cmd, template, command_args, text_selection, cmd_opts)
    local language = get_language()
    local language_instructions = ""
    if cmd_opts.language_instructions ~= nil then
        language_instructions = cmd_opts.language_instructions[language]
    end

    template = safe_replace(template, "{{filetype}}", Utils.get_filetype())
    template = safe_replace(template, "{{text_selection}}", text_selection)
    template = safe_replace(template, "{{language}}", language)
    template = safe_replace(template, "{{command_args}}", command_args)
    template = safe_replace(template, "{{language_instructions}}", language_instructions)
    return template
end

return Render
