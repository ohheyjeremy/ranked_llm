require "test_helper"

class Llm::TaskTypeTest < ActiveSupport::TestCase
  test "an app that declares nothing has only the catch-all" do
    assert_equal [ "default" ], Llm::TaskType.keys
    assert Llm::TaskType.valid?("default")
    assert_not Llm::TaskType.valid?("chat")
  end

  test "declared task types are added to the catch-all, which stays first" do
    with_task_types("chat" => "Chat replies", "summarise" => "Summarising") do
      assert_equal %w[default chat summarise], Llm::TaskType.keys
      assert Llm::TaskType.valid?("chat")
      assert_equal "Chat replies", Llm::TaskType.label("chat")
      assert_equal({ "chat" => "Chat replies", "summarise" => "Summarising" }, Llm::TaskType.declared)
    end
  end

  test "symbol keys are accepted and normalised to strings" do
    with_task_types(chat: "Chat replies") do
      assert Llm::TaskType.valid?("chat")
      assert Llm::TaskType.valid?(:chat)
      assert_equal "Chat replies", Llm::TaskType.label(:chat)
    end
  end

  test "declaring the reserved default key is refused" do
    error = assert_raises(ArgumentError) do
      RankedLlm.configure { |config| config.task_types = { "default" => "Mine" } }
    end
    assert_match "reserved", error.message
  ensure
    RankedLlm.reset_configuration!
  end

  test "an unknown key labels as itself rather than blowing up" do
    assert_equal "nonsense", Llm::TaskType.label("nonsense")
  end

  test "configuration declared after this file was autoloaded is still picked up" do
    assert_not Llm::TaskType.valid?("late")
    with_task_types("late" => "Declared later") do
      assert Llm::TaskType.valid?("late")
    end
    assert_not Llm::TaskType.valid?("late")
  end
end
