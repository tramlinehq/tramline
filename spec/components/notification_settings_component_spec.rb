require "rails_helper"

describe NotificationSettingsComponent, type: :component do
  let(:train) { create(:train, :with_no_platforms, :without_notification_settings) }
  let(:kinds) { NotificationSetting.kinds.keys.first(3) }

  it "renders a status pill for every setting, including several in the same state" do
    create(:notification_setting, train:, kind: kinds[0])
    create(:notification_setting, train:, kind: kinds[1])
    create(:notification_setting, :inactive, train:, kind: kinds[2])
    allow(train).to receive(:send_notifications?).and_return(true)

    text = render_inline(described_class.new(train:, settings: train.notification_settings)).text

    expect(text.scan("Enabled").size).to eq(2)
    expect(text.scan("Disabled").size).to eq(1)
  end

  it "builds a new status pill on every call" do
    setting = create(:notification_setting, train:, kind: kinds[0])
    component = described_class::NotificationSettingComponent.new(train.app, train, setting)

    expect(component.status_pill).not_to equal(component.status_pill)
    expect(component.release_specific_status_pill).not_to equal(component.release_specific_status_pill)
  end
end
