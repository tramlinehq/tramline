class DownloadAppIconJob < ApplicationJob
  queue_as :default

  def perform(app_id, icon_url)
    app = App.find(app_id)
    return if icon_url.blank?

    begin
      # Download the icon from the URL
      response = HTTP.get(icon_url)

      Tempfile.create(["app_icon", File.extname(icon_url)]) do |downloaded_file|
        File.binwrite(downloaded_file.path, response.to_s)

        # Add content_type method that the validator expects
        downloaded_file.define_singleton_method(:content_type) do
          response.content_type.mime_type
        end

        validate_and_attach_icon(app, downloaded_file)
      end
    rescue => e
      Rails.logger.error "Failed to download icon for app #{app.id} from #{icon_url}: #{e.message}"
    end
  end

  private

  def validate_and_attach_icon(app, downloaded_file)
    validation = Validators::AppIconValidator.validate(downloaded_file)
    if validation.errors.any?
      Rails.logger.error "Icon validation failed for app #{app.id}: #{validation.errors.join(", ")}"
    else
      extension = extract_extension(downloaded_file)
      filename = "#{app.name}#{".#{extension}" if extension.present?}"

      app.icon.attach(
        io: downloaded_file,
        filename: filename,
        content_type: downloaded_file.content_type
      )

      Rails.logger.info "Successfully attached icon for app #{app.id}"
    end
  end

  def extract_extension(file)
    case file.content_type
    when "image/png"
      "png"
    when "image/jpeg", "image/jpg"
      "jpg"
    when "image/webp"
      "webp"
    end
  end
end
