require "test_helper"

# Per-task-type ranking and the shared-pool fallback, both added in 0.3.0.
class Llm::ClientTaskTypeTest < ActiveSupport::TestCase
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

  def call(client)
    client.call_tool(system: "s", tool: { name: "t" }, max_tokens: 100, messages: [ { role: "user", content: "hi" } ])
  end

  setup do
    @workspace = Workspace.create!(name: "Acme")
  end

  test "a task type with its own ranking uses it instead of the default list" do
    with_task_types("chat" => "Chat replies") do
      @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
      @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d", task_type: "chat")

      client = Llm::Client.for(@workspace, task_type: "chat")
      stub_adapter_for(client, "deepseek" => FakeAdapter.new(:succeed))

      assert_equal({ "ok" => true }, call(client))
      assert_equal "deepseek", client.last_provider
    end
  end

  test "a task type nobody ranked falls back to the default list" do
    with_task_types("chat" => "Chat replies", "summarise" => "Summarising") do
      @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
      @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d", task_type: "chat")

      client = Llm::Client.for(@workspace, task_type: "summarise")
      stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))

      assert_equal({ "ok" => true }, call(client))
      assert_equal "anthropic", client.last_provider
    end
  end

  test "passing no task type behaves exactly as it did before task types existed" do
    with_task_types("chat" => "Chat replies") do
      @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
      @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d", task_type: "chat")

      client = Llm::Client.for(@workspace)
      stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))

      assert_equal({ "ok" => true }, call(client))
      assert_equal "anthropic", client.last_provider
    end
  end

  test "a task type's list falls back through its own ranks, not the default one" do
    with_task_types("chat" => "Chat replies") do
      @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
      @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d", task_type: "chat")
      @workspace.llm_credentials.create!(provider: "mistral", model: "pixtral-large-latest", api_key: "sk-m", task_type: "chat")

      client = Llm::Client.for(@workspace, task_type: "chat")
      stub_adapter_for(client, "deepseek" => FakeAdapter.new(:fail), "mistral" => FakeAdapter.new(:succeed))

      assert_equal({ "ok" => true }, call(client))
      assert_equal "mistral", client.last_provider
      assert_equal "pixtral-large-latest", client.last_model
    end
  end

  test "last_provider and last_model report the credential that actually served the call" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")

    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:fail), "deepseek" => FakeAdapter.new(:succeed))

    call(client)

    assert_equal "deepseek", client.last_provider
    assert_equal "deepseek-chat", client.last_model
  end

  test "last_provider is nil before any call" do
    assert_nil Llm::Client.for(@workspace).last_provider
  end

  # Shared pool

  def workspace_sharing(credentials)
    @workspace.define_singleton_method(:shared_llm_credentials) { credentials }
    @workspace
  end

  test "an owner with no credentials of its own falls back to the shared pool" do
    pool_holder = Workspace.create!(name: "Platform")
    pooled = pool_holder.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-pool")

    client = Llm::Client.for(workspace_sharing([ Llm::SharedCredential.new(pooled) ]))
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))

    assert_equal({ "ok" => true }, call(client))
  end

  test "the owner's own credentials are always tried before the shared pool" do
    pool_holder = Workspace.create!(name: "Platform")
    pooled = pool_holder.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-pool")
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-own")

    client = Llm::Client.for(workspace_sharing([ Llm::SharedCredential.new(pooled) ]))
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed), "deepseek" => FakeAdapter.new(:succeed))

    call(client)

    assert_equal "anthropic", client.last_provider
  end

  test "usage on a borrowed credential is recorded against the borrower, flagged shared" do
    pool_holder = Workspace.create!(name: "Platform")
    pooled = pool_holder.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-pool")

    client = Llm::Client.for(workspace_sharing([ Llm::SharedCredential.new(pooled) ]))
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))
    call(client)

    assert_equal 0, pool_holder.llm_usage_records.count
    record = @workspace.llm_usage_records.sole
    assert record.shared?
    assert_equal 1, @workspace.llm_usage_records.shared.count
    assert_equal 0, @workspace.llm_usage_records.own.count
  end

  test "usage on the owner's own credential is not flagged shared" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-own")

    client = Llm::Client.for(@workspace)
    stub_adapter_for(client, "anthropic" => FakeAdapter.new(:succeed))
    call(client)

    assert_not @workspace.llm_usage_records.sole.shared?
    assert_equal 1, @workspace.llm_usage_records.own.count
  end

  test "an owner that offers no pool is unaffected" do
    assert_equal [], @workspace.shared_llm_credentials

    assert_raises(Llm::Client::NoCredentialsError) { call(Llm::Client.for(@workspace)) }
  end
end
