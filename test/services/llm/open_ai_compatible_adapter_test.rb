require "test_helper"

class Llm::OpenAiCompatibleAdapterTest < ActiveSupport::TestCase
  FakeHttpResponse = Struct.new(:code, :success?, :parsed_response, :body)

  def stub_post(response)
    original = HTTParty.method(:post)
    captured = nil
    HTTParty.define_singleton_method(:post) do |url, options|
      captured = [ url, options ]
      response
    end
    yield
    captured
  ensure
    HTTParty.define_singleton_method(:post, original)
  end

  setup do
    @credential = Llm::Credential.new(provider: "mistral", model: "pixtral-large-latest", api_key: "sk-mistral-test")
    @adapter = Llm::OpenAiCompatibleAdapter.new(@credential)
  end

  test "posts to the provider's chat/completions endpoint with a bearer token and parses the tool call arguments" do
    fake_response = FakeHttpResponse.new(200, true, {
      "choices" => [ { "message" => { "tool_calls" => [ { "function" => { "arguments" => { "priority" => "high" }.to_json } } ] } } ],
      "usage" => { "prompt_tokens" => 15, "completion_tokens" => 25 }
    }, nil)

    result = nil
    url, options = stub_post(fake_response) do
      result = @adapter.call_tool(
        system: "sys", content_blocks: [ { kind: :text, text: "hi" } ],
        tool: { name: "triage_task", description: "d", input_schema: { type: "object" } }, max_tokens: 500
      )
    end

    assert_equal({ "priority" => "high" }, result.data)
    assert_equal 15, result.input_tokens
    assert_equal 25, result.output_tokens
    assert_equal "https://api.mistral.ai/v1/chat/completions", url
    assert_equal "Bearer sk-mistral-test", options[:headers]["Authorization"]

    body = JSON.parse(options[:body])
    assert_equal "pixtral-large-latest", body["model"]
    assert_equal "sys", body["messages"].first["content"]
    assert_equal "function", body["tools"].first["type"]
    assert_equal "triage_task", body["tools"].first["function"]["name"]
    assert_equal "triage_task", body.dig("tool_choice", "function", "name")
  end

  test "translates an image content block to an image_url data URI" do
    fake_response = FakeHttpResponse.new(200, true, {
      "choices" => [ { "message" => { "tool_calls" => [ { "function" => { "arguments" => "{}" } } ] } } ]
    }, nil)

    _url, options = stub_post(fake_response) do
      @adapter.call_tool(
        system: "sys",
        content_blocks: [ { kind: :text, text: "hi" }, { kind: :image, media_type: "image/png", data: "abc123" } ],
        tool: { name: "t", description: "d", input_schema: {} }, max_tokens: 100
      )
    end

    body = JSON.parse(options[:body])
    image_block = body["messages"].last["content"].find { |b| b["type"] == "image_url" }
    assert_equal "data:image/png;base64,abc123", image_block["image_url"]["url"]
  end

  test "sends a full multi-turn conversation as-is when messages: is given" do
    fake_response = FakeHttpResponse.new(200, true, {
      "choices" => [ { "message" => { "tool_calls" => [ { "function" => { "arguments" => "{}" } } ] } } ]
    }, nil)

    _url, options = stub_post(fake_response) do
      @adapter.call_tool(
        system: "sys",
        messages: [ { role: "user", content: "hello" }, { role: "assistant", content: "hi there" } ],
        tool: { name: "chat_reply", description: "d", input_schema: {} }, max_tokens: 100
      )
    end

    body = JSON.parse(options[:body])
    assert_equal(
      [ { "role" => "system", "content" => "sys" }, { "role" => "user", "content" => "hello" }, { "role" => "assistant", "content" => "hi there" } ],
      body["messages"]
    )
  end

  test "raises when the API responds with an error status" do
    fake_response = FakeHttpResponse.new(401, false, {}, "unauthorized")
    stub_post(fake_response) do
      assert_raises(RuntimeError) do
        @adapter.call_tool(system: "sys", content_blocks: [], tool: { name: "t", description: "d", input_schema: {} }, max_tokens: 100)
      end
    end
  end

  test "raises when the response has no tool call" do
    fake_response = FakeHttpResponse.new(200, true, { "choices" => [ { "message" => {} } ] }, nil)
    stub_post(fake_response) do
      assert_raises(RuntimeError) do
        @adapter.call_tool(system: "sys", content_blocks: [], tool: { name: "t", description: "d", input_schema: {} }, max_tokens: 100)
      end
    end
  end
end
