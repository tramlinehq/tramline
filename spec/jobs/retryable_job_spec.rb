# frozen_string_literal: true

require "rails_helper"

TestError = Class.new(StandardError)
MAX_RETRY_COUNT = 5

class TestJob < ApplicationJob
  include RetryableJob

  cattr_accessor :exhausted_called, default: false
  cattr_accessor :last_exhausted_error
  cattr_accessor :last_exhausted_args

  enduring_retry_on TestError, max_attempts: MAX_RETRY_COUNT, backoff: {period: :minutes, type: :static, factor: 1}

  def perform_work(_)
    raise TestError
  end

  def retries_exhausted(error, args)
    self.class.exhausted_called = true
    self.class.last_exhausted_error = error
    self.class.last_exhausted_args = args
  end
end

RSpec.describe RetryableJob do
  after do
    TestJob.jobs.clear
    TestJob.exhausted_called = false
    TestJob.last_exhausted_error = nil
    TestJob.last_exhausted_args = nil
  end

  it "retries with correct metadata" do
    TestJob.perform_async("test")

    # Process the job to trigger the retry
    perform_one_job

    # Verify the retry job was enqueued with correct metadata
    expect(TestJob.jobs.size).to eq(1)
    retried_job = TestJob.jobs.first
    expect(retried_job["args"].last).to eq(
      "_retry_meta" => {
        "attempt" => 2,
        "original_error" => "TestError"
      }
    )
  end

  it "retries up to max_attempts" do
    TestJob.perform_async("test")

    # Simulate processing all retries
    MAX_RETRY_COUNT.times do |i|
      expect(TestJob.jobs.size).to eq(1), "Expected job to be retried on attempt #{i + 1}, got #{TestJob.jobs.size}"
      perform_one_job
    end

    # Verify no more retries after max attempts
    expect(TestJob.jobs.size).to eq(0)
  end

  it "calls retries_exhausted when max attempts are reached" do
    args = ["test_arg"]
    TestJob.perform_async(*args)

    # Process all retries
    MAX_RETRY_COUNT.times do
      perform_one_job
    end

    expect(TestJob.exhausted_called).to be true
    expect(TestJob.last_exhausted_error).to be_a(TestError)
    expect(TestJob.last_exhausted_args).to eq(args)
  end
end

def perform_one_job
  job = TestJob.jobs.first
  raise "No jobs in queue" unless job
  TestJob.jobs.shift
  TestJob.process_job(job)
rescue TestError
  # Allow the job to fail so we can test retries
end
