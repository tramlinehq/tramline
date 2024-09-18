class UnreifiedStoreSubmissionPresenter < SimpleDelegator
  def self.build(parent_release_conf, parent_release, build)
    reified_submissions = parent_release.store_submissions
    release_platform_run = parent_release.release_platform_run
    parent_release_conf.submissions.filter_map do |submission_conf|
      unless reified_submission?(reified_submissions, submission_conf)
        new(submission_conf, parent_release, release_platform_run, build)
      end
    end
  end

  def self.reified_submission?(reified_submissions, submission_conf)
    reified_submissions.any? do |submission|
      submission.conf.number == submission_conf.number
    end
  end

  def initialize(conf, parent_release, release_platform_run, build)
    sequence_number = conf.number
    id = SecureRandom.uuid
    config = conf.as_json
    unreified_submission =
      conf.submission_class.new(id:, parent_release:, release_platform_run:, build:, sequence_number:, config:)
    super(unreified_submission)
  end

  def status
    "Not yet started"
  end
end
