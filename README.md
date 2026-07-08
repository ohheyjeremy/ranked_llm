# RankedLlm

A ranked list of AI API credentials — spanning any mix of OpenAI, Anthropic, DeepSeek, Mistral, OpenRouter, etc. —
tried in order, falling back to the next on **any** failure from the current one. Tracks per-model pricing and logs
real spend per call, so cost is visible instead of assumed.

Extracted from [Progentick](https://github.com/ohheyjeremy/progentick).

## What it replaces

An app whose AI-calling features are pinned to one hardcoded provider/model/key. If that credential is down,
rate-limited, or misconfigured, every feature that depends on it just breaks.

## Install

Add to your Gemfile:

```ruby
gem "ranked_llm", github: "ohheyjeremy/ranked_llm"
```

Then:

```bash
bundle install
bin/rails generate ranked_llm:install
bin/rails db:migrate
```

This creates `llm_credentials` and `llm_usage_records` tables, scoped **polymorphically** to whatever your app's
tenant/owner concept is — the gem never assumes it's called `Account`.

Wire up your owner model:

```ruby
class Account < ApplicationRecord # or Team, Organization, User, ...
  include Llm::Owned
end
```

If this app doesn't already use Active Record Encryption (`Llm::Credential#api_key` is encrypted at rest with it):

```bash
bin/rails db:encryption:init
```

## Usage

```ruby
result = Llm::Client.for(current_account).call_tool(
  system: "You triage bug reports.",
  tool: { name: "triage", description: "...", input_schema: { type: "object", properties: { ... } } },
  max_tokens: 500,
  messages: [ { role: "user", content: "..." } ]
)
# => { "priority" => "high", ... } — a plain Hash with string keys, the parsed tool-call arguments.
```

- `messages:` for a full multi-turn conversation, or `content_blocks:` (`{ kind: :text, text: "..." }` /
  `{ kind: :image, media_type: "...", data: "<base64>" }`) for a single implicit user turn — pass exactly one.
- If any `content_blocks` entry is `kind: :image`, only vision-capable ranked credentials are attempted.
- On failure, the client automatically retries the next-ranked credential. Raises
  `Llm::Client::AllProvidersFailedError` if every configured credential fails, or
  `Llm::Client::NoCredentialsError` if none are configured (or none are vision-capable when an image is present).
- Every **successful** call logs an `Llm::UsageRecord` (provider, model, token counts, cost at the time of the
  call) — failed attempts that got skipped in the fallback chain are never logged.

## Settings UI

There's no mounted engine UI — every host app has its own auth boundary and design system. Instead, scaffold a
starting point and adapt it:

```bash
bin/rails generate ranked_llm:views
```

This copies a controller, view, and Stimulus drag-to-reorder controller into your app. Read the generator's output
for what to rename (`current_account` → your app's actual auth helper) and restyle.

## Pricing data

`Llm::ProviderRegistry::PROVIDERS` hand-seeds `input_price_per_million`/`output_price_per_million` (USD per 1M
tokens) per model, current as of when this gem was last updated. **This drifts.** Verify against each provider's
current pricing page before trusting it for real budgeting decisions. Models with genuinely variable pricing (e.g.
`openrouter/auto`, a meta-router) have `nil` pricing — `Llm::ProviderRegistry.cost_for` returns `nil` rather than
`0` for these, so a usage record's `cost_usd` can be `nil` and callers must not treat that as "free."

Adding a new provider/model: edit `PROVIDERS` in `app/services/llm/provider_registry.rb`. Model names are
deliberately not free-text on `Llm::Credential` — they're validated against this registry, since provider catalogs
(especially OpenRouter's) move fast and typos are easy.

## Adding a new provider

- If it speaks the OpenAI-style chat-completions shape (function-calling via `tools`/`tool_choice`), just add it to
  `PROVIDERS` with its `base_uri` — `Llm::OpenAiCompatibleAdapter` handles it.
- Otherwise (like Anthropic), add a case to `Llm::Client#adapter_for` and a new adapter implementing
  `#call_tool(system:, tool:, max_tokens:, content_blocks: nil, messages: nil) -> Llm::CallResult`.

## Testing

```bash
bundle install
bundle exec rake test
```

Uses [combustion](https://github.com/pat/combustion) to run the model/service specs against an in-memory dummy
Rails app (`test/internal`) — no full generated dummy app checked in.

## License

MIT.
