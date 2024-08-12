local Render = require("codegpt.template_render")
local Utils = require("codegpt.utils")

OpenAIProvider = {}

local function generate_messages(command, cmd_opts, command_args, text_selection)
    local system_message = Render.render(command, cmd_opts.system_message_template, command_args, text_selection,
        cmd_opts)
    local user_message = Render.render(command, cmd_opts.user_message_template, command_args, text_selection, cmd_opts)

    local messages = {}
    if system_message ~= nil and system_message ~= "" then
        table.insert(messages, { role = "system", content = system_message })
    end

    if user_message ~= nil and user_message ~= "" then
        table.insert(messages, { role = "user", content = user_message })
    end

    return messages
end

function OpenAIProvider.make_request(command, cmd_opts, command_args, text_selection)
    local messages = generate_messages(command, cmd_opts, command_args, text_selection)

    local request = {
        temperature = cmd_opts.temperature,
        frequency_penalty = cmd_opts.frequency_penalty,
        n = cmd_opts.number_of_choices,
        model = cmd_opts.model,
        messages = messages,
        max_tokens = 4096,
        stream = true,
    }

    return request
end

function OpenAIProvider.make_headers()
    local token = vim.g["codegpt_openai_api_key"]
    if not token then
        error(
            "OpenAIApi Key not found, set in vim with 'codegpt_openai_api_key' or as the env variable 'OPENAI_API_KEY'"
        )
    end

    return { Content_Type = "application/json", Authorization = "Bearer " .. token }
end

function OpenAIProvider.handle_response(json, cb, cancel)
    if json == nil then
        print("Response empty")
    elseif json.error then
        print("Error: " .. json.error.message)
    elseif not json.choices or 0 == #json.choices or (not json.choices[1].message and not json.choices[1].delta) then
        print("Error: " .. vim.fn.json_encode(json))
    else
        local response_text
        if json.choices[1].delta then
            response_text = json.choices[1].delta.content
        else
            response_text = json.choices[1].message.content
        end

        if response_text ~= nil then
            if type(response_text) ~= "string" then
                print("Error: No response text " .. type(response_text))
            else
                local bufnr = vim.api.nvim_get_current_buf()
                if vim.g["codegpt_clear_visual_selection"] then
                    vim.api.nvim_buf_set_mark(bufnr, "<", 0, 0, {})
                    vim.api.nvim_buf_set_mark(bufnr, ">", 0, 0, {})
                end
                local lines = Utils.parse_lines(response_text)
                if lines == nil then
                    print("Error: No response text")
                    return
                end
                cb(lines, cancel)
            end
        end
    end
end

return OpenAIProvider
