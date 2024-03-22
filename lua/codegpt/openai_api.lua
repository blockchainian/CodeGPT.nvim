local curl = require("plenary.curl")
local Providers = require("codegpt.providers")
local OpenAIApi = {}

CODEGPT_CALLBACK_COUNTER = 0

local status_index = 0
local progress_bar_dots = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function OpenAIApi.get_status(...)
    if CODEGPT_CALLBACK_COUNTER > 0 then
        status_index = status_index + 1
        if status_index > #progress_bar_dots then
            status_index = 1
        end
        return progress_bar_dots[status_index]
    else
        return ""
    end
end

local function run_started_hook()
    if vim.g["codegpt_hooks"]["request_started"] ~= nil then
        vim.g["codegpt_hooks"]["request_started"]()
    end

    CODEGPT_CALLBACK_COUNTER = CODEGPT_CALLBACK_COUNTER + 1
end

local function run_finished_hook()
    CODEGPT_CALLBACK_COUNTER = CODEGPT_CALLBACK_COUNTER - 1
    if CODEGPT_CALLBACK_COUNTER <= 0 then
        if vim.g["codegpt_hooks"]["request_finished"] ~= nil then
            vim.g["codegpt_hooks"]["request_finished"]()
        end
    end
end

local function curl_stream_handler(error, response, cb, cancel)
    if error ~= nil then
        print("Error: " .. error)
        run_finished_hook()
        return
    end

    if response == nil then
        run_finished_hook()
        return
    end

    local data = response:gsub("data: ", "")
    if data == "[DONE]" then
        run_finished_hook()
        return
    end
    if data == "" then
        return
    end

    vim.schedule_wrap(function(msg)
        -- cancellation often causes a misformed response.
        local ok, json = pcall(vim.fn.json_decode, msg)
        if ok then
            Providers.get_provider().handle_response(json, cb, cancel)
        end
    end)(data)
end

function OpenAIApi.make_call(payload, cb)
    local payload_str = vim.fn.json_encode(payload)
    local url = vim.g["codegpt_chat_completions_url"]
    local headers = Providers.get_provider().make_headers()

    run_started_hook()

    OpenAIApi.cancel_call()
    OpenAIApi.job = curl.post(url, {
        body = payload_str,
        headers = headers,
        stream = function(error, data, self)
            curl_stream_handler(error, data, cb, OpenAIApi.cancel_call)
        end,
        on_error = function(err)
            print('Error:', err.message)
            run_finished_hook()
        end,
    })
end

function OpenAIApi.cancel_call()
    if OpenAIApi.job ~= nil then
        OpenAIApi.job:shutdown()
    end
    OpenAIApi.job = nil
end

return OpenAIApi
