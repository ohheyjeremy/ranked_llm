module RankedLlm
  # Registers the gem's app/models and app/services directories the normal
  # Rails engine way. Deliberately not `isolate_namespace`d — call sites in
  # host apps address these classes as plain `Llm::...`, not
  # `RankedLlm::Llm::...`.
  class Engine < ::Rails::Engine
  end
end
