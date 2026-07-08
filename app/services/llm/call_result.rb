module Llm
  # What an adapter's #call_tool returns internally: the tool-call data a
  # caller wants, plus token counts so Llm::Client can log spend before
  # unwrapping to just `data` for the caller (existing callers are unaffected
  # by this — they never see token counts).
  CallResult = Struct.new(:data, :input_tokens, :output_tokens, keyword_init: true)
end
