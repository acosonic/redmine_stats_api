# Redmine Stats API Plugin

Ticket statistics dashboard and JSON API for Redmine, with daily file-based caching.

## Features

- **Project module** — "Statistics" tab in the project menu, toggleable on/off per project
- **JSON API** — global and per-project endpoints with token auth
- **24-hour caching** — file-based, no extra dependencies
- **Charts** — monthly trend and day-of-week bar charts (Chart.js)

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

## Enabling the Statistics Module

1. Go to **Administration > Roles and Permissions**
2. Check **"View project statistics"** for the roles that should see stats
3. Go to **Project > Settings > Modules**
4. Enable **"Statistics"**
5. The "Statistics" tab now appears in the project menu

## JSON API

### Global Statistics

```
GET /stats_api?token=YOUR_TOKEN
```

### Per-Project Statistics

```
GET /stats_api/project/:identifier?token=YOUR_TOKEN
GET /stats_api/project/:id?token=YOUR_TOKEN
```

Both return:

- **overall** — total, open, closed, close rate
- **recent** — tickets created today, this week, this month
- **overdue** — count of open tickets past due date
- **resolution_time** — avg/min/max days to close (last 12 months)
- **by_status** — ticket counts per status
- **by_tracker** — totals per tracker (Bug, Feature, Support, Task)
- **by_priority** — totals per priority level
- **by_project** — top 30 projects by volume (global only)
- **by_assignee** — top 20 assignees by open ticket count
- **monthly_trend** — created vs closed per month (last 12 months)
- **by_day_of_week** — ticket volume per weekday (last 12 months)
- **oldest_open** — 10 oldest open tickets

## Authentication

- **UI**: uses Redmine's built-in auth and role permissions
- **API**: requires a `token` query parameter (default set in `init.rb`, changeable via Administration > Plugins)

## Caching

- Responses are cached as JSON files in `tmp/stats_api_cache/`
- Cache TTL: **24 hours** (configurable via `CACHE_TTL` in `lib/stats_queries.rb`)
- Global, API per-project, and UI per-project caches are independent
- To force a refresh:

```bash
rm -f /path/to/redmine/tmp/stats_api_cache/*.json
```

## File Structure

```
redmine_stats_api/
├── init.rb                                        # Plugin registration, module, menu
├── config/routes.rb                               # Route definitions
├── lib/stats_queries.rb                           # Shared query logic + caching
├── app/controllers/stats_api_controller.rb        # JSON API (token auth)
├── app/controllers/project_stats_controller.rb    # UI controller (Redmine auth)
├── app/views/project_stats/show.html.erb          # Dashboard view with charts
└── README.md
```

## License

MIT
