require "rails_helper"

describe Artifacts::Stream do
  def zip_with(entries, extension = ".zip")
    Tempfile.new(["artifact", extension]).tap do |file|
      Zip::OutputStream.open(file.path) do |zip|
        entries.each do |name, body|
          zip.put_next_entry(name)
          zip.write(body)
        end
      end
    end
  end

  def opened(stream)
    results = []
    stream.with_open { |io| results << {ext: io.ext, body: File.binread(io.file.path)} }
    results
  end

  it "extracts the build inside an archive" do
    archive = zip_with("app-release.aab" => "aab-bytes")

    expect(opened(described_class.new(archive, is_archive: true))).to eq([{ext: ".aab", body: "aab-bytes"}])
  end

  it "extracts only the entry matching the filter pattern" do
    archive = zip_with("app-debug.apk" => "debug", "app-release.apk" => "release")

    expect(opened(described_class.new(archive, is_archive: true, filter_pattern: "release"))).to eq([{ext: ".apk", body: "release"}])
  end

  it "refuses archives with several builds and no filter" do
    archive = zip_with("app-debug.apk" => "debug", "app-release.apk" => "release")

    expect { opened(described_class.new(archive, is_archive: true)) }.to raise_error(described_class::SingleUnzipSupportedOnly)
  end

  it "ignores entries nested in directories, including traversal paths" do
    archive = zip_with("app-release.aab" => "aab-bytes", "../escaped.apk" => "evil", "nested/other.apk" => "nested")

    expect(opened(described_class.new(archive, is_archive: true))).to eq([{ext: ".aab", body: "aab-bytes"}])
  end

  it "detects an aab from its contents when the file has no extension" do
    bundle = zip_with({"base/manifest/AndroidManifest.xml" => "manifest", "BundleConfig.pb" => "config"}, "")

    expect(opened(described_class.new(bundle)).pluck(:ext)).to eq([".aab"])
  end
end
