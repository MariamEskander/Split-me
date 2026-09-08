# Luciq MCP tools — reference

All 35 tools. Every app-scoped tool requires `slug` and `mode`; get both from
`list_applications`. Dates are epoch milliseconds and omitted date filters mean
the last 7 days. Write tools are marked ✎.

| Area | Tool | Key filters / inputs |
| --- | --- | --- |
| Discovery | `list_applications` | `platform` (ios / android / react_native / flutter), `limit`, `offset` |
| Discovery | `get_luciq_skills` | `name` (omit for the index), `file` |
| Docs | `search_documentation` | `query` |
| Docs | `get_documentation_page` | `url` |
| Triage | `list_issues` | `crashes_types`, `apm_types` (networks / traces / launches / screen_loadings / frame_drops), `ai_issues_types` (visual_issue / broken_functionality), `bugs_types`, `apdex_severity` (high / medium / low / no_impact), `app_version`, `platform`, `teams`, `search_tokens`, `top_issues`, `date_ms` (≥ 24 h); sort `apdex_impact` or `occurrences_counter`; per-source `pagination` tokens |
| Crashes | `list_crashes` | `type` (CRASH / ANR / OOM / NON_FATAL), `subtype` (CRITICAL / ERROR / WARNING / INFO — needs NON_FATAL), `status_id` (1 open, 2 closed, 3 in progress), `app_versions`, `devices`, `os_versions`, `current_views`, `platform` (IOS / ANDROID / DART / JAVASCRIPT), `teams`, **`feature_flags`**, `user_uuids` (≤100), `user_attributes` (array of `{operator, text}` per key), `date_ms`; sort `last_occurred_at`, `occurrences_counter`, `affected_users_counter`, `severity`, `first_occurred_at`, `min/max_app_version` |
| Crashes | `crash_details` | `number` |
| Crashes | `crash_diagnostics` | `number` — stacktrace, device metrics, distributions, screen flows. Re-call while `status: "generating"` |
| Crashes | `crash_patterns` | `number`, `pattern_key` (`app_versions` / `devices` / `oses` / `current_views` / `app_status` / `experiments`), `app_versions`, `devices`, `os_versions`, `date_ms`; sort `occurrences_count` / `last_seen` / `first_seen` |
| Crashes | `list_occurrences_tokens` | `number`, `app_status` (foreground / background), `app_versions`, `current_views`, `devices`, `os_versions`, **`experiments`**, `user_uuids`, `date_ms`, `current_token`, `direction` |
| Crashes | `get_occurrence_details` | `number` + `ulid` |
| Hangs | `list_app_hangs` | `app_versions`, `current_views`, `devices`, `os_versions`, `platform`, `status_id`, `teams`, `user_uuids`, `date_ms`; same sorts as crashes |
| Bugs | `list_bugs` | `priority_id` (−1 N/A, 1 Trivial, 2 Minor, 3 Major, 4 Blocker), `status_id` (1 New, 2 Closed, 3 In Progress), `tag` / `no_tag`, `category` / `no_category`, `forwarded_to` / `not_forwarded_to`, `duplicate_type`, `email` (`{operator, value}`), `has_description`, `title`, `app_version`, `devices`, `os_versions`, `platform`, `device_class` (Android), **`experiments`**, `user_uuids`, `user_attributes` (`{operator, value}`), `reported_at` (`from` / `to`) |
| Bugs | `bug_details` | `number` |
| Bugs ✎ | `update_bug` | `number` + one of `status_id`, `priority_id`, `tags` (+ `tag_action`: append / remove / replace), or `action` (`mark_as_duplicate` needs `original_bug_number`, `unmark_as_duplicate`) |
| AI issues | `ai_issue_details` | `issue_type` (visual_issue / broken_functionality), `id`, `occurrences_limit`, `occurrences_pagination_token` |
| AI issues | `ai_issue_occurrence_details` | `issue_type`, `number` — returns the screenshots as images |
| Health | `app_insights` | `app_version`, `date_ms` — crashes, bugs, APM and stability rates in one call |
| Health | `app_version_adoption` | `app_versions` (exact, e.g. `"1.0 (2)"`, ≤20), `include_daily_trend` |
| Per user | `user_summary` | `user_uuid` (exact SDK id), `period_days` (≤56) |
| Replays | `list_session_replays` | `user` (**the only filter that resolves emails**), `issues` (fatal_crash / ndk_crash / anr / oom / fatal_hang / app_termination / non_fatal_crash / ai_issues), `session_class` (satisfying / tolerable / frustrating / crashing), `countries`, **`experiments`**, `devices`, `os_versions`, `app_versions` (must be `"version (build)"`), `user_attributes` (single `{operator, text}`), `date_ms`, `pagination_token` |
| APM | `apm_list_groups` | `metric` (network / launch / flows / screen_loading / frame_drop / funnels), `group_name`, ranges on `50th_percentile_ms`, `95th_percentile_ms`, `apdex`, `apdex_change`, `count`, `dissat_count`, `client/server/total_failure_rate` (network), `occurrence_classification`, `session_classification` (funnels), `view_type`, `key_metric`, `platform`, `app_version`, `teams`, `user_uuids` |
| APM | `apm_group_view` | `metric`, `group_uuid` or `group_url` (+ `method`), `views` (`summary`, `apdex_chart`, `throughput_chart`, `failure_rate`, `spans_table`, `dimensions`, `outliers`, `stages_breakdown`, `web_vitals`, `frames_distribution`, `delayed_frames`, `steps`, `trends`, `issues`), per-view `sort` / `limit` / `offset` / `pattern_key` / `step_range`; filters add `carrier`, `country`, `radio`, `failure_name/type`, payload sizes, `response_time_ms`, `first_screen`, `battery_level`, `power_saving`, `span_name`, **`experiment`**, `custom_attributes` |
| APM | `apm_occurrence` | `metric`, `selector` (worst / by_token / list), `token`, `group_uuid` or `group_url`, `latency_percentile` (fast / regular / slow / outlier), `poor_occurrences`, `current_token`, `direction`, `limit` |
| APM | `apm_funnel_events` | `event_type` (network / screen_loading), `q` (substring), `limit` (≤25) |
| APM ✎ | `apm_funnel_write` | `operation` (create / update / delete), `name`, `steps` (2–20 ordered, each an OR group of ≤5 events, `{type, name or ulid}`), `ulid` |
| Store | `list_reviews` | `rating` (1–5), `country`, `prompt_type` (custom / native / app_store), `os`, `app_version`, `date_ms` |
| Surveys | `list_surveys` | `status` (0 draft, 1 published, 2 paused), `type` (0 custom, 1 nps, 2 app_store) |
| Surveys | `survey_details` | `id`, `page`; filters `nps` (0–10), `response_status` (0 open, 1 closed), `search_words`, `locale`, `countries`, `devices`, `os_versions`, `platforms`, `app_versions`, `date_ms` |
| Product | `list_opportunities` | `priority` (1–4 / unset), `status` (open / in_progress / closed / dismissed), `team_id` |
| Product | `opportunity_details` | `id` |
| Alerts | `read_alerts` | `action` (list / details / **init**), `ulid`, `sort_by` (latest_creation_date / last_edit_date / highest_triggered_count) |
| Alerts ✎ | `write_alerts` | `action` (create / update / delete), `type`, `trigger`, `conditions`, `actions`, `trigger_options`, `operation` (0 AND, 1 OR), `rule_owner`, `title`, `ulid`. Call `read_alerts init` first — anything absent from init is rejected |
| Incidents | `read_incidents` | `action` (list / details), `status` (open / manual_resolve / automatic_resolve), `type` (12 values incl. crash / anr / oom / non_fatal / fatal_ui_hang / feature_experiment), `title` tokens, `date_ms`, `sort_by` (first_triggered / last_triggered / count) |
| Incidents ✎ | `write_incidents` | `action` (resolve / reopen), `ulid` |

## The same concept, four different parameter names

Feature flags / experiments are spelled differently per tool. This is the most
likely cause of an empty result that looks like a syntax error:

| Tool | Parameter |
| --- | --- |
| `list_crashes` | `feature_flags` |
| `list_bugs`, `list_session_replays`, `list_occurrences_tokens` | `experiments` |
| `apm_group_view`, `apm_occurrence` | `experiment` (singular) |
| `crash_patterns` | `pattern_key: "experiments"` |

Value format is the same everywhere: the bare flag name (`"private_mode"`), or
`"flag_name -> variant"` when a variant was set.

## Other shape differences to watch

- **`user_attributes`** takes three shapes: an *array* of `{operator, text}` per
  key in `list_crashes`; a *single* `{operator, text}` in `list_session_replays`;
  a single `{operator, value}` in `list_bugs`.
- **Date filters**: `date_ms` with `gte`/`lte` everywhere except `list_bugs`,
  which uses `reported_at` with `from`/`to`.
- **App versions**: `list_session_replays` and `app_version_adoption` require
  `"1.0 (2)"` — version *and* build. Other tools accept a bare `"1.0"`.
- **Emails**: only `list_session_replays.filters.user` resolves an email. Take
  `user.id` off that row and feed it to `user_summary` or `list_bugs`.
