module JsonKeyProvidable
  extend ActiveSupport::Concern

  private

  def providable_params
    super.merge(json_key: json_key_file.read)
  end

  def providable_params_errors
    @providable_params_errors ||= Validators::KeyFileValidator.validate(json_key_file).errors
  end

  def json_key_file
    @json_key_file ||= integration_params[:providable][:json_key_file]
  end
end
