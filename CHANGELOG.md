# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-07-24

### Added

- Kimi (Moonshot AI) as a provider: `kimi-k3` (1M context, vision), `kimi-k2.7-code`
  (262k context, coding-focused, no vision), `kimi-k2.6` (262k context, vision).
  Model IDs, context windows, vision support, and pricing verified against the
  official docs at platform.kimi.ai. Uses the existing `Llm::OpenAiCompatibleAdapter`
  — no adapter changes needed, since Moonshot's API supports forced `tool_choice`
  on a standard chat/completions endpoint.

## [0.1.0] - 2026-07-23

### Added

- Initial extraction from Progentick: ranked, multi-provider AI API credentials
  with automatic fallback and per-call cost tracking for Rails apps.
- `Llm::Owned` concern — include in any tenant/owner model (Account, Team, User, ...).
- `Llm::Client.for(owner).call_tool(...)` — tries ranked credentials in order,
  falling back to the next on any failure; only vision-capable credentials are
  attempted when the call includes an image.
- `Llm::AnthropicAdapter` and `Llm::OpenAiCompatibleAdapter` (shared by OpenAI,
  DeepSeek, Mistral, OpenRouter, and any other OpenAI-compatible provider).
- `Llm::ProviderRegistry` — hand-maintained model catalog with per-model pricing
  and vision flags.
- `Llm::Credential` (encrypted `api_key`, positioned per-owner) and
  `Llm::UsageRecord` (token counts + cost per call).
- Rails generators: `ranked_llm:install` (migrations) and `ranked_llm:views`
  (scaffolded settings UI — controller, view, drag-to-reorder Stimulus controller).
