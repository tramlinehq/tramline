# frozen_string_literal: true

require "rails_helper"

describe StoreRollout do
  describe "#next_rollout_percentage" do
    test_cases = [
      # [config, current_stage, expected_result]
      [[10.0], nil, 10.0],
      [[10.0], 0, nil],
      [[10.0, 20.0], nil, 10.0],
      [[10.0, 20.0], 0, 20.0],
      [[10.0, 20.0], 1, nil],
      [[10.0, 20.0, 30.0], nil, 10.0],
      [[10.0, 20.0, 30.0], 0, 20.0],
      [[10.0, 20.0, 30.0], 1, 30.0],
      [[10.0, 20.0, 30.0], 2, nil],
      [[10.0, 20.0, 30.0, 40.0, 50.0], nil, 10.0],
      [[10.0, 20.0, 30.0, 40.0, 50.0], 1, 30.0],
      [[10.0, 20.0, 30.0, 40.0, 50.0], 3, 50.0],
      [[10.0, 20.0, 30.0, 40.0, 50.0], 4, nil],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], nil, 10.0],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], 4, 60.0],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], 8, 100.0],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], 9, nil]
    ]

    test_cases.each do |config, current_stage, expected|
      context "with config size #{config.size}" do
        context "when current_stage is #{current_stage.nil? ? "nil" : current_stage}" do
          let(:rollout) do
            create(:store_rollout, :play_store,
              config: config,
              current_stage: current_stage)
          end

          if expected.nil?
            it "returns nil (reached last stage)" do
              expect(rollout.next_rollout_percentage).to be_nil
            end
          else
            it "returns #{expected}" do
              expect(rollout.next_rollout_percentage).to eq(expected)
            end
          end
        end
      end
    end
  end

  describe "#reached_last_stage?" do
    test_cases = [
      # [config, current_stage, expected_result]
      [[10.0], nil, false],
      [[10.0], 0, true],
      [[10.0, 20.0], nil, false],
      [[10.0, 20.0], 0, false],
      [[10.0, 20.0], 1, true],
      [[10.0, 20.0, 30.0], nil, false],
      [[10.0, 20.0, 30.0], 0, false],
      [[10.0, 20.0, 30.0], 1, false],
      [[10.0, 20.0, 30.0], 2, true],
      [[10.0, 20.0, 30.0, 40.0, 50.0], nil, false],
      [[10.0, 20.0, 30.0, 40.0, 50.0], 1, false],
      [[10.0, 20.0, 30.0, 40.0, 50.0], 3, false],
      [[10.0, 20.0, 30.0, 40.0, 50.0], 4, true],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], nil, false],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], 4, false],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], 8, false],
      [[10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0], 9, true]
    ]

    test_cases.each do |config, current_stage, expected|
      context "with config size #{config.size}" do
        context "when current_stage is #{current_stage.nil? ? "nil" : current_stage}" do
          let(:rollout) do
            create(:store_rollout, :play_store,
              config: config,
              current_stage: current_stage)
          end

          it "returns #{expected}" do
            expect(rollout.reached_last_stage?).to be expected
          end
        end
      end
    end

    it "returns true when config is empty and current_stage is nil" do
      rollout = create(:store_rollout, :play_store, config: [], current_stage: nil)
      expect(rollout.reached_last_stage?).to be true
    end

    it "returns true when current_stage exceeds config size" do
      rollout = create(:store_rollout, :play_store, config: [10, 20], current_stage: 5)
      expect(rollout.reached_last_stage?).to be true
    end
  end
end
