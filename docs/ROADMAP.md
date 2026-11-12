# Roadmap: after the MVP

Ideas to pick up **after the MVP is complete** (after phase H and the final checkpoint). Nothing here is decided yet. Each item needs a design discussion before we build it.

## Logos

### Service logos on cards
- Show each service's logo on its card.
- Options to explore, roughly in order of effort:
  1. The site's favicon or `apple-touch-icon` from `site_url`, fetched once and cached.
  2. Statuspage pages often show a logo in their HTML header. Scrape it once during detection.
  3. A third-party logo or favicon API. This is a privacy and dependency tradeoff, and our `HttpClient` currently blocks it by design.
  4. Let users upload or override a logo per subscription (Active Storage).
- Store the logo on `Feed`, since it's shared, with an optional per-subscription override.

## Carried over from MVP decisions

- **SimpleCov** coverage reporting (deferred in decision 8c).
- Switch to **feature branches and PRs** once the MVP ships (decision 9b).
- **Deployment** with Kamal + Thruster, plus production `SINGLE_USER_MODE` guidance.
- **Streak history UI:** longest streak, incident timeline. We already keep every incident (decision 2b).
- **Time zone picker** should support IANA names (`America/Chicago`), not only Rails zone names.
- **URL query strings:** normalization strips them (decision 2c). Revisit if a real feed needs one, for example `?format=rss`.
- **Google Cloud-style feeds** post one entry per *update*, so one incident becomes several entries. Consider grouping them by the incident ID inside the entry ID.
