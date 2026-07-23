# Curated, hand-maintained list of supported providers and models.
# Deliberately not free-text: provider model catalogs (especially
# OpenRouter's) move fast, so this needs occasional manual updates in
# exchange for never risking a typo'd/unsupported model string.
#
# Each model carries a `vision:` flag. Callers that need to see an image
# (e.g. analyzing a screenshot) can restrict Llm::Client to vision-capable
# ranked credentials only — everything else has no such constraint and can
# use any ranked credential, vision or not.
#
# Each model also carries `input_price_per_million`/`output_price_per_million`
# (USD per 1M tokens, nil if genuinely variable e.g. openrouter/auto). These
# are seeded from public pricing pages at the time this was written and WILL
# drift — re-check against each provider's current pricing before trusting
# them for real budgeting decisions.
module Llm
  module ProviderRegistry
    PROVIDERS = {
      "anthropic" => {
        label: "Anthropic",
        base_uri: nil, # handled by the Anthropic gem directly, not the generic OpenAI-compatible adapter
        models: {
          "claude-sonnet-5" => { vision: true, input_price_per_million: 3.00, output_price_per_million: 15.00 },
          "claude-opus-4-8" => { vision: true, input_price_per_million: 15.00, output_price_per_million: 75.00 },
          "claude-haiku-4-5-20251001" => { vision: true, input_price_per_million: 1.00, output_price_per_million: 5.00 }
        }
      },
      "openai" => {
        label: "OpenAI",
        base_uri: "https://api.openai.com/v1",
        models: {
          "gpt-4o" => { vision: true, input_price_per_million: 2.50, output_price_per_million: 10.00 },
          "gpt-4o-mini" => { vision: true, input_price_per_million: 0.15, output_price_per_million: 0.60 },
          "gpt-4.1" => { vision: true, input_price_per_million: 2.00, output_price_per_million: 8.00 },
          "o3-mini" => { vision: false, input_price_per_million: 1.10, output_price_per_million: 4.40 }
        }
      },
      "deepseek" => {
        label: "DeepSeek",
        base_uri: "https://api.deepseek.com/v1",
        # No vision-capable model today — never eligible for vision-only
        # calls, but fine for text-only calls.
        models: {
          "deepseek-chat" => { vision: false, input_price_per_million: 0.27, output_price_per_million: 1.10 },
          "deepseek-reasoner" => { vision: false, input_price_per_million: 0.55, output_price_per_million: 2.19 }
        }
      },
      "mistral" => {
        label: "Mistral",
        base_uri: "https://api.mistral.ai/v1",
        models: {
          "pixtral-large-latest" => { vision: true, input_price_per_million: 2.00, output_price_per_million: 6.00 },
          "pixtral-12b-latest" => { vision: true, input_price_per_million: 0.15, output_price_per_million: 0.15 }
        }
      },
      "kimi" => {
        label: "Kimi (Moonshot AI)",
        base_uri: "https://api.moonshot.ai/v1",
        # Pricing here is the standard (cache-miss) input rate — this gem
        # doesn't model cache-hit discounts for any provider.
        models: {
          "kimi-k3" => { vision: true, input_price_per_million: 3.00, output_price_per_million: 15.00 },
          "kimi-k2.7-code" => { vision: false, input_price_per_million: 0.95, output_price_per_million: 4.00 },
          "kimi-k2.6" => { vision: true, input_price_per_million: 0.95, output_price_per_million: 4.00 }
        }
      },
      "openrouter" => {
        label: "OpenRouter",
        base_uri: "https://openrouter.ai/api/v1",
        models: {
          "anthropic/claude-3.5-sonnet" => { vision: true, input_price_per_million: 3.00, output_price_per_million: 15.00 },
          "google/gemini-2.0-flash-001" => { vision: true, input_price_per_million: 0.10, output_price_per_million: 0.40 },
          "openai/gpt-4o" => { vision: true, input_price_per_million: 2.50, output_price_per_million: 10.00 },
          # Lets OpenRouter's own router pick the best underlying model per
          # request instead of pinning one — convenient, but it's a
          # meta-router rather than a specific model, so treat it as
          # non-vision-guaranteed (which model it picks varies) and
          # unpriceable (cost depends on whatever it picks).
          "openrouter/auto" => { vision: false, input_price_per_million: nil, output_price_per_million: nil }
        }
      }
    }.freeze

    def self.valid?(provider, model)
      PROVIDERS.key?(provider) && PROVIDERS[provider][:models].key?(model)
    end

    def self.vision_capable?(provider, model)
      valid?(provider, model) && PROVIDERS[provider][:models][model][:vision]
    end

    def self.base_uri_for(provider)
      PROVIDERS.fetch(provider).fetch(:base_uri)
    end

    def self.pricing_for(provider, model)
      return nil unless valid?(provider, model)

      cfg = PROVIDERS[provider][:models][model]
      return nil if cfg[:input_price_per_million].nil? || cfg[:output_price_per_million].nil?

      { input_price_per_million: cfg[:input_price_per_million], output_price_per_million: cfg[:output_price_per_million] }
    end

    # Returns nil (rather than 0) when a model has no known/fixed pricing —
    # callers must not silently treat "unknown" as "free".
    def self.cost_for(provider, model, input_tokens:, output_tokens:)
      pricing = pricing_for(provider, model)
      return nil unless pricing

      (input_tokens * pricing[:input_price_per_million] + output_tokens * pricing[:output_price_per_million]) / 1_000_000.0
    end

    def self.grouped_options
      PROVIDERS.map { |key, cfg| [ cfg[:label], cfg[:models].keys.map { |m| [ m, "#{key}:#{m}" ] } ] }
    end
  end
end
