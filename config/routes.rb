get "stats_api", to: "stats_api#index"
get "stats_api/project/:project_id", to: "stats_api#project"
get "projects/:project_id/statistics", to: "project_stats#show", as: "project_statistics"
