# Roadmap: after the MVP

Ideas to pick up **after the MVP is complete** (after phase H and the final checkpoint). Nothing here is decided yet. Each item needs a design discussion before we build it.

## Card clarity and color

### Color thresholds (red / yellow / green)
- Color each card by how recently the service had an incident, so you can see at a glance which services are incident-prone right now.
- Ship sensible **defaults**, for example red for 0–1 days, yellow for 2–6 days and green for 7+ days.
- Let each user **customize** the thresholds in Settings. Maybe allow per-subscription overrides too, like the severity override.
- Open questions:
  - Where do theme colors stop and threshold colors start?
  - How does each structural theme (Worksite, Farmhouse, …) show the levels?
  - Should "∞ / no incidents" always count as green?

### Make "0 days" look urgent even when nothing is ongoing
- Today a card only gets a red outline while an incident is **ongoing**. A card at **0 days** because something was resolved today looks calm, with no outline, even though the service just had an incident.
- The color thresholds above would cover this: 0 days should always show the most severe color.

### Explain which incident the counter is using
- *Reported with Huntress:* the card's "Last:" incident (Nov 2, **major**) didn't match the top of the status page (Nov 3, impact **none**). The newer incident was filtered out by the "minor and worse" threshold, and the card gives no hint of that.
- Ideas:
  - Label it "Last counted incident (minor+)".
  - Add a note such as "1 lower-severity incident since".
  - Add a tooltip showing the active threshold.
  - Link to the full incident list.

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
