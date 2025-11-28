require "webmock/rspec"

def stub_vertex_ai_gemini_api(project_id, prompt, parsed_response, response_type = "text")
  body = {
    contents: [
      {
        role: "user",
        parts: [
          {text: prompt}
        ]
      }
    ]
  }

  if response_type == "json"
    body[:generationConfig] = {
      responseMimeType: "application/json"
    }
  end

  stub_request(
    :post,
    "https://us-central1-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent"
  ).with(
    headers: {
      "Authorization" => "Bearer dummy-token",
      "Content-Type" => "application/json"
    },
    body: body
  ).to_return(
    status: 200,
    body: parsed_response.to_json,
    headers: {"Content-Type" => "application/json"}
  )
end

def stub_google_service_account_auth
  auth_client = instance_double(Google::Auth::ServiceAccountCredentials)
  allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(auth_client)
  allow(auth_client).to receive(:fetch_access_token!).and_return({"access_token" => "dummy-token"})
end

def stub_vertex_ai_llama_api(project_id, prompt, parsed_response, response_type = "text")
  stub_request(:post, "https://us-east5-aiplatform.googleapis.com/v1/projects/#{project_id}/locations/us-east5/endpoints/openapi/chat/completions")
    .with(
      headers: {
        "Authorization" => "Bearer dummy-token",
        "Content-Type" => "application/json"
      },
      body: {
        model: "meta/llama-4-maverick-17b-128e-instruct-maas",
        stream: false,
        messages: [{role: "user", content: prompt}]
      }

    )
    .to_return(
      status: 200,
      body: parsed_response.to_json,
      headers: {"Content-Type" => "application/json"}
    )
end
