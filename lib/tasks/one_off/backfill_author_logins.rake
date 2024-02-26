namespace :one_off do
  desc "Backfill author logins for commits in a release"
  task :backfill_author_logins, %i[release_id] => [:destructive, :environment] do |_, args|
    release_id = args[:release_id].to_s
    _release = Release.find(release_id)
    OneOff::BackfillAuthorLogins.perform_later(release_id)
  end
end
