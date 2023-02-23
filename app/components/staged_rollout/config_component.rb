class StagedRollout::ConfigComponent < ViewComponent::Base
  include AssetsHelper

  def initialize(config:, current_stage: nil)
    @config = config
    @current_stage = current_stage
  end

  attr_reader :config, :current_stage

  def stage_perc(stage)
    return "0%" if stage.nil?
    "#{stage}%"
  end

  def until_current?(stage)
    return false if current_stage.nil?
    current_stage >= stage
  end
end
