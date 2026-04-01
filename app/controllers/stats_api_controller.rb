class StatsApiController < ApplicationController
  skip_before_action :check_if_login_required
  before_action :authorize_token

  CACHE_DIR = Rails.root.join("tmp", "stats_api_cache")
  CACHE_TTL = 86_400

  def index
    json = cached("global") { build_global_stats }
    render json: json, content_type: "application/json"
  end

  def project
    proj = Project.find_by(identifier: params[:project_id]) ||
           Project.find_by(id: params[:project_id])
    unless proj
      return render json: { error: "Project not found" }, status: :not_found
    end
    json = cached("project_#{proj.id}") { build_project_stats(proj) }
    render json: json, content_type: "application/json"
  end

  private

  def authorize_token
    expected = Setting.plugin_redmine_stats_api["api_token"] rescue "rSt4t5_2026xK9"
    unless params[:token].present? && ActiveSupport::SecurityUtils.secure_compare(params[:token], expected)
      render json: { error: "Access denied" }, status: :forbidden
    end
  end

  def cached(key)
    FileUtils.mkdir_p(CACHE_DIR) unless CACHE_DIR.exist?
    cache_file = CACHE_DIR.join("#{key}.json")
    if cache_file.exist? && (Time.now - cache_file.mtime) < CACHE_TTL
      return cache_file.read
    end
    data = yield
    json = JSON.pretty_generate(data)
    File.write(cache_file, json)
    json
  end

  def db
    ActiveRecord::Base.connection
  end

  def fmt_ym
    "'%Y-%m'"
  end

  # ── GLOBAL STATS ──

  def build_global_stats
    {
      generated_at: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      cache_ttl_seconds: CACHE_TTL,
      overall: overall_summary,
      recent: recent_counts,
      overdue: overdue_count,
      resolution_time: resolution_time,
      by_status: by_status,
      by_tracker: by_tracker,
      by_priority: by_priority,
      by_project: by_project,
      by_assignee: by_assignee,
      monthly_trend: monthly_trend,
      by_day_of_week: by_day_of_week,
      oldest_open: oldest_open
    }
  end

  def overall_summary(where = "1=1")
    db.select_one(
      "SELECT COUNT(*) AS total," \
      " SUM(CASE WHEN s.is_closed = 0 THEN 1 ELSE 0 END) AS open," \
      " SUM(CASE WHEN s.is_closed = 1 THEN 1 ELSE 0 END) AS closed," \
      " ROUND(SUM(CASE WHEN s.is_closed = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS close_rate" \
      " FROM issues i JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE #{where}"
    )
  end

  def by_status(where = "1=1")
    db.select_all(
      "SELECT s.name AS status, COUNT(*) AS count" \
      " FROM issues i JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE #{where}" \
      " GROUP BY s.name, s.position ORDER BY s.position"
    ).to_a
  end

  def by_tracker(where = "1=1")
    db.select_all(
      "SELECT t.name AS tracker, COUNT(*) AS total," \
      " SUM(CASE WHEN s.is_closed = 0 THEN 1 ELSE 0 END) AS open," \
      " SUM(CASE WHEN s.is_closed = 1 THEN 1 ELSE 0 END) AS closed" \
      " FROM issues i" \
      " JOIN trackers t ON i.tracker_id = t.id" \
      " JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE #{where}" \
      " GROUP BY t.name ORDER BY total DESC"
    ).to_a
  end

  def by_priority(where = "1=1")
    db.select_all(
      "SELECT e.name AS priority, COUNT(*) AS total," \
      " SUM(CASE WHEN s.is_closed = 0 THEN 1 ELSE 0 END) AS open" \
      " FROM issues i" \
      " JOIN enumerations e ON i.priority_id = e.id AND e.type = 'IssuePriority'" \
      " JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE #{where}" \
      " GROUP BY e.name, e.position ORDER BY e.position"
    ).to_a
  end

  def by_project
    db.select_all(
      "SELECT p.name AS project, p.identifier, COUNT(*) AS total," \
      " SUM(CASE WHEN s.is_closed = 0 THEN 1 ELSE 0 END) AS open" \
      " FROM issues i" \
      " JOIN projects p ON i.project_id = p.id" \
      " JOIN issue_statuses s ON i.status_id = s.id" \
      " GROUP BY p.name, p.identifier ORDER BY total DESC LIMIT 30"
    ).to_a
  end

  def by_assignee(where = "1=1")
    db.select_all(
      "SELECT COALESCE(CONCAT(u.firstname, ' ', u.lastname), 'Unassigned') AS assignee," \
      " COUNT(*) AS total," \
      " SUM(CASE WHEN s.is_closed = 0 THEN 1 ELSE 0 END) AS open" \
      " FROM issues i" \
      " LEFT JOIN users u ON i.assigned_to_id = u.id" \
      " JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE #{where}" \
      " GROUP BY assignee ORDER BY open DESC LIMIT 20"
    ).to_a
  end

  def monthly_trend(where = "1=1")
    ym = fmt_ym
    db.select_all(
      "SELECT DATE_FORMAT(i.created_on, #{ym}) AS month," \
      " COUNT(*) AS created," \
      " SUM(CASE WHEN i.closed_on IS NOT NULL" \
      " AND DATE_FORMAT(i.closed_on, #{ym}) = DATE_FORMAT(i.created_on, #{ym})" \
      " THEN 1 ELSE 0 END) AS closed_same_month" \
      " FROM issues i" \
      " WHERE i.created_on >= DATE_SUB(NOW(), INTERVAL 12 MONTH) AND #{where}" \
      " GROUP BY month ORDER BY month"
    ).to_a
  end

  def resolution_time(where = "1=1")
    db.select_one(
      "SELECT" \
      " ROUND(AVG(TIMESTAMPDIFF(HOUR, i.created_on, i.closed_on)) / 24, 1) AS avg_days," \
      " ROUND(MIN(TIMESTAMPDIFF(HOUR, i.created_on, i.closed_on)) / 24, 1) AS min_days," \
      " ROUND(MAX(TIMESTAMPDIFF(HOUR, i.created_on, i.closed_on)) / 24, 1) AS max_days," \
      " COUNT(*) AS sample_size" \
      " FROM issues i" \
      " WHERE i.closed_on IS NOT NULL AND i.closed_on >= DATE_SUB(NOW(), INTERVAL 12 MONTH) AND #{where}"
    )
  end

  def overdue_count(where = "1=1")
    db.select_value(
      "SELECT COUNT(*) FROM issues i" \
      " JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE s.is_closed = 0 AND i.due_date < CURDATE() AND #{where}"
    )
  end

  def recent_counts(where = "1=1")
    ym = fmt_ym
    db.select_one(
      "SELECT" \
      " SUM(CASE WHEN DATE(i.created_on) = CURDATE() THEN 1 ELSE 0 END) AS today," \
      " SUM(CASE WHEN YEARWEEK(i.created_on, 1) = YEARWEEK(CURDATE(), 1) THEN 1 ELSE 0 END) AS this_week," \
      " SUM(CASE WHEN DATE_FORMAT(i.created_on, #{ym}) = DATE_FORMAT(CURDATE(), #{ym}) THEN 1 ELSE 0 END) AS this_month" \
      " FROM issues i WHERE i.created_on >= DATE_SUB(NOW(), INTERVAL 31 DAY) AND #{where}"
    )
  end

  def by_day_of_week(where = "1=1")
    db.select_all(
      "SELECT DAYNAME(i.created_on) AS day, COUNT(*) AS count" \
      " FROM issues i" \
      " WHERE i.created_on >= DATE_SUB(NOW(), INTERVAL 12 MONTH) AND #{where}" \
      " GROUP BY DAYOFWEEK(i.created_on), day" \
      " ORDER BY DAYOFWEEK(i.created_on)"
    ).to_a
  end

  def oldest_open(where = "1=1")
    db.select_all(
      "SELECT i.id, p.name AS project, t.name AS tracker," \
      " i.subject, DATE(i.created_on) AS created," \
      " DATEDIFF(NOW(), i.created_on) AS age_days" \
      " FROM issues i" \
      " JOIN projects p ON i.project_id = p.id" \
      " JOIN trackers t ON i.tracker_id = t.id" \
      " JOIN issue_statuses s ON i.status_id = s.id" \
      " WHERE s.is_closed = 0 AND #{where}" \
      " ORDER BY i.created_on ASC LIMIT 10"
    ).to_a
  end

  # ── PER-PROJECT STATS ──

  def build_project_stats(proj)
    w = "i.project_id = #{proj.id.to_i}"
    {
      generated_at: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      cache_ttl_seconds: CACHE_TTL,
      project: { id: proj.id, name: proj.name, identifier: proj.identifier },
      overall: overall_summary(w),
      recent: recent_counts(w),
      overdue: overdue_count(w),
      resolution_time: resolution_time(w),
      by_status: by_status(w),
      by_tracker: by_tracker(w),
      by_priority: by_priority(w),
      by_assignee: by_assignee(w),
      monthly_trend: monthly_trend(w),
      by_day_of_week: by_day_of_week(w),
      oldest_open: oldest_open(w)
    }
  end
end
