class WebhookHandlers::Github::Push
  Response = Struct.new(:status, :body)

  def self.process(payload)
    new(payload).process
  end

  def process
    Response.new(status: :accepted)
    # TODO: filter commits from the branche(es) we care about
    # Run train steps from first to current to generate builds
  end
end
