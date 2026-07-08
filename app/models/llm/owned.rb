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
  end
end
