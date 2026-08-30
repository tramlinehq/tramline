# == Schema Information
#
# Table name: slack_integrations
#
#  id                          :uuid             not null, primary key
#  oauth_access_token          :string
#  original_oauth_access_token :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
class SlackIntegration < ApplicationRecord
  has_paper_trail
  encrypts :oauth_access_token, deterministic: true

  using RefinedString
  include Vaultable
  include Providable
  include Displayable
  include Loggable
  include Rails.application.routes.url_helpers

  delegate :integrable, to: :integration
  delegate :cache, to: Rails

  attr_accessor :code

  before_create :complete_access
  after_create_commit :fetch_channels

  Notifier = Notifiers::Slack

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

  CREATE_CHANNEL_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    is_private: :is_private
  }

  CHANNELS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    description: [:purpose, :value],
    is_private: :is_private,
    member_count: :num_members
  }

  TEAM_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    domain: :domain,
    email_domain: :email_domain,
    icon: [:icon, :image_34],
    enterprise_id: :enterprise_id,
    enterprise_name: :enterprise_name
  }

  DEPLOY_MESSAGE = "A wild new release has appeared!"
  CACHE_EXPIRY = 1.month
  CODE_SNIPPET_CHARACTER_LIMIT = 3500
  MAX_RETRY_ATTEMPTS = 3
  RETRYABLE_ERRORS = ["name_taken"]

  # Paginating conversations.list for big workspaces (some have 10k+ channels,
  # i.e. 50+ pages at 200/page). conversations.list is a Slack Tier-2 method
  # (~20 req/min), so a sustained page walk trips its rate limit. We throttle
  # between pages and escalate the delay the deeper we go.
  CHANNELS_PAGE_SLEEP = 1.second                # base delay between fetched pages
  CHANNELS_PAGE_SLEEP_BACKOFF_EVERY = 15        # every N fetched pages, escalate
  CHANNELS_PAGE_SLEEP_BACKOFF_FACTOR = 2        # ...by this factor
  CHANNELS_PAGE_SLEEP_MAX = 30.seconds          # ...but never sleep longer than this
  # Hard ceiling on the walk so a giant (or pathologically paginating) workspace
  # can't run the job for hours — stop after ~15k channels (75 pages at 200/page,
  # the api's LIST_CHANNELS_LIMIT). At this cap a full walk is ~8 min of throttle
  # sleeps; the CHANNELS_PAGE_SLEEP_MAX ceiling keeps it bounded if raised.
  CHANNELS_MAX_PAGES = 75
  # Progress is published to the full-list key as the walk grows, so the UI shows
  # a partial list instead of nothing on a workspace too big to paginate in one
  # cycle. Short TTL so a stalled walk's truncated list can't shadow the real set
  # for long — a completed walk overwrites it at CACHE_EXPIRY.
  CHANNELS_PARTIAL_CACHE_EXPIRY = 10.minutes
  # The synchronous web read (#channels) paginates at most this many pages inline
  # to stay responsive, then parks the remainder on the background job (which
  # walks the whole workspace fresh). Small workspaces finish within this budget
  # and never spawn a job.
  CHANNELS_SYNC_PAGE_LIMIT = 3

  def controllable_rollout?
    false
  end

  def further_setup?
    false
  end

  def install_path
    unless integration.notification? || integration.build_channel?
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end

    BASE_INSTALLATION_URL
      .expand(params: {
        client_id: creds.integrations.slack.client_id,
        redirect_uri: redirect_uri,
        scope: creds.integrations.slack.scopes,
        state: integration.installation_state
      }).to_s
  end

  def complete_access
    return if oauth_access_token.present?
    self.oauth_access_token = Installations::Slack::Api.oauth_access_token(code)
  end

  def installation
    Installations::Slack::Api.new(oauth_access_token)
  end

  def metadata
    installation.team_info(TEAM_TRANSFORMATIONS)
  end

  def connection_data
    return unless integration.metadata
    "Workspace: #{integration.metadata["name"]} (#{integration.metadata["domain"]})"
  end

  # SlackIntegration: after_commit
  def fetch_channels
    RefreshSlackChannelsJob.perform_async(id)
  end

  def populate_channels!
    cache.write(channels_cache_key, get_all_channels, expires_in: CACHE_EXPIRY)
  end

  def channels
    cached = cache.read(channels_cache_key)
    return sliced_channels(cached) unless cached.nil?

    # Cold cache: paginate a bounded prefix inline so the request stays responsive
    # on huge workspaces (some have 50+ pages), then hand the remainder to the
    # background job, which walks the whole workspace fresh and finalizes the full
    # list at CACHE_EXPIRY. A small workspace finishes within the budget and needs
    # no job. The bounded prefix we just fetched is re-fetched by the job (a few
    # redundant calls) — cheap, and it keeps every walk on live cursors.
    list, complete = walk_channels(max_pages: CHANNELS_SYNC_PAGE_LIMIT)
    if complete
      cache.write(channels_cache_key, list, expires_in: CACHE_EXPIRY)
    else
      fetch_channels
    end
    sliced_channels(list)
  rescue Installations::Error => e
    # A walk can fail midway on huge workspaces (Slack rate limits). walk_channels
    # publishes progress to the cache as it paginates, so surface whatever pages we
    # did fetch rather than nothing, and park a job to walk it fresh. The partial
    # carries only a short TTL so it can't shadow the real set for long, and the
    # train's configured channel is kept selectable regardless
    # (TrainsController#ensure_current_channel_in_options).
    elog(e, level: :warn)
    fetch_channels
    sliced_channels(cache.read(channels_cache_key) || [])
  end

  def sliced_channels(list)
    list.map { |c| c.slice(:id, :name, :is_private) }
  end

  def channels_cache_key
    "app/#{integrable.id}/slack_integration/#{id}/channels"
  end

  def notify!(channel, message, type, params, file_id = nil, file_title = nil)
    response = installation.rich_message(channel, message, notifier(type, params), file_id, file_title)
    return if response.blank?
    response.dig("message", "ts")
  rescue => e
    Rails.logger.error("Error sending message to Slack: #{e.message}")
    elog(e, level: :debug)
  end

  def notify_with_snippet!(channel, message, type, params, snippet_content, snippet_title)
    thread_id = notify!(channel, message, type, params)
    return unless thread_id

    messages = snippet_content.break_into_chunks(CODE_SNIPPET_CHARACTER_LIMIT)
    messages.each_with_index.map do |msg, idx|
      msg = "```#{msg}```"
      msg.prepend("*#{snippet_title}*\n\n") if idx == 0
      installation.message(channel, msg, thread_id:)
    end
  rescue => e
    elog(e, level: :warn)
  end

  # renders the changelog exclusively in a thread
  def notify_changelog!(channel, message, thread_id, changelog, existing_params, header_affix: nil, continuation: false)
    return if changelog.blank?

    params = existing_params.merge({changes: changelog, header_affix:, continuation:})
    payload = notifier(:changelog, params)

    installation.message(channel, message, block: payload, thread_id:)
  rescue => e
    elog(e, level: :debug)
  end

  # renders the primary notification and then threads a changelog as necessary
  def notify_with_threaded_changelog!(channel, message, type, params, changelog_key:, changelog_partitions:, header_affix:)
    changelog = params[changelog_key]
    return if changelog.blank?

    changelog_parts = changelog.in_groups_of(changelog_partitions, false)
    params[:changelog] = {first_part: changelog_parts[0], total_parts: changelog_parts.size, header_affix:}

    # send the initial part of the notification
    thread_id = notify!(channel["id"], message, type, params)
    return unless thread_id

    # thread the changelog if necessary
    if changelog_parts.size > 1
      changelog_parts[1..].each.with_index(2) do |change_group, index|
        continuation_header_affix = "#{header_affix} (#{index}/#{changelog_parts.size})"
        notify_changelog!(channel["id"], message, thread_id, change_group, params,
          header_affix: continuation_header_affix,
          continuation: true)
      end
    end

    thread_id
  end

  def upload_file!(file, file_name)
    installation.upload_file(file, file_name)
  rescue => e
    elog(e, level: :warn)
  end

  def create_channel!(name)
    execute_with_retry do |attempt|
      channel_name = name
      channel_name = [name, attempt].join("_") if attempt > 0
      installation.create_channel(CREATE_CHANNEL_TRANSFORMATIONS, channel_name)
    end
  end

  def notifier(type, params)
    params[:changelog_linker] = nil
    params[:changelog_linker] = Notifier::Changelogs::Linker.new(integrable) if params[:enable_changelog_linking]
    Notifier::Builder.build(type, **params)
  end

  def to_s
    "slack"
  end

  def creatable?
    false
  end

  def connectable?
    true
  end

  def store?
    false
  end

  def further_build_channel_setup?
    false
  end

  def public_icon_img
    nil
  end

  def project_link
    nil
  end

  def deep_link(_, _)
    nil
  end

  def channel_deep_link(channel_id)
    "slack://channel?team=#{integration.metadata["id"]}&id=#{channel_id}"
  end

  private

  def execute_with_retry(attempt: 0, &)
    yield(attempt)
  rescue Installations::Error => ex
    elog(ex, level: :warn)
    return if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if RETRYABLE_ERRORS.include?(ex.reason)
      execute_with_retry(attempt: next_attempt, &)
    end
  rescue => ex
    elog(ex, level: :warn)
  end

  # Paginate every page of conversations.list (used by the background job).
  def get_all_channels
    walk_channels.first
  end

  # Walk conversations.list iteratively (not recursively — a 50+ page workspace
  # would otherwise build a deep call stack), up to max_pages pages (nil = no
  # bound). Returns [channels, complete] where complete is true only when the
  # cursor was exhausted (the whole workspace paginated). Always fetches live —
  # we deliberately don't cache pages by cursor: a Slack pagination cursor isn't
  # reliably valid minutes later, so a "resumed" walk risks stitching a stale
  # snapshot, and a re-walk from scratch is both simpler and always current.
  # Bounded walks are the synchronous web path, so they don't throttle — the bulk
  # (throttled) pagination is the job's unbounded walk.
  def walk_channels(max_pages: nil)
    channels = []
    cursor = nil
    sleep_duration = CHANNELS_PAGE_SLEEP
    pages = 0
    # The caller's inline budget, but never past the hard ceiling.
    page_cap = [max_pages, CHANNELS_MAX_PAGES].compact.min

    loop do
      page = installation.list_channels(CHANNELS_TRANSFORMATIONS, cursor)
      channels.concat(page[:channels])
      cursor = page[:next_cursor]
      pages += 1
      return [channels, true] if cursor.blank?

      # Publish progress so the UI shows a growing list mid-walk instead of nothing
      # until a 50+ page workspace is fully paginated. Short TTL (see the constant):
      # a stalled walk must not leave a truncated list shadowing the real set. The
      # complete list is written by the caller (#channels / #populate_channels!) at
      # CACHE_EXPIRY once the walk finishes, overwriting this.
      cache.write(channels_cache_key, channels, expires_in: CHANNELS_PARTIAL_CACHE_EXPIRY)

      # Stop at the budget: the web prefix hands the rest to the job; the job stops
      # at the hard ceiling (truncating a huge workspace) so it can't run for hours.
      if pages >= page_cap
        if pages >= CHANNELS_MAX_PAGES
          Rails.logger.warn("SlackIntegration##{id}: channel walk hit the #{CHANNELS_MAX_PAGES}-page (~15k) cap; list truncated")
        end
        return [channels, false]
      end

      # Throttle only the unbounded (job) walk; the bounded web prefix is a few
      # calls and stays responsive. Escalate the delay but cap it so total runtime
      # stays bounded.
      if (pages % CHANNELS_PAGE_SLEEP_BACKOFF_EVERY).zero?
        sleep_duration = [sleep_duration * CHANNELS_PAGE_SLEEP_BACKOFF_FACTOR, CHANNELS_PAGE_SLEEP_MAX].min
      end
      sleep(sleep_duration) if max_pages.nil?
    end
  end

  def redirect_uri
    if Rails.env.development?
      slack_callback_url(host: ENV["HOST_NAME"], port: "3000", protocol: "https")
    else
      slack_callback_url(host: ENV["HOST_NAME"], protocol: "https")
    end
  end
end
