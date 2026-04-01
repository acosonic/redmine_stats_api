# Redmine Stats API Plugin

A Redmine plugin that exposes ticket statistics as a JSON API with daily file-based caching.

## Compatibility

- Redmine 4.x (tested on 4.1.0)
- Ruby 2.6+
- MySQL / MariaDB

## Installation

```bash
cd /path/to/redmine/plugins
git clone <repo-url> redmine_stats_api
touch /path/to/redmine/tmp/restart.txt   # restart Passenger
# or: systemctl restart redmine
```

No migrations required.

## Endpoints

### Global Statistics

```
GET /stats_api?token=YOUR_TOKEN
```

Returns:

- **overall** — total, open, closed, close rate
- **recent** — tickets created today, this week, this month
- **overdue** — count of open tickets past due date
- **resolution_time** — avg/min/max days to close (last 12 months)
- **by_status** — ticket counts per status
- **by_tracker** — totals per tracker (Bug, Feature, Support, Task)
- **by_priority** — totals per priority level
- **by_project** — top 30 projects by volume
- **by_assignee** — top 20 assignees by open ticket count
- **monthly_trend** — created vs closed per month (last 12 months)
- **by_day_of_week** — ticket volume per weekday (last 12 months)
- **oldest_open** — 10 oldest open tickets

### Per-Project Statistics

```
GET /stats_api/project/:identifier?token=YOUR_TOKEN
GET /stats_api/project/:id?token=YOUR_TOKEN
```

Returns the same breakdown scoped to a single project (excludes `by_project`).

## Authentication

Requests require a `token` query parameter. The default token is set in `init.rb` and can be changed via:

**Administration > Plugins > Redmine Stats API > Settings**

## Caching

- Responses are cached as JSON files in `tmp/stats_api_cache/`
- Cache TTL: **24 hours** (configurable via `CACHE_TTL` in the controller)
- Global and per-project caches are independent
- To force a refresh, delete the cache files:

```bash
rm -f /path/to/redmine/tmp/stats_api_cache/*.json
```

## Example Response

```json
{
  "generated_at": "2026-04-01 12:43:47",
  "cache_ttl_seconds": 86400,
  "overall": {
    "total": 277595,
    "open": 14805,
    "closed": 262790,
    "close_rate": "94.7"
  },
  "recent": {
    "today": 95,
    "this_week": 335,
    "this_month": 95
  },
  "overdue": 22,
  "resolution_time": {
    "avg_days": "15.0",
    "min_days": "0.0",
    "max_days": "791.0",
    "sample_size": 84540
  }
}
```

## File Structure

```
redmine_stats_api/
├── init.rb                              # Plugin registration
├── config/routes.rb                     # Route definitions
├── app/controllers/stats_api_controller.rb  # All logic + caching
└── README.md
```

## License

MIT
