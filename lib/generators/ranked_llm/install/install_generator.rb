require "rails/generators"
require "rails/generators/migration"

module RankedLlm
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migrations
        migration_template "create_llm_credentials.rb.tt", "db/migrate/create_llm_credentials.rb"
        sleep 1 if migrations_need_distinct_timestamps?
        migration_template "create_llm_usage_records.rb.tt", "db/migrate/create_llm_usage_records.rb"
      end

      def show_post_install_message
        say ""
        say "ranked_llm installed. Next steps:", :green
        say "  1. Run: bin/rails db:migrate"
        say "  2. Add `include Llm::Owned` to whatever model is your tenant/owner concept (Account, Team, User, ...)."
        say "  3. Configure Active Record Encryption if this app doesn't already (bin/rails db:encryption:init) —"
        say "     Llm::Credential#api_key is encrypted at rest using it."
        say "  4. Call it: Llm::Client.for(current_account).call_tool(system:, tool:, max_tokens:, messages:)"
        say ""
        say "  Optional settings UI scaffold: bin/rails generate ranked_llm:views"
        say ""
      end

      private

      def migrations_need_distinct_timestamps?
        true
      end
    end
  end
end
