require_dependency File.join(File.dirname(__FILE__), '..', '..', 'lib', 'stats_queries')

class ProjectStatsController < ApplicationController
  include StatsQueries

  before_action :find_project_by_project_id, :authorize

  def show
    @stats = cached("project_ui_#{@project.id}") { build_project_stats(@project) }
  end

  private

  def find_project_by_project_id
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
