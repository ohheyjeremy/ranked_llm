module Llm
  # A ranked AI API credential. Llm::Client tries these in position order for
  # every LLM call, falling back to the next rank on any failure from the
  # current one.
  class Credential < ApplicationRecord
    belongs_to :owner, polymorphic: true

    encrypts :api_key

    positioned on: :owner

    validates :provider, :model, :api_key, presence: true
    validate :provider_and_model_are_known

    scope :ranked, -> { order(:position) }

    private

    def provider_and_model_are_known
      return if Llm::ProviderRegistry.valid?(provider, model)

      errors.add(:model, "#{model.inspect} is not a supported model for provider #{provider.inspect}")
    end
  end
end
