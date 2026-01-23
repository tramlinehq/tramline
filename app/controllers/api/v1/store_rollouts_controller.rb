class Api::V1::StoreRolloutsController < ApiController
  Action = Coordinators::Actions

  def increase
    rollout = find_android_rollout
    raise ActiveRecord::RecordNotFound if rollout.blank?

    result = Action.increase_the_store_rollout!(rollout)

    if result.ok?
      render json: rollout_response(rollout.reload), status: :ok
    else
      render json: {error: result.error.message}, status: :unprocessable_entity
    end
  end

  private

  def find_android_rollout
    release = find_release
    return nil if release.blank?

    android_run = release.android_release_platform_run
    return nil if android_run.blank?

    android_run.inflight_store_rollout
  end

  def find_release
    authorized_organization
      .releases
      .where(branch_name: release_param)
      .or(authorized_organization.releases.where(id: release_param))
      .or(authorized_organization.releases.where(slug: release_param))
      .joins(train: :app)
      .where(apps: {slug: app_param})
      .first
  end

  def rollout_response(rollout)
    {
      rollout: rollout.release_info.merge(
        id: rollout.id,
        status: rollout.status,
        current_stage: rollout.stage,
        next_rollout_percentage: rollout.next_rollout_percentage,
        is_staged_rollout: rollout.staged_rollout?
      )
    }
  end

  def app_param
    params.require(:app_id)
  end

  def release_param
    params.require(:release_id)
  end
end
