# Roadmap: after the MVP

Ideas to pick up **after the MVP is complete** (after phase H and the final checkpoint). Nothing here is decided yet. Each item needs a design discussion before we build it.

## Logos

- **Logo uploads.** Logos are fetched automatically from each status page, falling back to a monogram. Next would be letting users upload or override a logo (Active Storage is already installed). Decide between a per-subscription override and a shared one on the feed.

## Ideas from mrshu/github-statuses

Taken from [mrshu/github-statuses](https://github.com/mrshu/github-statuses), an unofficial GitHub status history built by scraping Statuspage's `history.atom` into git every day. Listed in suggested order.

### Feed accuracy

1. **Parse the update history in RSS/Atom entries.** Statuspage-style entries contain update lines such as `<small>Mar 5, 14:02 UTC</small><strong>Investigating</strong> – …`. Use them to get:
   - a real `started_at` (the first update, preferably "Investigating")
   - a real `resolved_at` (the last "Resolved")
   - the **ongoing** state when there is no "Resolved" yet

   Today `FeedProviders::Rss` treats every entry as resolved at the moment it was published, so RSS-only pages never show a live incident. Fall back to the current behaviour when an entry has no update lines.

2. **Severity for RSS incidents.** Fetch each incident page once and read the `impact-<level>` CSS class (`none`, `minor`, `major`, `critical`, `maintenance`). That fills in `impact` so the severity threshold applies to RSS incidents. Fetch only new or changed incidents, cache the result on the incident, rate-limit the requests, and keep `unknown` when a page has no class.

3. **Edited resolutions.** GitHub rewrites its "Resolved" update to add a root-cause write-up, and the feed republishes it under the original timestamp. Add a spec confirming that polling updates the existing incident (upsert on `external_id`) rather than duplicating it.

### Display

4. **Uptime %.** Compute uptime per service over 90 days and all time:
   - take each incident's window (`started_at` to `resolved_at`, or now if ongoing) and skip maintenance
   - merge overlapping windows
   - uptime = 1 − downtime minutes ÷ minutes in the period

   Show it on cards and in themes that suit it (GitHub, Datadog, Mission Control). Decide whether the severity threshold applies, i.e. "uptime counting minor+".

5. **Color history days by worst severity.** *Partly done:* the counter now reports `worst_impacts` and `tracked_since`, and the default theme uses them. Still to do: use them in the GitHub, Datadog and Mission Control themes, which still color by count only.

6. **Component filters.** Statuspage incidents list the affected `components`. Let a subscription count only the components the user cares about, e.g. "days since a GitHub **Actions** incident". This needs schema decisions:
   - store components per incident (a join table, or JSON on `Incident`)
   - store the selected components on `Subscription`, since they are a personal preference
   - pick the components from the page's `components.json`

   RSS fallback: parse "This incident affected: X, Y" from the incident text or page.

7. **Postmortem impact windows.** Parse the actual impact window out of postmortem text ("On March 5, 2026, between 14:00 UTC and 15:30 UTC") and prefer it over the posting times when computing downtime. Only worth doing together with uptime %.

Not planned: their ML guess of affected components (GLiNER2). It's a heavy runtime that only fills gaps in GitHub's own tagging.

## Carried over from MVP decisions

- **SimpleCov** coverage reporting (deferred in decision 8c).
- Switch to **feature branches and PRs** once the MVP ships (decision 9b).
- **Deployment** with Kamal + Thruster, plus production `SINGLE_USER_MODE` guidance.
- **Streak history UI:** longest streak, incident timeline. We already keep every incident (decision 2b).
- **Time zone picker** should support IANA names (`America/Chicago`), not only Rails zone names.
- **URL query strings:** normalization strips them (decision 2c). Revisit if a real feed needs one, for example `?format=rss`.
- **Google Cloud-style feeds** post one entry per *update*, so one incident becomes several entries. Consider grouping them by the incident ID inside the entry ID.

## Last: history backfill

- **Backfill incident history from `/history.json`.** `/api/v2/incidents.json` only returns the 50 most recent incidents. That's about 2 weeks for Cloudflare and 2–3 months for GitHub or Claude (checked 2026-11-12). Statuspage pages also serve an undocumented `/history.json?page=N`, three months per page; GitHub's goes back to 2011. Each incident has:
  - `code` (matches our `external_id`)
  - `name`
  - `impact`
  - `timestamp` (`Nov 28, 06:59 - 08:23 UTC`, with the year taken from the month the incident is listed under)
  - `message` (often the postmortem)

  Run it as a throttled one-time job when a feed is first subscribed, so uptime % and history views have data from day one. Caveats:
  - The endpoint is undocumented and could change.
  - Times are only accurate to the minute and arrive as HTML that needs parsing.
  - A full backfill is many requests (about 60 for GitHub).
