local OpenAIProvider = require("codegpt.providers.openai")

Providers = {}

function Providers.get_provider()
	return OpenAIProvider
end

return Providers
