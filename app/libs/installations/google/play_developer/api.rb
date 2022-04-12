module Installations
  class Google::PlayDeveloper::Api
    attr_reader :apk_path, :package_name

    def initialize
      @apk_path = apk_path
      @package_name = package_name
    end

    def upload
      android_publisher = Androidpublisher::AndroidPublisherService.new
      android_publisher.authorization = user_credentials_for(Androidpublisher::AUTH_ANDROIDPUBLISHER)

      edit = android_publisher.insert_edit(package_name)
      android_publisher.upload_edit_apk(package_name, edit, upload_source: apk_path)
      android_publisher.commit_edit(package_name, edit.id)
    end

    def auth
      scopes = Androidpublisher::AUTH_ANDROIDPUBLISHER
      Google::Auth.get_application_default(scopes)
    end
  end
end
