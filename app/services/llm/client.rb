# Common interface every adapter implements:
#   #call_tool(system:, tool:, max_tokens:, content_blocks: nil, messages: nil) -> Llm::CallResult
#
# Exactly one of content_blocks:/messages: is given. content_blocks is a
# neutral shape each adapter translates to a single implicit user turn:
# { kind: :text, text: "..." } / { kind: :image, media_type: "...", data: "<base64>" }.
# messages is a full multi-turn conversation: [{ role: "user"|"assistant", content: "..." }, ...],
# for callers that need history, not a single turn.
# tool is { name:, description:, input_schema: } — plain JSON schema, provider-agnostic.
#
# Llm::Client itself has the same #call_tool(...) signature, but returns just
# the tool-call Hash (string keys) — it unwraps Llm::CallResult#data after
# logging Llm::UsageRecord from #input_tokens/#output_tokens, so callers never
# deal with the adapter-level result type.
#
# Llm::Client tries the owner's Llm::Credential rows in rank order, falling
# back to the next on ANY error from the current one. If the call includes an
# image (content_blocks with a :image block), only vision-capable credentials
# are attempted — everything else has no such constraint.
#
# `owner` is whatever model included Llm::Owned (Account, Team, User, ...).
module Llm
  class Client
    class NoCredentialsError < StandardError; end
    class AllProvidersFailedError < StandardError; end

    def self.for(owner)
      new(owner)
    end

    def initialize(owner)
      @owner = owner
    end

    def call_tool(system:, tool:, max_tokens:, content_blocks: nil, messages: nil)
      needs_vision = content_blocks&.any? { |block| block[:kind] == :image } || false

      credentials = @owner.llm_credentials.ranked.to_a
      credentials = credentials.select { |c| Llm::ProviderRegistry.vision_capable?(c.provider, c.model) } if needs_vision
      raise NoCredentialsError, "No configured AI API credential can handle this request" if credentials.empty?

      last_error = nil
      credentials.each do |credential|
        result = adapter_for(credential).call_tool(system: system, tool: tool, max_tokens: max_tokens, content_blocks: content_blocks, messages: messages)
        record_usage(credential, result)
        return result.data
      rescue StandardError => e
        last_error = e
        Rails.logger.warn("Llm::Client: #{credential.provider}/#{credential.model} failed (#{e.class}: #{e.message}), trying next")
      end

      raise AllProvidersFailedError, "All #{credentials.size} configured AI API credential(s) failed. Last error: #{last_error.class}: #{last_error.message}"
    end

    private

    def adapter_for(credential)
      case credential.provider
      when "anthropic" then AnthropicAdapter.new(credential)
      else OpenAiCompatibleAdapter.new(credential)
      end
    end

    def record_usage(credential, result)
      @owner.llm_usage_records.create!(
        provider: credential.provider,
        model: credential.model,
        input_tokens: result.input_tokens,
        output_tokens: result.output_tokens,
        cost_usd: ProviderRegistry.cost_for(credential.provider, credential.model, input_tokens: result.input_tokens, output_tokens: result.output_tokens)
      )
    rescue StandardError => e
      # Never let usage logging break a successful call.
      Rails.logger.error("Llm::Client: failed to record usage for #{credential.provider}/#{credential.model}: #{e.message}")
    end
  end
end
