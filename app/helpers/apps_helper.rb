module AppsHelper
  def setup_instruction_color(is_completed)
    is_completed ? "bg-green-400" : "bg-blue-200"
  end
end
