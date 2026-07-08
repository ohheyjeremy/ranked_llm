module Llm
  # One row per successful Llm::Client call: which provider/model actually
  # served it, how many tokens it used, and what that cost at the time (using
  # Llm::ProviderRegistry's pricing at the moment of the call, not whatever
  # the registry says later — prices drift, history shouldn't).
  #
  # Deliberately keyed by provider/model strings, not a credential_id — a
  # credential can be reranked or removed, but its usage history shouldn't
  # disappear with it.
  class UsageRecord < ApplicationRecord
    belongs_to :owner, polymorphic: true

    validates :provider, :model, presence: true
    validates :input_tokens, :output_tokens, numericality: { greater_than_or_equal_to: 0 }

    scope :this_month, -> { where(created_at: Time.current.all_month) }

    def self.total_cost(scope = all)
      scope.sum(:cost_usd)
    end
  end
end
