require_relative "lib/ranked_llm/version"

Gem::Specification.new do |spec|
  spec.name        = "ranked_llm"
  spec.version     = RankedLlm::VERSION
  spec.authors     = [ "Jeremy" ]
  spec.summary     = "Ranked, multi-provider AI API credentials with automatic fallback and cost tracking for Rails apps."
  spec.description = "A ranked list of AI API credentials (OpenAI, Anthropic, DeepSeek, Mistral, OpenRouter, ...) " \
                      "tried in order, falling back to the next on any failure, with per-model pricing and " \
                      "per-call spend logging. Extracted from Progentick."
  spec.homepage    = "https://github.com/ohheyjeremy/ranked_llm"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,lib}/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "positioning", "~> 0.4"
  spec.add_dependency "httparty"
  spec.add_dependency "anthropic"

  spec.add_development_dependency "combustion", "~> 1.5"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "minitest"
end
