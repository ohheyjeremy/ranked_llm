module Llm
  # A ranked AI API credential. Llm::Client tries these in position order for
  # every LLM call, falling back to the next rank on any failure from the
  # current one.
  class Credential < ApplicationRecord
    belongs_to :owner, polymorphic: true

    encrypts :api_key

    # Each task type ranks independently, so positions restart per list.
    positioned on: [ :owner, :task_type ]

    validates :provider, :model, :api_key, presence: true
    validates :task_type, inclusion: { in: ->(_) { Llm::TaskType.keys },
                                       message: "isn't a task type this app declared (see RankedLlm.configure)" }
    validate :provider_and_model_are_known

    scope :ranked, -> { order(:position) }
    scope :for_task_type, ->(task_type) { where(task_type: task_type) }

    # A credential the owner actually holds, never one borrowed from a shared
    # pool (see Llm::SharedCredential). Lets Llm::Client tag usage correctly.
    def shared? = false

    private

    def provider_and_model_are_known
      return if Llm::ProviderRegistry.valid?(provider, model)

      errors.add(:model, "#{model.inspect} is not a supported model for provider #{provider.inspect}")
    end
  end
end
