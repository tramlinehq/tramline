# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalApp do
  describe "#active_locales" do
    context "when android" do
      let(:production_track) {
        {
          "name" => "production",
          "releases" => [
            {
              "status" => "inProgress",
              "build_number" => "3",
              "localizations" => [
                {
                  "text" => "This latest version includes bugfixes for the android platform.",
                  "language" => "en-US"
                },
                {
                  "text" => "À la mode, les élèves sont bien à l'aise.",
                  "language" => "fr-FR"
                }
              ],
              "user_fraction" => 0.01,
              "version_string" => "1.10.0"
            },
            {
              "status" => "completed",
              "build_number" => "2",
              "localizations" => [
                {
                  "text" => "The latest version contains bug fixes and performance improvements.",
                  "language" => "en-US"
                },
                {
                  "text" => "something else in French",
                  "language" => "fr-FR"
                }
              ],
              "user_fraction" => nil,
              "version_string" => "1.20.0"
            }
          ]
        }
      }
      let(:beta_track) {
        {
          "name" => "beta",
          "releases" => [
            {
              "status" => "completed",
              "build_number" => "1",
              "localizations" => [
                {
                  "text" => "• Update README.md\n• new RC build\n• new and improved RC",
                  "language" => "en-AU"
                },
                {
                  "text" => "• Update README.md\n• new RC build\n• new and improved RC",
                  "language" => "en-US"
                }
              ],
              "user_fraction" => nil,
              "version_string" => "1.10.0"
            }
          ]
        }
      }
      let(:channel_data) {
        [
          beta_track,
          production_track
        ]
      }
      let(:external_app) { create(:external_app, :android, channel_data:) }

      it "returns all the locales for the latest production track in store" do
        result = external_app.active_locales
        expect(result.size).to eq(2)
        expect(result.map(&:locale)).to contain_exactly("en-US", "fr-FR")
        expect(result.map(&:release_notes)).to contain_exactly("This latest version includes bugfixes for the android platform.",
          "À la mode, les élèves sont bien à l'aise.")
      end

      it "return empty array if no locales are found for the latest production track in store" do
        external_app.update! channel_data: [beta_track]
        expect(external_app.active_locales).to be_empty
      end
    end

    context "when ios" do
      let(:test_track) {
        {name: "Alpha Group",
         releases: [
           {id: "8573c263-1d1b-45c6-92e3-418c17d8a17a",
            status: "BETA_APPROVED",
            build_number: "471281165",
            release_date: "2024-10-16T03:35:40-07:00",
            localizations: nil,
            version_string: "10.39.0"},
           {id: "c493a681-7b2a-4556-ba54-ac3b6b8e17d9",
            status: "BETA_APPROVED",
            build_number: "471281164",
            release_date: "2024-10-16T03:30:39-07:00",
            localizations: nil,
            version_string: "10.38.0"}
         ]}
      }
      let(:production_track) {
        {name: "production",
         releases: [
           {id: "62cdd0b0-19aa-4389-bd4b-4789ccf833f8",
            status: "READY_FOR_SALE",
            build_number: "471281164",
            release_date: "2024-10-15T23:44:11-07:00",
            localizations: [
              {keywords: "japanese, aural, subway",
               language: "hi",
               whats_new: "नवीनतम संस्करण में बग फिक्स और प्रदर्शन सुधार शामिल हैं।",
               promo_text: nil,
               description: "A true aural experience of the Yamanote line in Tokyo."},
              {keywords: "japanese, aural, subway",
               language: "en-US",
               whats_new: "The latest version contains bug fixes and performance improvements.",
               promo_text: nil,
               description: "A true aural experience of the Yamanote line in Tokyo."},
              {keywords: "japanese, aural, subway",
               language: "ja",
               whats_new: "最新バージョンにはバグ修正とパフォーマンスの改善が含まれています",
               promo_text: nil,
               description: "A true aural experience of the Yamanote line in Tokyo."}
            ],
            version_string: "10.38.0"}
         ]}
      }

      let(:channel_data) {
        [
          test_track,
          production_track
        ]
      }
      let(:external_app) { create(:external_app, :ios, channel_data:) }

      it "returns all the locales for the latest production track in store" do
        result = external_app.active_locales
        expect(result.size).to eq(3)
        expect(result.map(&:locale)).to contain_exactly("en-US", "hi", "ja")
        expect(result.map(&:release_notes)).to contain_exactly("The latest version contains bug fixes and performance improvements.",
          "नवीनतम संस्करण में बग फिक्स और प्रदर्शन सुधार शामिल हैं।",
          "最新バージョンにはバグ修正とパフォーマンスの改善が含まれています")
      end

      it "return empty array if no locales are found for the latest production track in store" do
        external_app.update! channel_data: [test_track]
        expect(external_app.active_locales).to be_empty
      end
    end
  end
end
