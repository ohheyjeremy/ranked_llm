require "test_helper"

class Llm::AnthropicAdapterTest < ActiveSupport::TestCase
  FakeToolUseBlock = Struct.new(:type, :input)
  FakeUsage = Struct.new(:input_tokens, :output_tokens)
  FakeResponse = Struct.new(:content, :usage)

  class FakeAnthropicClient
    def initialize(input, usage: Llm::AnthropicAdapterTest::FakeUsage.new(10, 20))
      @input = input
      @usage = usage
    end

    def messages = self

    def create(**captured_args)
      @captured_args = captured_args
      FakeResponse.new([ Llm::AnthropicAdapterTest::FakeToolUseBlock.new(:tool_use, @input) ], @usage)
    end

    attr_reader :captured_args
  end

  def stub_new(klass, replacement)
    original = klass.method(:new)
    klass.define_singleton_method(:new, &replacement)
    yield
  ensure
    klass.define_singleton_method(:new, original)
  end

  setup do
    @workspace = Workspace.create!(name: "Acme")
    @credential = @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-ant-test")
    @adapter = Llm::AnthropicAdapter.new(@credential)
  end

  test "sends text and image blocks in Anthropic's native shape and returns the tool call input" do
    fake_client = nil
    # The real anthropic gem parses response JSON with symbolize_names: true,
    # so tool_use.input arrives with symbol keys — simulate that here.
    stub_new(Anthropic::Client, ->(**) { fake_client = FakeAnthropicClient.new({ priority: "high" }) }) do
      result = @adapter.call_tool(
        system: "sys prompt",
        content_blocks: [ { kind: :text, text: "hello" }, { kind: :image, media_type: "image/png", data: "abc123" } ],
        tool: { name: "triage_task", description: "d", input_schema: { type: "object" } },
        max_tokens: 500
      )
      assert_equal({ "priority" => "high" }, result.data)
      assert_equal 10, result.input_tokens
      assert_equal 20, result.output_tokens
    end

    args = fake_client.captured_args
    assert_equal @credential.model, args[:model]
    assert_equal "sys prompt", args[:system]
    assert_equal 500, args[:max_tokens]
    content = args[:messages].first[:content]
    assert_equal({ type: "text", text: "hello" }, content[0])
    assert_equal({ type: "image", source: { type: "base64", media_type: "image/png", data: "abc123" } }, content[1])
    assert_equal [ { name: "triage_task", description: "d", input_schema: { type: "object" } } ], args[:tools]
    assert_equal({ type: "tool", name: "triage_task" }, args[:tool_choice])
  end

  test "sends a full multi-turn conversation as-is when messages: is given" do
    fake_client = nil
    stub_new(Anthropic::Client, ->(**) { fake_client = FakeAnthropicClient.new({ reply: "hi" }) }) do
      @adapter.call_tool(
        system: "sys prompt",
        messages: [ { role: "user", content: "hello" }, { role: "assistant", content: "hi there" } ],
        tool: { name: "chat_reply", description: "d", input_schema: { type: "object" } },
        max_tokens: 500
      )
    end

    assert_equal(
      [ { role: "user", content: "hello" }, { role: "assistant", content: "hi there" } ],
      fake_client.captured_args[:messages]
    )
  end

  class FakeEmptyAnthropicClient
    def messages = self

    def create(**) = FakeResponse.new([])
  end

  test "raises when the response has no tool_use block" do
    stub_new(Anthropic::Client, ->(**) { FakeEmptyAnthropicClient.new }) do
      assert_raises(RuntimeError) do
        @adapter.call_tool(system: "s", content_blocks: [], tool: { name: "t", description: "d", input_schema: {} }, max_tokens: 100)
      end
    end
  end
end
