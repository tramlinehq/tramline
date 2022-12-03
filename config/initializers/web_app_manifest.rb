Rails.application.config.assets.configure do |env|
  env.register_mime_type("application/manifest+json", extensions: [".webmanifest", ".webmanifest.erb"])
  env.register_mime_type("application/xml", extensions: [".xml", ".xml.erb"])
  env.register_preprocessor("application/xml", Sprockets::ERBProcessor)
end
