class StagedRollout::ConfigComponent < ViewComponent::Base
  include AssetsHelper

  def initialize(config:, current_stage: nil, disabled: false)
    @config = config
    @current_stage = current_stage
    @disabled = disabled
  end

  attr_reader :config, :current_stage, :disabled

  def stage_perc(stage)
    return "0%" if stage.nil?
    "#{stage}%"
  end

  def until_current?(stage)
    return false if current_stage.nil?
    current_stage >= stage
  end

  def wrapper_class
    base_class = "w-48"
    base_class += " opacity-50" if disabled
    base_class
  end
end
