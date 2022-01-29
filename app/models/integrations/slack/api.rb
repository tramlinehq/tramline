class Integrations::Slack::Api
  attr_reader :installation_scopes, :installation_state

  OAUTH_V2ACCESS_TOKEN_URL = "https://slack.com/api/oauth.v2.access"
  PUBLISH_CHAT_MESSAGE_URL = "https://slack.com/api/chat.postMessage"

  def initialize
  end

  def oauth_access_token(code)
    form_params = {
      form: {
        client_id: creds.integrations.slack.client_id,
        client_secret: creds.integrations.slack.client_secret,
        code:
      }
    }

    HTTP
      .post(OAUTH_V2ACCESS_TOKEN_URL, form_params)
      .then { |response| response.body.to_s }
      .then { |body| JSON.parse(body) }
      .then { |json| json["access_token"] }
  end

  def message(token, channel, text)
    json_params = {
      json: {
        channel:,
        text:
      }
    }

    HTTP
      .auth("Bearer #{token}")
      .post(PUBLISH_CHAT_MESSAGE_URL, json_params)
  end

  private

  def creds
    Rails.application.credentials
  end
end
