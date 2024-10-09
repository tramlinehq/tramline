module AppsHelper
  def setup_instruction_color(is_completed)
    is_completed ? "bg-green-400" : "bg-blue-200"
  end

  def store_logo(app)
    return "integrations/logo_app_store.png" if app.ios?
    "integrations/logo_google_play_store.png" if app.android?
  end
end
