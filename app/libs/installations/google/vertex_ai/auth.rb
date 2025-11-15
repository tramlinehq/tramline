module Installations
  module Google::VertexAi::Auth
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = "https://www.googleapis.com/auth/cloud-platform"

    def access_token
      auth_client.fetch_access_token!["access_token"]
    end

    def auth_client
      key_file.rewind
      SERVICE_ACCOUNT.make_creds(json_key_io: key_file, scope: SCOPE)
    end
  end
end
