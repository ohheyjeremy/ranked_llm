module Llm
  # The kinds of work a host app asks an AI for, declared via
  # RankedLlm.configure. Each one can carry its own ranked credential list, so
  # a cheap fast model can serve one kind of call while something stronger
  # serves another.
  #
  # An app that declares nothing has only DEFAULT, which is the behaviour
  # before task types existed: one ranked list per owner, serving everything.
  module TaskType
    DEFAULT = RankedLlm::Configuration::DEFAULT_TASK_TYPE

    # Read through to the config on every call rather than memoising, so an
    # initializer that runs after this file is autoloaded is still picked up.
    def self.all
      { DEFAULT => "Everything else" }.merge(RankedLlm.config.task_types)
    end

    def self.keys = all.keys

    def self.valid?(key) = all.key?(key.to_s)

    def self.label(key) = all[key.to_s] || key.to_s

    # Everything the host declared, without the catch-all. Handy for building
    # a settings UI that treats the default list separately.
    def self.declared = all.except(DEFAULT)
  end
end
