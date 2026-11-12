# Roadmap: after the MVP

Ideas to pick up **after the MVP is complete** (after phase H and the final checkpoint). Nothing here is decided yet. Each item needs a design discussion before we build it.

## Logos

- **Logo uploads.** Logos are fetched automatically from each status page, falling back to a monogram. Next would be letting users upload or override a logo (Active Storage is already installed). Decide between a per-subscription override and a shared one on the feed.

## Carried over from MVP decisions

- **SimpleCov** coverage reporting (deferred in decision 8c).
- Switch to **feature branches and PRs** once the MVP ships (decision 9b).
- **Deployment** with Kamal + Thruster, plus production `SINGLE_USER_MODE` guidance.
- **Streak history UI:** longest streak, incident timeline. We already keep every incident (decision 2b).
- **Time zone picker** should support IANA names (`America/Chicago`), not only Rails zone names.
- **URL query strings:** normalization strips them (decision 2c). Revisit if a real feed needs one, for example `?format=rss`.
- **Google Cloud-style feeds** post one entry per *update*, so one incident becomes several entries. Consider grouping them by the incident ID inside the entry ID.
