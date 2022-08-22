require "rails_helper"

describe Services::PostRelease::ParallelBranches do
  let(:release) { FactoryBot.create(:releases_train_run, branch_name: "production") }

  it ".call" do
    repo_integration = instance_double(Installations::Github::Api)
    allow_any_instance_of(described_class).to receive(:repo_integration).and_return(repo_integration)
    allow(repo_integration).to receive(:create_pr!).and_return({number: 1})
    allow(repo_integration).to receive(:merge_pr!)
    allow(Automatons::Tag).to receive(:dispatch!)

    described_class.call(release)
    expect(release.status).to be_eql("finished")
    expect(Automatons::Tag).to have_received(:dispatch!).with(train: release.train, branch: "production")
    expect(repo_integration).to have_received(:create_pr!).with(nil,
      "dev",
      nil,
      "[Release kickoff] 1.1.1",
      "New release train train triggered.\nThe dev branch has been merged into production branch, as per Release with Backmerge branching strategy.\n")
    expect(repo_integration).to have_received(:merge_pr!).with(any_args)
  end
end
