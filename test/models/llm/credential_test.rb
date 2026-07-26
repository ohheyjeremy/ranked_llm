require "test_helper"

class Llm::CredentialTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Acme")
  end

  test "encrypts and decrypts the api_key" do
    credential = @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-ant-test")
    assert_equal "sk-ant-test", credential.reload.api_key
    assert_not_includes Llm::Credential.connection.select_value(
      "SELECT api_key FROM llm_credentials WHERE id = #{credential.id}"
    ), "sk-ant-test"
  end

  test "ranked scope orders by position" do
    primary = @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    backup = @workspace.llm_credentials.create!(provider: "openrouter", model: "openrouter/auto", api_key: "sk-b")
    assert_equal [ primary, backup ], @workspace.llm_credentials.ranked.to_a
  end

  test "requires provider, model, and api_key" do
    credential = @workspace.llm_credentials.new
    assert_not credential.valid?
    assert_includes credential.errors.attribute_names, :provider
    assert_includes credential.errors.attribute_names, :model
    assert_includes credential.errors.attribute_names, :api_key
  end

  test "rejects an unknown provider/model combination" do
    credential = @workspace.llm_credentials.new(provider: "anthropic", model: "not-a-real-model", api_key: "sk-test")
    assert_not credential.valid?
    assert_includes credential.errors.attribute_names, :model
  end

  test "accepts every provider/model combination in the registry" do
    Llm::ProviderRegistry::PROVIDERS.each do |provider, cfg|
      cfg[:models].each_key do |model|
        credential = @workspace.llm_credentials.new(provider: provider, model: model, api_key: "sk-test")
        assert credential.valid?, "#{provider}:#{model} should be valid but got #{credential.errors.full_messages}"
      end
    end
  end

  test "new credentials for an owner are auto-positioned after existing ones" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    second = @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-b")
    assert_equal 2, second.position
  end

  test "position is scoped per owner, not globally" do
    @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")

    other_workspace = Workspace.create!(name: "Globex")
    credential = other_workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-b")

    assert_equal 1, credential.position
  end

  # Per-task-type lists (0.3.0)

  test "credentials land on the default list unless told otherwise" do
    credential = @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")

    assert_equal "default", credential.task_type
    assert_not credential.shared?
  end

  test "positions restart per task type, so each list ranks from 1" do
    with_task_types("chat" => "Chat replies") do
      first_default = @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
      second_default = @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d")
      first_chat = @workspace.llm_credentials.create!(provider: "mistral", model: "pixtral-large-latest", api_key: "sk-m", task_type: "chat")

      assert_equal 1, first_default.position
      assert_equal 2, second_default.position
      assert_equal 1, first_chat.position
    end
  end

  test "for_task_type returns only that list" do
    with_task_types("chat" => "Chat replies") do
      @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
      chat = @workspace.llm_credentials.create!(provider: "deepseek", model: "deepseek-chat", api_key: "sk-d", task_type: "chat")

      assert_equal [ chat ], @workspace.llm_credentials.for_task_type("chat").to_a
      assert_equal 1, @workspace.llm_credentials.for_task_type("default").count
    end
  end

  test "a task type the app never declared is rejected" do
    credential = @workspace.llm_credentials.build(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a", task_type: "undeclared")

    assert_not credential.valid?
    assert_match "isn't a task type this app declared", credential.errors[:task_type].to_sentence
  end
end
