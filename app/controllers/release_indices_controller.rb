class ReleaseIndicesController < SignedInApplicationController
  using RefinedString

  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :set_tab_configuration, only: %i[edit update]

  def edit
    @release_index = @train.release_index
  end

  def update
    @release_index = @train.release_index

    if @release_index.update(parsed_params)
      redirect_to edit_app_train_release_index_path(@app, @train), notice: t(".success")
    else
      redirect_to edit_app_train_release_index_path(@app, @train), flash: {error: t(".failure", errors: @release_index.errors.full_messages.to_sentence)}
    end
  end

  private

  def set_train
    @train = Train.friendly.find(params[:train_id])
  end

  def set_app_from_train
    @app = @train.app
  end

  def set_tab_configuration
    @tab_configuration = [
      [1, "Release Settings", edit_app_train_path(@app, @train), "v2/cog.svg"],
      [2, "Submissions Settings", submission_config_edit_app_train_path(@app, @train), "v2/route.svg"],
      [3, "Notification Settings", app_train_notification_settings_path(@app, @train), "bell.svg"],
      [4, "Release Health Rules", rules_app_train_path(@app, @train), "v2/heart_pulse.svg"],
      [5, "Reldex Settings", edit_app_train_release_index_path(@app, @train), "v2/ruler.svg"]
    ].compact
  end

  def release_index_params
    params
      .require(:release_index)
      .permit(:tolerable_min,
        :tolerable_max,
        release_index_components_attributes: [:tolerable_min, :tolerable_max, :weight_percentage, :id])
  end

  def parsed_params
    release_index_params
      .merge(tolerable_range: release_index_params[:tolerable_min].safe_float..release_index_params[:tolerable_max].safe_float)
      .merge(release_index_components_attributes: parsed_component_params)
  end

  def parsed_component_params
    release_index_params[:release_index_components_attributes].each do |_idx, component|
      component
        .merge!(tolerable_range: component[:tolerable_min].safe_float..component[:tolerable_max].safe_float,
          weight: component[:weight_percentage].safe_float / 100.0)
    end
  end
end
