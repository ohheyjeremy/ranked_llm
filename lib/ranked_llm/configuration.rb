module RankedLlm
  # Host-app configuration. Everything here has a working default, so an app
  # that never calls RankedLlm.configure behaves exactly as it did before task
  # types existed: one ranked list per owner, serving everything.
  class Configuration
    # The catch-all list. Always present, can't be removed, and is what any
    # unranked task type falls back to.
    DEFAULT_TASK_TYPE = "default".freeze

    attr_reader :task_types

    def initialize
      @task_types = {}
    end

    # The kinds of work this app asks an AI for, as { key => human label }.
    # Declaring them lets an owner rank credentials per job, so a cheap fast
    # model can take one kind of call while something stronger takes another.
    #
    #   RankedLlm.configure do |config|
    #     config.task_types = {
    #       "chat" => "Chat replies",
    #       "summarise" => "Summarising"
    #     }
    #   end
    #
    # Keys are persisted on Llm::Credential#task_type, so renaming one later
    # is a data migration, not just a label change. The default list is always
    # included and does not need declaring.
    def task_types=(types)
      keys = types.keys.map(&:to_s)
      if keys.include?(DEFAULT_TASK_TYPE)
        raise ArgumentError, "#{DEFAULT_TASK_TYPE.inspect} is reserved for the catch-all list and is always present"
      end

      @task_types = types.transform_keys(&:to_s).freeze
    end
  end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Test/reload hook. Not meant for application code.
    def reset_configuration!
      @config = Configuration.new
    end
  end
end
