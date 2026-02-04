require "rails_helper"

describe BackmergeCherryPickInstructionsComponent, type: :component do
  let(:app) { create(:app, :android) }
  let(:train) { create(:train, app:, branching_strategy: :almost_trunk, backmerge_strategy: :continuous) }
  let(:release) { create(:release, train:) }
  let(:commit) do
    create(:commit, release:, commit_hash: "abc123def456789", message: "Fix bug")
  end

  describe "#render?" do
    context "when backmerge_failure is false" do
      it "returns false" do
        commit.update(backmerge_failure: false)
        component = described_class.new(commit)
        expect(component.render?).to be(false)
      end
    end

    context "when backmerge_failure is true" do
      before { commit.update(backmerge_failure: true) }

      context "when using almost_trunk branching strategy with continuous backmerge" do
        it "returns true" do
          component = described_class.new(commit)
          expect(component.render?).to be(true)
        end
      end

      context "when not using almost_trunk branching strategy" do
        before { train.update(branching_strategy: :release_backmerge) }

        it "returns false" do
          component = described_class.new(commit)
          expect(component.render?).to be(false)
        end
      end

      context "when backmerge strategy is not continuous" do
        before { train.update(backmerge_strategy: :on_finalize) }

        it "returns false" do
          component = described_class.new(commit)
          expect(component.render?).to be(false)
        end
      end
    end
  end

  describe "#working_branch" do
    it "returns the train's working branch" do
      train.update(working_branch: "main")
      component = described_class.new(commit)
      expect(component.working_branch).to eq("main")
    end
  end

  describe "#release_branch" do
    it "returns the release's branch name" do
      release.update(branch_name: "release/1.0.0")
      component = described_class.new(commit)
      expect(component.release_branch).to eq("release/1.0.0")
    end
  end

  describe "#short_sha" do
    it "returns the first 7 characters of the commit hash" do
      component = described_class.new(commit)
      expect(component.short_sha).to eq("abc123d")
    end
  end

  describe "#instructions" do
    let(:component) { described_class.new(commit) }

    it "returns array of 4 git commands" do
      expect(component.instructions.length).to eq(4)
    end

    it "includes git fetch command" do
      expect(component.instructions[0]).to eq("git fetch")
    end

    it "includes git checkout command with correct branch and working branch" do
      train.update(working_branch: "main")
      expect(component.instructions[1]).to eq("git checkout -b patch-abc123d main")
    end

    it "includes git cherry-pick command with short sha" do
      expect(component.instructions[2]).to eq("git cherry-pick abc123d")
    end

    it "includes git push command with patch branch" do
      expect(component.instructions[3]).to eq("git push -u origin patch-abc123d")
    end
  end

  describe "rendering" do
    context "when component renders" do
      before { commit.update(backmerge_failure: true) }

      it "renders the modal with correct title" do
        html = render_inline(described_class.new(commit)).to_html
        expect(html).to include("Cherry-Pick Commit to Working Branch")
      end

      it "renders the modal subtitle" do
        html = render_inline(described_class.new(commit)).to_html
        expect(html).to include("Follow these steps to manually cherry-pick this commit")
      end

      it "displays commit details" do
        html = render_inline(described_class.new(commit)).to_html
        expect(html).to include(commit.short_sha)
        expect(html).to include(release.branch_name)
        expect(html).to include(train.working_branch)
      end

      it "renders all 4 instruction steps" do
        html = render_inline(described_class.new(commit)).to_html
        expect(html).to include("git fetch")
        expect(html).to include("git checkout -b patch-#{commit.short_sha} #{train.working_branch}")
        expect(html).to include("git cherry-pick #{commit.short_sha}")
        expect(html).to include("git push -u origin patch-#{commit.short_sha}")
      end

      it "renders the note about merge conflicts" do
        html = render_inline(described_class.new(commit)).to_html
        expect(html).to include("If cherry-pick fails due to conflicts")
        expect(html).to include("git cherry-pick --continue")
      end

      it "renders copy buttons for each command" do
        html = render_inline(described_class.new(commit)).to_html
        # Each SmartTextBoxComponent renders a clipboard button with data-action
        # The data-action contains "clipboard#copy" among other actions
        expect(html.scan(/data-action="[^"]*clipboard#copy[^"]*"/).count).to eq(4)
      end
    end

    context "when component doesn't render" do
      before { commit.update(backmerge_failure: false) }

      it "renders nothing" do
        html = render_inline(described_class.new(commit)).to_html
        expect(html.strip).to be_empty
      end
    end
  end
end
