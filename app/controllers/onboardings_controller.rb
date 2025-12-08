class OnboardingsController < SignedInApplicationController
  before_action :set_app
  before_action :set_onboarding_state
  before_action :set_step

  # Main onboarding view
  def show
    render :show
  end

  # Version configuration step
  def version
    @step = 0
    render :show
  end

  # Branching configuration step
  def branching
    @step = 1
    render :show
  end

  # Tags configuration step
  def tags
    @step = 2
    render :show
  end

  # Workflows configuration step
  def workflows
    @step = 3
    render :show
  end

  # Cycle features configuration step
  def cycle_features
    @step = 4
    render :show
  end

  # Submissions configuration step
  def submissions
    @step = 5
    render :show
  end

  # Save the version configuration
  def save_version
    @step = 0

    if @onboarding_state.update(version_params)
      @onboarding_state.complete_step("version")

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "onboarding_step_#{@step}",
            partial: "version_form",
            locals: {app: @app, onboarding_state: @onboarding_state}
          )
        }
        format.html { redirect_to branching_app_onboarding_path(@app) }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "onboarding_step_#{@step}",
            partial: "version_form",
            locals: {app: @app, onboarding_state: @onboarding_state}
          ), status: :unprocessable_entity
        }
        format.html { render :show }
      end
    end
  end

  # Save the branching configuration
  def save_branching
    @step = 1

    if @onboarding_state.update(branching_params)
      @onboarding_state.complete_step("branching")

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "onboarding_step_#{@step}",
            partial: "branching_form",
            locals: {app: @app, onboarding_state: @onboarding_state}
          )
        }
        format.html { redirect_to tags_app_onboarding_path(@app) }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "onboarding_step_#{@step}",
            partial: "branching_form",
            locals: {app: @app, onboarding_state: @onboarding_state}
          ), status: :unprocessable_entity
        }
        format.html { render :show }
      end
    end
  end

  # Save the tags configuration
  def save_tags
    if @onboarding_state.update(tags_params)
      @onboarding_state.complete_step("tags")
      redirect_to app_onboarding_workflows_path(@app)
    else
      @step = 2
      render :show
    end
  end

  # Save the workflows configuration
  def save_workflows
    if @onboarding_state.update(workflows_params)
      @onboarding_state.complete_step("workflows")
      redirect_to app_onboarding_cycle_features_path(@app)
    else
      @step = 3
      render :show
    end
  end

  # Save the cycle features configuration
  def save_cycle_features
    if @onboarding_state.update(cycle_features_params)
      @onboarding_state.complete_step("cycle_features")
      redirect_to app_onboarding_submissions_path(@app)
    else
      @step = 4
      render :show
    end
  end

  # Save the submissions configuration
  def save_submissions
    if @onboarding_state.update(submissions_params)
      @onboarding_state.complete_step("submissions")
      redirect_to complete_app_onboarding_path(@app)
    else
      @step = 5
      render :show
    end
  end

  # Complete the onboarding process and create the train/release platform
  def complete
    if @onboarding_state.ready_for_completion?
      converter = OnboardingToTrainConverter.new(@onboarding_state)

      if converter.convert!
        respond_to do |format|
          format.turbo_stream {
            render turbo_stream: [
              turbo_stream.replace(
                "onboarding_wizard",
                partial: "completion",
                locals: {app: @app}
              ),
              turbo_stream.prepend(
                "flash_messages",
                partial: "shared/flash",
                locals: {type: "success", message: "Onboarding complete! Your release train has been created."}
              )
            ]
          }
          format.html {
            redirect_to app_trains_path(@app), notice: "Onboarding complete! Your release train has been created."
          }
        end
      else
        respond_to do |format|
          format.turbo_stream {
            render turbo_stream: turbo_stream.prepend(
              "flash_messages",
              partial: "shared/flash",
              locals: {type: "error", message: "There was an error creating your release train. Please try again."}
            )
          }
          format.html {
            redirect_to app_onboarding_path(@app), alert: "There was an error creating your release train. Please try again."
          }
        end
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.prepend(
            "flash_messages",
            partial: "shared/flash",
            locals: {type: "error", message: "Please complete all steps before finishing onboarding."}
          )
        }
        format.html {
          redirect_to app_onboarding_path(@app), alert: "Please complete all steps before finishing onboarding."
        }
      end
    end
  end

  private

  def set_onboarding_state
    @onboarding_state = OnboardingState.find_or_create_by(app: @app)
  end

  def set_step
    @step = params[:step].present? ? params[:step].to_i : 0
  end

  def version_params
    params.require(:onboarding_state).permit(
      :version_strategy,
      :minor_version_bump_strategy,
      :patch_version_bump_strategy,
      :build_version_strategy
    )
  end

  def branching_params
    params.require(:onboarding_state).permit(
      :branching_strategy,
      :branch_naming_format,
      :source_branch,
      :release_branch_format
    )
  end

  def tags_params
    params.require(:onboarding_state).permit(
      :tagging_enabled,
      :tag_format,
      :tag_all_releases
    )
  end

  def workflows_params
    params.require(:onboarding_state).permit(
      :ci_cd_workflow,
      :ci_cd_provider,
      :ci_cd_workflow_path,
      :ci_cd_branch_pattern
    )
  end

  def cycle_features_params
    params.require(:onboarding_state).permit(
      :auto_deployment,
      :auto_increment_version,
      :copy_changelog
    )
  end

  def submissions_params
    params.require(:onboarding_state).permit(
      :rc_submission_enabled,
      :rc_submission_provider,
      :rc_submission_config,
      :production_submission_enabled,
      :production_submission_provider,
      :production_submission_config
    )
  end
end
