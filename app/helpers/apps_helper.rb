module AppsHelper
  def setup_instruction_color(is_completed)
    is_completed ? "bg-green-400" : "bg-blue-200"
  end

  def store_logo(app)
    return "integrations/logo_app_store.png" if app.ios?
    "integrations/logo_google_play_store.png" if app.android?
  end

  MOVEMENT_STATUS_COLORS = {
    in_progress: "bg-amber-500",
    done: "bg-indigo-500",
    failed: "bg-red-500",
    not_started: "bg-slate-300"
  }.freeze

  def movement_status(status_summary)
    status_summary.key(true)
  end

  def movement_status_text(status_summary)
    (movement_status(status_summary) || :processing).to_s.titleize
  end

  def movement_status_color(status_summary)
    MOVEMENT_STATUS_COLORS.fetch(movement_status(status_summary), "bg-slate-100")
  end
end
