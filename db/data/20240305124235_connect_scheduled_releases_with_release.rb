class ConnectScheduledReleasesWithRelease < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      # scan all automatic trains
      Train.where.not(kickoff_at: nil).where.not(repeat_duration: nil).each do |train|
        # check redundantly to be sure
        next unless train.automatic?

        # find last 10 scheduled releases
        last_10 = train.scheduled_releases.where("scheduled_at < ?", Time.current.beginning_of_day).order(scheduled_at: :asc).last(10)

        # skip if there are no scheduled releases
        next if last_10.blank?

        last_10.each do |scheduled_release|
          # find a release within a 10 minute window around the scheduled release schedule time
          target_date = scheduled_release.scheduled_at
          release = train.releases.where("scheduled_at >= ? AND scheduled_at <= ?", target_date - 10.minutes, target_date + 10.minutes).first

          # update the scheduled release if a release was found
          next if release.blank?
          scheduled_release.update!(release: release)
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
