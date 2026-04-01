Redmine::Plugin.register :redmine_stats_api do
  name "Redmine Stats API"
  author "DomDistrict"
  description "JSON statistics endpoint with daily caching"
  version "1.0.0"

  settings default: {
    "api_token" => "rSt4t5_2026xK9"
  }, partial: nil
end
