require "test_helper"

class Llm::ClientTest < ActiveSupport::TestCase
  FakeAdapter = Struct.new(:behavior) do
    def call_tool(**)
      case behavior
      when :succeed then Llm::CallResult.new(data: { "ok" => true }, input_tokens: 100, output_tokens: 50)
      when :fail then raise "simulated provider failure"
      end
    end
  end

  def stub_adapter_for(client, behaviors_by_provider)
    client.define_singleton_method(:adapter_for) { |credential| behaviors_by_provider.fetch(credential.provider) }
  end

  setup do
    @workspace = Workspace.create!(name: "Acme")
  end

  test "uses the first ranked credential when it succeeds" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))

    result = client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, content_blocks: [ { kind: :text, text: "hi" } ])
    assert_equal({ "ok" => true }, result)
  end

  test "falls back to the next ranked credential when the first fails" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")
    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:fail), "deepseek" => FakeAdapter.new(:succeed))

    result = client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, content_blocks: [ { kind: :text, text: "hi" } ])
    assert_equal({ "ok" => true }, result)
  end

  test "raises AllProvidersFailedError when every ranked credential fails" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")
    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:fail), "deepseek" => FakeAdapter.new(:fail))

    assert_raises(Llm::Client::AllProvidersFailedError) do
      client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, content_blocks: [ { kind: :text, text: "hi" } ])
    end
  end

  test "raises NoCredentialsError when the owner has no configured credentials" do
    client = Llm::Client.for(@workspace)
    assert_raises(Llm::Client::NoCredentialsError) do
      client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, content_blocks: [ { kind: :text, text: "hi" } ])
    end
  end

  test "skips non-vision-capable credentials when the call includes an image" do
    @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    client = Llm::Client.for(@workspace)
    # deepseek isn't vision-capable, so it must never be asked — no :fail/:succeed stub
    # provided for it means the test would raise KeyError if the client tried it.
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))

    result = client.call_tool(
      system: "s", tool: { name: "t" }, max_tokens: 100,
      content_blocks: [ { kind: :text, text: "hi" }, { kind: :image, media_type: "image/png", data: "abc" } ]
    )
    assert_equal({ "ok" => true }, result)
  end

  test "does not filter by vision when messages: (no image content_blocks) is used" do
    @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")
    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "deepseek" => FakeAdapter.new(:succeed))

    result = client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, messages: [ { role: "user", content: "hi" } ])
    assert_equal({ "ok" => true }, result)
  end

  test "records usage and cost for a successful call, but not for a failed attempt that was skipped" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")
    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:fail), "deepseek" => FakeAdapter.new(:succeed))

    assert_difference "Llm::UsageRecord.count", 1 do
      client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, content_blocks: [ { kind: :text, text: "hi" } ])
    end

    record = @workspace.llm_usage_records.order(:id).last
    assert_equal "deepseek", record.provider
    assert_equal "deepseek-chat", record.model
    assert_equal 100, record.input_tokens
    assert_equal 50, record.output_tokens
    expected_cost = (100 * 0.27 + 50 * 1.10) / 1_000_000.0
    assert_in_delta expected_cost, record.cost_usd, 0.0000001
  end

  test "records a nil cost when the model has no known pricing" do
    @workspace.llm_credentials.create!(provider: "openrouter", model: "openrouter/auto", api_key: "sk-or")
    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "openrouter" => FakeAdapter.new(:succeed))

    client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, content_blocks: [ { kind: :text, text: "hi" } ])

    assert_nil @workspace.llm_usage_records.order(:id).last.cost_usd
  end
end
