FactoryBot.define do
  factory :build_artifact do
    step_run
    generated_at { Time.current }
    file { Rack::Test::UploadedFile.new("spec/fixtures/storage/test_artifact.aab.zip", "application/zip") }
  end
end
