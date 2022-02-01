class Integrations::Slack::Api
  attr_reader :installation_scopes, :installation_state, :oauth_access_token

  PUBLISH_CHAT_MESSAGE_URL = "https://slack.com/api/chat.postMessage"
  LIST_CHANNELS_URL = "https://slack.com/api/conversations.list"
  LIST_CHANNELS_LIMIT = 200

  def initialize(oauth_access_token)
    @oauth_access_token = oauth_access_token
  end

  class << self
    OAUTH_V2ACCESS_TOKEN_URL = "https://slack.com/api/oauth.v2.access"

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

    def creds
      Rails.application.credentials
    end
  end

  def message(channel, text)
    json_params = {
      json: {
        channel:,
        text:
      }
    }

    HTTP
      .auth("Bearer #{oauth_access_token}")
      .get(PUBLISH_CHAT_MESSAGE_URL, json_params)
  end

  def list_channels
    params = {
      params: {
        limit: LIST_CHANNELS_LIMIT,
        exclude_archived: false,
        types: "public_channel,private_channel"
      }
    }

    HTTP
      .auth("Bearer #{oauth_access_token}")
      .get(LIST_CHANNELS_URL, params)
      .then { |response| response.body.to_s }
      .then { |body| JSON.parse(body) }
      .then { |json| json["channels"] }
      .then { |channels| channels.map { |list| list.slice("id", "name") } }
  end

  def search_channels(q)
    list_channels.then { |channels| channels.select { |list| list["name"] =~ Regexp.new(q) } }
  end

  private

  def creds
    Rails.application.credentials
  end
end
