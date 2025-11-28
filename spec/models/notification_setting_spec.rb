# frozen_string_literal: true

require "rails_helper"

describe NotificationSetting do
  let(:notification_provider) { instance_double(SlackIntegration) }

  before do
    allow_any_instance_of(described_class).to receive(:notification_provider).and_return(notification_provider)
    allow_any_instance_of(App).to receive(:notifications_set_up?).and_return(true)
  end

  it "has a valid factory" do
    expect(create(:notification_setting)).to be_valid
  end

  describe "#notify!" do
    before do
      allow(notification_provider).to receive(:notify!)
    end

    context "when notifications are not set up on the app" do
      let(:setting) { create(:notification_setting) }

      before do
        allow_any_instance_of(App).to receive(:notifications_set_up?).and_return(false)
      end

      it "does not send notification" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).not_to have_received(:notify!)
      end
    end

    context "when notification is not active" do
      let(:setting) { create(:notification_setting, :inactive) }

      it "does not send notification" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).not_to have_received(:notify!)
      end
    end

    context "when destination is not release specific channel" do
      let(:setting) { create(:notification_setting) }

      it "sends notification to default channels" do
        setting.notify!("Message", {param: "value"})

        setting.notification_channels.each do |channel|
          expect(notification_provider).to have_received(:notify!).with(channel["id"], any_args)
        end
      end
    end

    context "when destination is both release specific channel and default channel" do
      let(:setting) { create(:notification_setting, :release_specific) }

      it "sends notification to release specific channel" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).to have_received(:notify!).with(setting.release_specific_channel["id"], any_args)
      end

      it "sends notification to default channels" do
        setting.notify!("Message", {param: "value"})
        setting.notification_channels.each do |channel|
          expect(notification_provider).to have_received(:notify!).with(channel["id"], any_args)
        end
      end
    end

    context "when destination is only release specific channel" do
      let(:setting) { create(:notification_setting, :only_release_specific) }

      it "sends notification to release specific channel" do
        setting.notify!("Message", {param: "value"})
        expect(notification_provider).to have_received(:notify!).with(setting.release_specific_channel["id"], any_args)
      end

      it "does not send notification to default channels" do
        setting.notify!("Message", {param: "value"})
        setting.notification_channels.each do |channel|
          expect(notification_provider).not_to have_received(:notify!).with(channel["id"], any_args)
        end
      end
    end
  end

  describe "#notify_with_changelog!" do
    let(:thread_id) { Faker::Number.number(digits: 10).to_s }

    before do
      allow(notification_provider).to receive(:notify_with_threaded_changelog!).and_return(thread_id)
      allow(notification_provider).to receive(:notify_changelog!)
    end

    context "when kind does not need changelog" do
      let(:setting) { create(:notification_setting) }

      it "does not send notification" do
        setting.notify_with_changelog!("Message", {param: "value"})
        expect(notification_provider).not_to have_received(:notify_with_threaded_changelog!)
        expect(notification_provider).not_to have_received(:notify_changelog!)
      end
    end

    context "when kind is rc_finished" do
      let(:setting) { create(:notification_setting, kind: :rc_finished) }

      let(:notification_params) {
        {
          diff_changelog: Array.new(Random.rand(1..10)) { Faker::Lorem.sentence }
        }
      }

      context "when it is first pre-prod release" do
        let(:params) { notification_params.merge(first_pre_prod_release: true) }

        it "sends notification with threaded changelog" do
          setting.notify_with_changelog!("Some Message", params)
          expect(notification_provider).to have_received(:notify_with_threaded_changelog!)
            .with(
              setting.notification_channels.first,
              "Some Message",
              "rc_finished",
              params.merge(user_content: nil),
              changelog_key: :diff_changelog,
              changelog_partitions: 20,
              header_affix: "Changes in this build"
            )
        end
      end

      context "when it is not first pre-prod release" do
        let(:full_changelog) { Array.new(40) { Faker::Lorem.sentence } }
        let(:params) { notification_params.merge(first_pre_prod_release: false, full_changelog:) }

        it "sends the diff changelog" do
          setting.notify_with_changelog!("Some Message", params)
          expect(notification_provider).to have_received(:notify_with_threaded_changelog!)
            .with(
              setting.notification_channels.first,
              "Some Message",
              "rc_finished",
              params.merge(user_content: nil),
              changelog_key: :diff_changelog,
              changelog_partitions: 20,
              header_affix: "Changes in this build"
            )
        end

        it "sends full changelog in two parts" do
          setting.notify_with_changelog!("Some Message", params)

          expect(notification_provider).to have_received(:notify_changelog!)
            .with(
              setting.notification_channels.first["id"],
              "Some Message",
              thread_id,
              full_changelog.first(20),
              params.merge(user_content: nil),
              header_affix: "Full release changelog",
              continuation: false
            )

          expect(notification_provider).to have_received(:notify_changelog!)
            .with(
              setting.notification_channels.first["id"],
              "Some Message",
              thread_id,
              full_changelog.last(20),
              params.merge(user_content: nil),
              header_affix: "Full release changelog (2/2)",
              continuation: true
            )
        end
      end
    end

    context "when kind is production_rollout_started" do
      let(:setting) { create(:notification_setting, kind: :production_rollout_started) }

      let(:params) {
        {
          diff_changelog: Array.new(Random.rand(1..10)) { Faker::Lorem.sentence }
        }
      }

      it "sends notification with threaded changelog" do
        setting.notify_with_changelog!("Some Message", params)
        expect(notification_provider).to have_received(:notify_with_threaded_changelog!)
          .with(
            setting.notification_channels.first,
            "Some Message",
            "production_rollout_started",
            params.merge(user_content: nil),
            changelog_key: :diff_changelog,
            changelog_partitions: 20,
            header_affix: "Changes in release"
          )
      end
    end
  end

  describe "user_content validation" do
    it "allows valid alphanumeric and unicode content" do
      setting = build(:notification_setting, user_content: "Hello world! 🚀 Release v1.2.3")
      expect(setting).to be_valid
    end

    it "allows empty user content" do
      setting = build(:notification_setting, user_content: "")
      expect(setting).to be_valid
    end

    it "allows nil user content" do
      setting = build(:notification_setting, user_content: nil)
      expect(setting).to be_valid
    end

    it "normalizes user content by stripping whitespace" do
      setting = create(:notification_setting, user_content: "  content with spaces  ")
      expect(setting.user_content).to eq("content with spaces")
    end

    it "allows unicode characters and punctuation" do
      setting = build(:notification_setting, user_content: "Release notes: Bug fixes & improvements! 🎉")
      expect(setting).to be_valid
    end

    it "allows slack-friendly characters" do
      setting = build(:notification_setting, user_content: "Check out <#channel> and @user mentions")
      expect(setting).to be_valid
    end
  end

  describe "Slack notification rendering with user content" do
    let(:setting_with_content) { create(:notification_setting, :with_user_content) }
    let(:setting_without_content) { create(:notification_setting, user_content: nil) }

    it "includes user content when present" do
      # Test that user content is accessible
      expect(setting_with_content.user_content).to eq("Custom notification content from the team")
    end

    it "handles nil user content gracefully" do
      expect(setting_without_content.user_content).to be_nil
    end
  end
end
