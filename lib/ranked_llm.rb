require "positioning" # Llm::Credential uses `positioned` at class-definition time — must be loaded before app/models autoloads it.
require "httparty"
require "anthropic"
require "ranked_llm/version"
require "ranked_llm/configuration"
require "ranked_llm/engine"

module RankedLlm
end
