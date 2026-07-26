require "rails/generators"
require "rails/generators/migration"

module RankedLlm
  module Generators
    # Migrates an app installed on ranked_llm 0.2.x or earlier up to the 0.3.0
    # schema: per-task-type credential lists, and a flag on usage records for
    # calls served by a borrowed shared credential.
    #
    # A fresh install doesn't need this — ranked_llm:install already creates
    # the 0.3.0 shape.
    class UpgradeGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration
        migration_template "upgrade_ranked_llm_to_0_3_0.rb.tt", "db/migrate/upgrade_ranked_llm_to_0_3_0.rb"
      end

      def show_post_upgrade_message
        say ""
        say "Created the ranked_llm 0.3.0 upgrade migration. Next steps:", :green
        say "  1. Run: bin/rails db:migrate"
        say "  2. Nothing else is required. Every existing credential lands on the \"default\" list,"
        say "     which is the one that already served everything, so behaviour is unchanged."
        say ""
        say "  To actually use per-task-type ranking, declare the kinds of work this app does:", :yellow
        say "    # config/initializers/ranked_llm.rb"
        say "    RankedLlm.configure do |config|"
        say "      config.task_types = { \"chat\" => \"Chat replies\", \"summarise\" => \"Summarising\" }"
        say "    end"
        say "  then pass one at the call site:"
        say "    Llm::Client.for(current_account, task_type: \"chat\").call_tool(...)"
        say ""
      end
    end
  end
end
