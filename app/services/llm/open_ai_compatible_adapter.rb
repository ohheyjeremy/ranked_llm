# Shared by any provider that speaks the OpenAI-style chat-completions shape
# (function-calling via tools/tool_choice) — Mistral, OpenRouter, DeepSeek,
# OpenAI itself, etc.
module Llm
  class OpenAiCompatibleAdapter
    def initialize(credential)
      @credential = credential
      @base_uri = ProviderRegistry.base_uri_for(credential.provider)
    end

    def call_tool(system:, tool:, max_tokens:, content_blocks: nil, messages: nil)
      wire_messages = messages || [ { role: "user", content: content_blocks.map { |block| to_wire_block(block) } } ]
      response = HTTParty.post(
        "#{@base_uri}/chat/completions",
        headers: { "Authorization" => "Bearer #{@credential.api_key}", "Content-Type" => "application/json" },
        body: {
          model: @credential.model,
          max_tokens: max_tokens,
          messages: [ { role: "system", content: system } ] + wire_messages,
          tools: [ { type: "function", function: { name: tool[:name], description: tool[:description], parameters: tool[:input_schema] } } ],
          tool_choice: { type: "function", function: { name: tool[:name] } }
        }.to_json
      )
      raise "Llm::OpenAiCompatibleAdapter: API error #{response.code} — #{response.body}" unless response.success?

      arguments = response.parsed_response.dig("choices", 0, "message", "tool_calls", 0, "function", "arguments")
      raise "Llm::OpenAiCompatibleAdapter: no #{tool[:name]} tool call in response" unless arguments

      CallResult.new(
        data: JSON.parse(arguments),
        input_tokens: response.parsed_response.dig("usage", "prompt_tokens") || 0,
        output_tokens: response.parsed_response.dig("usage", "completion_tokens") || 0
      )
    end

    private

    def to_wire_block(block)
      case block[:kind]
      when :text then { type: "text", text: block[:text] }
      when :image then { type: "image_url", image_url: { url: "data:#{block[:media_type]};base64,#{block[:data]}" } }
      end
    end
  end
end
