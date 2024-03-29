module Installations
  class Slack::Api
    include Vaultable
    attr_reader :installation_scopes, :installation_state, :oauth_access_token

    PUBLISH_CHAT_MESSAGE_URL = "https://slack.com/api/chat.postMessage"
    LIST_CHANNELS_URL = "https://slack.com/api/conversations.list"
    GET_TEAM_URL = "https://slack.com/api/team.info"
    START_FILE_UPLOAD_URL = "https://slack.com/api/files.getUploadURLExternal"
    COMPLETE_FILE_UPLOAD_URL = "https://slack.com/api/files.completeUploadExternal"
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

    def message(channel, text, thread_id: nil)
      json_params = {
        json: {
          channel: channel,
          text: text,
          unfurl_links: false,
          thread_ts: thread_id
        }
      }

      execute(:post, PUBLISH_CHAT_MESSAGE_URL, json_params)
    end

    def rich_message(channel, text, block)
      json_params = {
        json: {
          channel: channel,
          text: text,
          unfurl_links: false
        }.merge(block)
      }

      execute(:post, PUBLISH_CHAT_MESSAGE_URL, json_params)
    end

    def rich_message_with_attachment(channel, text, block, attachment, attachment_title, attachment_name)
      start_upload_params = {
        params: {
          filename: attachment_name,
          length: attachment.size
        }
      }
      upload_response = execute(:get, START_FILE_UPLOAD_URL, start_upload_params)

      upload_params = {
        form: {
          file: HTTP::FormData::File.new(attachment)
        }
      }
      resp = HTTP.post(upload_response["upload_url"], upload_params)
      raise unless resp.status.success?

      msg = rich_message(channel, text, block)
      thread_ts = msg.dig("message", "ts")
      complete_upload_params = {
        json: {
          files: [{id: upload_response["file_id"], title: attachment_title}],
          channel_id: channel,
          thread_ts:
        }
      }
      execute(:post, COMPLETE_FILE_UPLOAD_URL, complete_upload_params)
    end

    def list_channels(transforms, cursor = nil)
      params = {
        params: {
          limit: LIST_CHANNELS_LIMIT,
          exclude_archived: true,
          types: "public_channel,private_channel",
          cursor:
        }
      }

      execute(:get, LIST_CHANNELS_URL, params)
        .then { |response| response.slice("channels", "response_metadata") }
        .then { |responses|
          {channels: Installations::Response::Keys.transform(responses["channels"], transforms),
           next_cursor: responses.dig("response_metadata", "next_cursor")}
        }
    end

    def team_info(transforms)
      execute(:get, GET_TEAM_URL, {})
        .then { |response| response&.fetch("team", nil) }
        .then { |team| Installations::Response::Keys.transform([team], transforms) }
        .first
    end

    private

    def execute(verb, url, params, headers = {})
      response = HTTP.auth("Bearer #{oauth_access_token}").headers(headers).public_send(verb, url, params)
      JSON.parse(response.body.to_s)
    end
  end
end
