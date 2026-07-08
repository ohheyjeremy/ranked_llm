require "rails/generators"

module RankedLlm
  module Generators
    # Scaffolds a starting-point settings controller/view/JS for managing
    # ranked credentials. Deliberately not auto-mounted: every host app has
    # its own auth boundary (current_account/current_team/...) and UI
    # conventions, so this is meant to be copied and adapted, not used as-is.
    class ViewsGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_controller
        template "ai_apis_controller.rb.tt", "app/controllers/settings/ai_apis_controller.rb"
      end

      def copy_view
        template "index.html.erb.tt", "app/views/settings/ai_apis/index.html.erb"
      end

      def copy_stimulus_controller
        copy_file "ranked_list_controller.js", "app/javascript/controllers/ranked_list_controller.js"
      end

      def show_post_install_message
        say ""
        say "Copied a starting-point settings controller/view/JS for ranked_llm.", :green
        say "Adjust the following before using it:", :yellow
        say "  - `current_account` in app/controllers/settings/ai_apis_controller.rb — rename to whatever"
        say "    your app's auth boundary actually calls the owner (current_team, current_user, ...)."
        say "  - Restyle app/views/settings/ai_apis/index.html.erb to match this app's existing UI conventions —"
        say "    these Tailwind classes are just a starting point."
        say "  - Add a route, e.g.:"
        say "      namespace :settings do"
        say "        resources :ai_apis, only: [ :index, :create, :destroy ] do"
        say "          patch :move, on: :member"
        say "        end"
        say "      end"
        say "  - Register the Stimulus controller if this app doesn't auto-register app/javascript/controllers"
        say "    (importmap-rails/Stimulus's default setup already does this)."
        say "  - This view drags with SortableJS via the `ranked-list` Stimulus controller — make sure"
        say "    the `sortablejs` package (or your import-mapped equivalent) is available."
        say ""
      end
    end
  end
end
