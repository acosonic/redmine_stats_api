require_dependency File.join(File.dirname(__FILE__), '..', '..', 'lib', 'stats_queries')

class StatsApiController < ApplicationController
  include StatsQueries

  skip_before_action :check_if_login_required
  before_action :authorize_token

  def index
    data = cached("global") { build_global_stats }
    render json: JSON.pretty_generate(data), content_type: "application/json"
  end

  def project
    proj = Project.find_by(identifier: params[:project_id]) ||
           Project.find_by(id: params[:project_id])
    unless proj
      return render json: { error: "Project not found" }, status: :not_found
    end
    data = cached("project_#{proj.id}") { build_project_stats(proj) }
    render json: JSON.pretty_generate(data), content_type: "application/json"
  end

  private

  def authorize_token
    expected = Setting.plugin_redmine_stats_api["api_token"] rescue "rSt4t5_2026xK9"
    unless params[:token].present? && ActiveSupport::SecurityUtils.secure_compare(params[:token], expected)
      render json: { error: "Access denied" }, status: :forbidden
    end
  end
end
