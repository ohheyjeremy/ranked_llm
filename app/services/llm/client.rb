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
#
# Which list gets tried depends on the caller's task_type (see Llm::TaskType),
# so an owner can rank one kind of work differently from another. A task type
# the owner hasn't ranked separately falls through to the DEFAULT list, so an
# app that declares no task types behaves exactly as it always did.
#
# Once the owner's own credentials are exhausted, anything returned by
# #shared_llm_credentials is tried as a last resort (see Llm::Owned).
#
# After a successful call_tool, #last_provider/#last_model report which
# credential actually served it, which is not necessarily rank 1 if earlier
# ones failed over. Callers that want to record provenance on whatever they
# build from the result read these off the same instance right afterwards.
module Llm
  class Client
    class NoCredentialsError < StandardError; end
    class AllProvidersFailedError < StandardError; end

    attr_reader :last_provider, :last_model

    def self.for(owner, task_type: TaskType::DEFAULT)
      new(owner, task_type: task_type)
    end

    def initialize(owner, task_type: TaskType::DEFAULT)
      @owner = owner
      @task_type = task_type.to_s
    end

    def call_tool(system:, tool:, max_tokens:, content_blocks: nil, messages: nil)
      needs_vision = content_blocks&.any? { |block| block[:kind] == :image } || false

      credentials = ranked_for_task_type
      # Borrowed keys are the last resort: the owner's own always come first.
      credentials.concat(@owner.shared_llm_credentials)
      credentials = credentials.select { |c| Llm::ProviderRegistry.vision_capable?(c.provider, c.model) } if needs_vision
      raise NoCredentialsError, "No configured AI API credential can handle this request" if credentials.empty?

      last_error = nil
      credentials.each do |credential|
        result = adapter_for(credential).call_tool(system: system, tool: tool, max_tokens: max_tokens, content_blocks: content_blocks, messages: messages)
        record_usage(credential, result)
        @last_provider = credential.provider
        @last_model = credential.model
        return result.data
      rescue StandardError => e
        last_error = e
        Rails.logger.warn("Llm::Client: #{credential.provider}/#{credential.model} failed (#{e.class}: #{e.message}), trying next")
      end

      raise AllProvidersFailedError, "All #{credentials.size} configured AI API credential(s) failed. Last error: #{last_error.class}: #{last_error.message}"
    end

    private

    # A task type only overrides the default list when the owner has actually
    # ranked something for it. Ranking nothing means "no opinion", which is
    # different from "no credentials for this".
    def ranked_for_task_type
      own = @owner.llm_credentials.for_task_type(@task_type).ranked.to_a
      return own if own.any?
      return [] if @task_type == TaskType::DEFAULT

      @owner.llm_credentials.for_task_type(TaskType::DEFAULT).ranked.to_a
    end

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
        cost_usd: ProviderRegistry.cost_for(credential.provider, credential.model, input_tokens: result.input_tokens, output_tokens: result.output_tokens),
        # Recorded against the borrowing owner, so a shared-pool cap can be
        # computed without joining back to whoever owns the key.
        shared: credential.shared?
      )
    rescue StandardError => e
      # Never let usage logging break a successful call.
      Rails.logger.error("Llm::Client: failed to record usage for #{credential.provider}/#{credential.model}: #{e.message}")
    end
  end
end
