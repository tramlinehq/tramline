require "webmock/rspec"

def stub_posthog_api
  stub_request(:post, %r{https://.*\.i\.posthog\.com/.*})
    .with(
      headers: {
        "Accept" => "*/*",
        "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
        "Content-Type" => "application/json",
        "User-Agent" => /posthog-ruby/
      }
    )
    .to_return(
      status: 200,
      body: '{"status": "ok"}',
      headers: {"Content-Type" => "application/json"}
    )
end
