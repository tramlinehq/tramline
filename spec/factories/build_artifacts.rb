FactoryBot.define do
  factory :build_artifact do
    transient do
      organization { create(:organization) }
    end

    build do
      app = create(:app, organization: organization)
      release_platform_run = create(:release_platform_run, app: app)
      create(:build, release_platform_run: release_platform_run)
    end

    generated_at { Time.current }
    file { Rack::Test::UploadedFile.new("spec/fixtures/storage/test_artifact.aab.zip", "application/zip") }
  end
end
