require "test_helper"

class Llm::ProviderRegistryTest < ActiveSupport::TestCase
  test "valid? rejects unknown providers and models" do
    assert Llm::ProviderRegistry.valid?("anthropic", "claude-sonnet-5")
    assert_not Llm::ProviderRegistry.valid?("anthropic", "not-a-model")
    assert_not Llm::ProviderRegistry.valid?("not-a-provider", "claude-sonnet-5")
  end

  test "cost_for computes cost from per-million pricing" do
    cost = Llm::ProviderRegistry.cost_for("anthropic", "claude-sonnet-5", input_tokens: 1_000_000, output_tokens: 1_000_000)
    assert_in_delta 18.00, cost, 0.0001
  end

  test "cost_for returns nil for models with no fixed pricing" do
    assert_nil Llm::ProviderRegistry.cost_for("openrouter", "openrouter/auto", input_tokens: 100, output_tokens: 100)
  end

  test "vision_capable? is false for unknown provider/model" do
    assert_not Llm::ProviderRegistry.vision_capable?("nope", "nope")
  end
end
