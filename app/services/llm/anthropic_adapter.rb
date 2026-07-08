module Llm
  class AnthropicAdapter
    def initialize(credential)
      @credential = credential
    end

    def call_tool(system:, tool:, max_tokens:, content_blocks: nil, messages: nil)
      wire_messages = messages || [ { role: "user", content: content_blocks.map { |block| to_wire_block(block) } } ]
      client = Anthropic::Client.new(api_key: @credential.api_key)
      response = client.messages.create(
        model: @credential.model,
        max_tokens: max_tokens,
        system: system,
        messages: wire_messages,
        tools: [ { name: tool[:name], description: tool[:description], input_schema: tool[:input_schema] } ],
        tool_choice: { type: "tool", name: tool[:name] }
      )
      tool_use = response.content.find { |block| block.type == :tool_use }
      raise "Llm::AnthropicAdapter: no #{tool[:name]} tool call in response" unless tool_use

      # The anthropic gem parses response JSON with symbolize_names: true, so
      # tool_use.input has symbol keys — stringify to match
      # Llm::OpenAiCompatibleAdapter#call_tool's return shape, which callers
      # rely on via string-key access.
      CallResult.new(
        data: tool_use.input.deep_stringify_keys,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens
      )
    end

    private

    def to_wire_block(block)
      case block[:kind]
      when :text then { type: "text", text: block[:text] }
      when :image then { type: "image", source: { type: "base64", media_type: block[:media_type], data: block[:data] } }
      end
    end
  end
end
