class Accounts::Integrations::GooglePlayStoreController < Accounts::IntegrationsController
  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:json_key, :type]
      ).merge(current_user:)
  end

  def providable_params
    super.merge(json_key: attachment)
  end

  def attachment
    Services::Attachment.for_json(integration_params[:providable][:json_key])
  end
end
