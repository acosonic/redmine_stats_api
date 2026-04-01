require_dependency File.join(File.dirname(__FILE__), 'lib', 'stats_queries')

Redmine::Plugin.register :redmine_stats_api do
  name "Redmine Stats API"
  author "DomDistrict"
  description "Ticket statistics dashboard and JSON API with daily caching"
  version "2.0.0"

  settings default: {
    "api_token" => "rSt4t5_2026xK9"
  }, partial: nil

  project_module :statistics do
    permission :view_project_statistics, { project_stats: [:show] }, public: false
  end

  menu :project_menu, :statistics,
    { controller: 'project_stats', action: 'show' },
    caption: 'Statistics',
    after: :activity,
    param: :project_id
end
