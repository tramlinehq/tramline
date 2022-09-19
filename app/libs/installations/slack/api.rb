module Installations
  class Slack::Api
    include Vaultable
    attr_reader :installation_scopes, :installation_state, :oauth_access_token

    PUBLISH_CHAT_MESSAGE_URL = "https://slack.com/api/chat.postMessage"
    LIST_CHANNELS_URL = "https://slack.com/api/conversations.list"
    LIST_CHANNELS_LIMIT = 200

    def initialize(oauth_access_token)
      @oauth_access_token = oauth_access_token
    end

    class << self
      include Vaultable

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
    end

    def message(channel, text)
      json_params = {
        json: {
          channel: channel,
          text: text
        }
      }

      HTTP
        .auth("Bearer #{oauth_access_token}")
        .post(PUBLISH_CHAT_MESSAGE_URL, json_params)
    end

    def rich_message(channel, text, block)
      json_params = {
        json: {
          channel: channel,
          text: text
        }.merge(block)
      }

      HTTP
        .auth("Bearer #{oauth_access_token}")
        .post(PUBLISH_CHAT_MESSAGE_URL, json_params)
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
        .then { |responses| Installations::Response::Keys.normalize(responses) }
    end
  end
end
