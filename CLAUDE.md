# CLAUDE.md

These are the working conventions for **days-since**. Read [`README.md`](README.md) first for product vision and architecture. This file covers *how* we build.

## Ground rules

- **Ask before major architectural decisions.** Don't make assumptions about schema, associations, counter semantics, provider behavior, polling or theme structure. Settled decisions are recorded in `README.md` → *Architecture overview*. If you change one, update the README in the same commit.
- **Everything is scoped to a user.** Load data through `Current.user` / `current_user`, for example `current_user.subscriptions.find(params[:id])`. Never use unscoped `Subscription.find`. This must hold in both `SINGLE_USER_MODE` and multi-user mode.
- **Never special-case `SINGLE_USER_MODE` outside auth.** The only code that knows about it resolves `current_user`, redirects the login routes, and logs the production boot warning. Everything else treats the local user as a normal `User`.
- **`Feed` is shared and `Subscription` is personal.** Per-user preferences such as display name, severity override and position live on `Subscription` or `User`, never on `Feed` or `Incident`.

## Commands

```sh
bin/dev                  # run the app (Puma + Solid Queue + Tailwind watcher)
bundle exec rspec        # run all specs
bundle exec rspec path/to/file_spec.rb:42
bin/rubocop -a           # lint and autocorrect (rubocop-rails-omakase)
bin/brakeman             # security scan
```

Ruby is pinned in `.ruby-version` and managed with mise.

## Git workflow

- **Only commit or push when asked.** Don't commit or push on your own initiative. Leave changes in the working tree for review unless the user asks for a commit or push in the current session. When you do commit, follow the rules below.
- **Atomic commits.** Each commit is one focused step, such as "Add Feed model" or "Add Statuspage provider". Don't mix unrelated changes, like setup with features or refactors with behavior changes.
- **Message style:** a plain imperative subject line of 72 characters or fewer, with no Conventional Commits prefix. Example: `Add exponential backoff to feed polling`. Add a body when the *why* isn't obvious.
- **Trailer:** end every commit message with `Co-Authored-By: Claude <model> <noreply@anthropic.com>`.
- **Branching:** the MVP is complete, so per decision 9b new work goes on feature branches. Check with the user before committing directly to `main`.
- **Remote:** `origin` is `git@github.com:erikbelusic/days-since.git`.
- Before committing, run `bundle exec rspec` and `bin/rubocop`, and both must pass. Never commit a red suite.
- `.lavish/` holds local review artifacts. It is gitignored, so never commit it.

## Ruby & Rails conventions

- Follow **rubocop-rails-omakase** and don't fight the Rails defaults.
- **Fat models, thin controllers.** Domain logic goes in models and plain Ruby objects (POROs) under `app/models`. Use namespaces such as `FeedProviders::Statuspage`, `FeedProviders::Rss`, `FeedProviders::Detector` and `FeedUrl` (normalization). Don't create an `app/services` directory.
- **Use concerns sparingly**, only for behavior shared by more than one model.
- **Jobs stay thin.** A job loads a record and calls a model method, such as `PollFeedJob → feed.poll!`.
- **Network I/O goes through Faraday** using the shared connection builder (timeouts, user agent, conditional GET headers). No model or view makes HTTP calls directly.
- **Enums use string values** (`enum :provider, { statuspage: "statuspage", rss: "rss" }`) so the database stays readable.
- **Times:** store UTC and compute "days since" in the user's `time_zone`. Use `Time.current` and `Date.current` in the right zone, never `Time.now`.
- **Hotwire first.** Use Turbo Frames and Streams for interactivity, and Stimulus only when Turbo can't do the job. Don't add a JavaScript build step, because the app uses Importmaps.

## Testing (RSpec)

**Test observable behavior, not implementation.**

- **No shoulda-matchers.** Don't write specs that only restate declarations, like `it { is_expected.to have_many(:subscriptions) }`. Test what the behavior *does*. For example, "subscribing to an existing URL reuses the same Feed".
- **Spec type priorities:**
  1. **Model / PORO specs** for domain logic: counter math, severity filtering, URL normalization, provider parsing, backoff.
  2. **Request specs** for controllers and auth, including `SINGLE_USER_MODE` on and off, and per-user scoping (user A can't see user B's subscriptions).
  3. **System specs** (Capybara + Cuprite) for key user journeys and theme rendering.
  4. **Job specs** only where the job contains logic beyond delegating.
- **factory_bot** for test data. Keep factories minimal and valid, and use traits for variations (`:ongoing`, `:resolved`, `:maintenance`).
- **WebMock blocks all real HTTP.** Stub requests with **hand-written fixtures** in `spec/fixtures/files/` (`statuspage/*.json`, `rss/*.xml`), loaded with `file_fixture`. Don't use VCR.
- **Time-dependent specs** use `travel_to` and set an explicit user time zone. Cover the edge around midnight in the user's zone.
- Every bug fix comes with a spec that reproduces the bug.
- SimpleCov is intentionally deferred, so don't add it yet.

## Theming conventions

Themes are code. To add one, open a pull request. There is no theme table in the database.

### Adding a theme

1. **Register it** in `Theme::REGISTRY` (`app/models/theme.rb`) with its key, display name and description. Optionally give it `level_labels`, its own words for the stability levels (`ongoing`, `day_one`, `short_streak`, `long_streak`, `solid_streak`). Any level it leaves out uses `Theme::DEFAULT_LEVEL_LABELS`. Views get the current theme's word from `stability_label(level)`.
2. **Define tokens** in `app/assets/tailwind/themes/<key>.css`, scoped to `[data-theme="<key>"]` (the attribute sits on `<body>` so Turbo swaps it on every visit), and add `@import "./themes/<key>.css";` to `app/assets/tailwind/application.css`. Tokens are `--ds-*` custom properties (`--ds-canvas`, `--ds-surface`, `--ds-ink`, `--ds-accent`, `--ds-danger`, `--ds-font-display`, optional `--ds-font-numeric` for day counts, …). See `themes/default.css` for the full set. The default values are also the `:root` fallback, so a missing token falls back to the default theme rather than breaking. `application.css` maps the tokens to Tailwind utilities (`bg-surface`, `text-ink`, `font-display`, `rounded-card`, …). Also define a color for each stability level (`--ds-level-ongoing`, `--ds-level-day-one`, `--ds-level-short-streak`, `--ds-level-long-streak`, `--ds-level-solid-streak`). Elements with `data-level` can then use `text-level` / `border-level` / `bg-level`, and `ds-pulse` for live incidents.
3. **Optionally override partials** in `app/views/themes/<key>/`, for example `_feed_card.html.erb`. Any partial a theme doesn't provide falls back to `app/views/themes/default/`. Partials receive the same locals as the default version, so keep the locals interface stable.
4. **Fonts** must be OFL or similarly licensed and **self-hosted** under `app/assets/fonts/`. Commit the license file next to the font.
5. **SVG/graphics** (hazard stripes, signage) go inline in partials or under `app/assets/images/themes/<key>/`.
6. **Specs:** add a system spec that renders the dashboard in the new theme, covering normal, `ONGOING`, and no-incident cards.

### Rules

- Views and components use **semantic Tailwind tokens** (`bg-surface`, `text-accent`). Hard-coded palette classes like `bg-yellow-400` belong only inside a theme's own partials.
- The theme key appears on `<body data-theme="…">` (not `<html>`: Turbo never updates `<html>` attributes, so a theme change would only half-apply). Don't make theme decisions in Ruby beyond choosing which partial to render.
- The default theme supports light and dark modes through `prefers-color-scheme`. Other themes may be single-mode.
- Theme partials stay presentational: they get the counter state (days, ongoing, no-history) already computed and never query the database.
