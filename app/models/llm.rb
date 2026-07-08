# Multi-provider LLM abstraction: a ranked list of API credentials tried in
# order, falling back to the next on any failure, shared by every feature in
# the host app that calls an LLM.
module Llm
  def self.table_name_prefix = "llm_"
end
