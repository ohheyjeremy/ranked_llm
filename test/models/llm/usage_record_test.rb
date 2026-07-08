require "test_helper"

class Llm::UsageRecordTest < ActiveSupport::TestCase
  setup do
    @workspace = Workspace.create!(name: "Acme")
  end

  test "requires provider and model" do
    record = @workspace.llm_usage_records.new(input_tokens: 10, output_tokens: 10)
    assert_not record.valid?
    assert_includes record.errors.attribute_names, :provider
    assert_includes record.errors.attribute_names, :model
  end

  test "this_month scopes to the current calendar month" do
    in_month = @workspace.llm_usage_records.create!(provider: "anthropic", model: "claude-sonnet-5", input_tokens: 1, output_tokens: 1, cost_usd: 0.001)
    @workspace.llm_usage_records.create!(provider: "anthropic", model: "claude-sonnet-5", input_tokens: 1, output_tokens: 1, cost_usd: 0.001, created_at: 2.months.ago)

    assert_includes Llm::UsageRecord.this_month, in_month
    assert_equal 1, Llm::UsageRecord.this_month.count
  end

  test "total_cost sums cost_usd across a scope" do
    @workspace.llm_usage_records.create!(provider: "deepseek", model: "deepseek-chat", input_tokens: 100, output_tokens: 100, cost_usd: 0.0107)
    @workspace.llm_usage_records.create!(provider: "deepseek", model: "deepseek-chat", input_tokens: 100, output_tokens: 100, cost_usd: 0.0002)

    assert_in_delta 0.0109, Llm::UsageRecord.total_cost(@workspace.llm_usage_records), 0.00001
  end

  test "usage history survives its credential being deleted" do
    credential = @workspace.llm_credentials.create!(provider: "anthropic", model: "claude-sonnet-5", api_key: "sk-a")
    record = @workspace.llm_usage_records.create!(provider: credential.provider, model: credential.model, input_tokens: 1, output_tokens: 1)

    credential.destroy!

    assert record.reload.persisted?
  end
end
