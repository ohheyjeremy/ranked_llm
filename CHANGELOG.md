# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0] - 2026-07-26

Brings the gem up to what Progentick's own copy had grown into, generalised so
none of it assumes a particular host app. **Existing installs need a migration**
(`bin/rails generate ranked_llm:upgrade`), but no code changes: every existing
credential lands on the `default` list, which is the one that already served
everything.

### Added

- **Per-task-type ranking.** An owner can rank credentials differently for
  different kinds of work, so a cheap fast model can take one job while
  something stronger takes another. Declare the jobs the app actually does:

  ```ruby
  RankedLlm.configure do |config|
    config.task_types = { "chat" => "Chat replies", "summarise" => "Summarising" }
  end
  ```

  then `Llm::Client.for(owner, task_type: "chat")`. A task type with no ranking
  of its own falls through to the `default` list, so an app that declares
  nothing behaves exactly as before. Adds `Llm::TaskType`,
  `RankedLlm.configure`, `Llm::Credential#task_type` and
  `Llm::Credential.for_task_type`.
- **Shared credential pools.** `Llm::Owned#shared_llm_credentials` (empty by
  default) lets an owner fall back to keys borrowed from elsewhere once its own
  are exhausted: a platform's own keys for accounts that haven't brought one, a
  parent organisation's keys, a plan allowance. Wrap them in
  `Llm::SharedCredential`. Usage is recorded against the *borrowing* owner with
  `shared: true`, so a cap or a bill can be computed straight off
  `llm_usage_records` (`.shared` / `.own` scopes) without joining back to the
  key's owner. The gem takes no view on where a pool comes from or who may use
  it — gating goes in the override.
- **`Llm::Client#last_provider` / `#last_model`**, reporting which credential
  actually served the last call, which is not necessarily rank 1 when earlier
  ones failed over. For recording provenance on whatever gets built from the
  result.
- `ranked_llm:upgrade` generator, producing the 0.2.x → 0.3.0 migration.

### Changed

- `Llm::Credential` positions are now scoped per (owner, task type), so each
  list ranks from 1 independently. The unique index moves accordingly.
- The `ranked_llm:views` scaffold gained a "Ranking for" picker, shown only
  once the app declares task types.

### Notes

- `task_type` is `"default"`, not `NULL`, for the catch-all list. Postgres
  treats NULLs as distinct in a unique index, so a nullable column would let
  two rows share a position and silently break the ranking.

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
