class StagedRolloutsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, only: %i[increase halt]
  before_action :set_release, only: %i[edit_all]
  before_action :set_deployment_run, except: [:edit_all]
  before_action :set_staged_rollout, except: [:edit_all]
  before_action :ensure_controlled_rolloutable, only: [:increase, :halt]
  before_action :ensure_rolloutable, only: [:fully_release, :resume]
  before_action :ensure_auto_rolloutable, only: [:pause]

  def edit_all
    @app = @release.app
  end

  def increase
    @staged_rollout.move_to_next_stage!

    if @staged_rollout.failed?
      redirect_back fallback_location: root_path, flash: {error: "Failed to increase the rollout. Please retry!"}
    else
      redirect_back fallback_location: root_path, notice: "Increased the rollout!"
    end
  end

  def pause
    unless @staged_rollout.may_pause?
      redirect_back fallback_location: root_path, flash: {error: "Rollout cannot be paused at this stage."}
      return
    end

    @staged_rollout.pause_release!

    if @staged_rollout.paused?
      redirect_back fallback_location: root_path, notice: "Paused the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to pause the rollout. Please retry!"}
    end
  end

  def resume
    unless @staged_rollout.may_resume?
      redirect_back fallback_location: root_path, flash: {error: "Rollout cannot be resumed at this stage."}
      return
    end

    @staged_rollout.resume_release!

    if @staged_rollout.started?
      redirect_back fallback_location: root_path, notice: "Resumed the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to resume the rollout. Please retry!"}
    end
  end

  def halt
    unless @staged_rollout.may_halt?
      redirect_back fallback_location: root_path, flash: {error: "Rollout cannot be halted at this stage."}
      return
    end

    @staged_rollout.halt_release!

    if @staged_rollout.stopped?
      redirect_back fallback_location: root_path, notice: "Halted the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to halt the rollout. Please retry!"}
    end
  end

  def fully_release
    @staged_rollout.fully_release!

    if @staged_rollout.fully_released?
      redirect_back fallback_location: root_path, notice: "Released to all users!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to release to all users due to #{@deployment_run.display_attr(:failure_reason)}"}
    end
  end

  private

  def ensure_rolloutable
    unless @deployment_run.rolloutable?
      redirect_back fallback_location: root_path, flash: {error: "Cannot perform this operation. The deployment is not in rollout stage."}
    end
  end

  def ensure_controlled_rolloutable
    unless @deployment_run.controllable_rollout?
      redirect_back fallback_location: root_path, flash: {error: "Cannot perform this operation. The deployment is not in rollout stage."}
    end
  end

  def ensure_auto_rolloutable
    unless @deployment_run.automatic_rollout?
      redirect_back fallback_location: root_path, flash: {error: "Cannot perform this operation. The deployment is not in rollout stage."}
    end
  end

  def set_staged_rollout
    @staged_rollout = @deployment_run.staged_rollout
  end

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:deployment_run_id])
  end

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end
end
