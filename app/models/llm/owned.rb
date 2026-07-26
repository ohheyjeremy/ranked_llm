module Llm
  # Include in whatever model is the tenant/owner concept in the host app
  # (Account, Team, Organization, User, ...). Credentials and usage records
  # belong to that model polymorphically, so this gem never has to assume
  # what the owner is called.
  #
  #   class Account < ApplicationRecord
  #     include Llm::Owned
  #   end
  #
  #   Llm::Client.for(current_account).call_tool(...)
  module Owned
    extend ActiveSupport::Concern

    included do
      has_many :llm_credentials, as: :owner, class_name: "Llm::Credential", dependent: :destroy
      has_many :llm_usage_records, as: :owner, class_name: "Llm::UsageRecord", dependent: :destroy
    end

    # Last-resort credentials borrowed from somewhere else, tried only once
    # this owner's own ranked list is exhausted. Empty by default: an app that
    # doesn't offer a shared pool needs to do nothing.
    #
    # Override to return Llm::SharedCredential-wrapped credentials, and put
    # whatever gating the app needs (opt-in, plan, a monthly cap) in here:
    #
    #   def shared_llm_credentials
    #     return [] unless use_shared_keys? && under_monthly_cap?
    #
    #     Account.shared_key_holder.llm_credentials.ranked.map { |c| Llm::SharedCredential.new(c) }
    #   end
    #
    # Usage from these is recorded against *this* owner with shared: true, so
    # a cap can be computed straight off llm_usage_records.
    def shared_llm_credentials
      []
    end
  end
end
