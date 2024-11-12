# == Schema Information
#
# Table name: crashlytics_integrations
#
#  id             :uuid             not null, primary key
#  code           :string
#  json_key       :string
#  project_number :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class CrashlyticsIntegration < ApplicationRecord
	has_paper_trail

	include Providable
	include Displayable

	delegate :cache, to: Rails
	delegate :integrable, to: :integration
	delegate :crashlytics_project, to: :app_config
	alias_method :project, :crashlytics_project

	API = Installations::Crashlytics::Api
	CACHE_EXPIRY = 1.month

	APPS_TRANSFORMATIONS = {
	  app_id: :app_id,
	  display_name: :display_name,
	  platform: :platform
	}

	RELEASE_TRANSFORMATIONS = {
	  new_errors_count: :errors_introduced_count,
	  errors_count: :errors_seen_count,
	  sessions_in_last_day: :sessions_count_in_last_24h,
	  sessions: :total_sessions_count,
	  sessions_with_errors: :unhandled_sessions_count,
	  daily_users_with_errors: :accumulative_daily_users_with_unhandled,
	  daily_users: :accumulative_daily_users_seen,
	  total_sessions_in_last_day: :total_sessions_count_in_last_24h,
	  external_release_id: :release_group_id
	}

	validate :correct_key, on: :create

	def access_key
	  StringIO.new(json_key)
	end

	def installation
	  API.new(project_number, access_key)
	end

	def to_s
	  "crashlytics"
	end

	def creatable?
	  true
	end

	def connectable?
	  false
	end

	def store?
	  false
	end

	def further_setup?
	  true
	end

	def connection_data
		"Project: #{project_number}"
	end

	def setup
	  android = list_apps(platform: "android")
	  ios = list_apps(platform: "ios")

	  case integrable.platform
	  when "android" then {android: android}
	  when "ios" then {ios: ios}
	  when "cross_platform" then {ios: ios, android: android}
	  else
	    raise ArgumentError, "Invalid platform"
	  end
	end

	def list_apps(platform:)
	  apps = cache.fetch(list_apps_cache_key, expires_in: CACHE_EXPIRY) do
	    installation.list_apps(APPS_TRANSFORMATIONS)
	  end

	  apps.select { |app| app[:platform] == platform }.map { |app| app.slice(:app_id, :display_name) }
	end

	def metadata
		{}
	end

	def find_release(platform, version, build_number)
	  installation.find_release(project(platform), version, build_number, RELEASE_TRANSFORMATIONS)
	end

	private

	def app_config
	  integration.app.config
	end

	def correct_key
	  installation.list_apps(APPS_TRANSFORMATIONS).present?
	rescue RuntimeError
	  errors.add(:json_key, :key_format)
	rescue Installations::Google::Firebase::Error => ex
	  errors.add(:json_key, ex.reason)
	end

	def list_apps_cache_key
	  "google_firebase_integration/#{id}/list_apps"
	end
end
