require "combustion"

Combustion.path = "test/internal"
Combustion.initialize! :active_record do
  # Test-only fixed keys — never use these for anything real. Required
  # because Llm::Credential#api_key uses Active Record Encryption. `self`
  # here is the Combustion::Application class itself (Combustion class_evals
  # this block), so `config` below resolves to its class-level config, same
  # as inside a `class MyApp < Rails::Application` body.
  config.active_record.encryption.primary_key = "a" * 32
  config.active_record.encryption.deterministic_key = "b" * 32
  config.active_record.encryption.key_derivation_salt = "c" * 32
end

require "rails/test_help"
require "minitest/autorun"

class ActiveSupport::TestCase
end
