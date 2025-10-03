class Assistant::Function::GetInfoFromFileSearch < Assistant::Function
  class << self
    def name
      "get_info_from_file_search"
    end

    def description
      <<~DESCRIPTION
        Use this function to search the partner-provided knowledge base for authoritative answers.

        Provide a concise question or instruction in the `query` parameter and the model will return a
        grounded answer using the documents stored in the partner's vector store.
      DESCRIPTION
    end
  end

  def params_schema
    build_schema(
      required: [ "query" ],
      properties: {
        query: {
          type: "string",
          description: "Question or instruction to run against the partner's file search knowledge base"
        }
      }
    )
  end

  def call(params = {})
    ensure_vector_store_ids!
    ensure_access_token!

    query = params["query"].to_s.strip
    raise ArgumentError, "Query must be provided" if query.blank?

    client = openai_client.beta(responses: "v1", assistants: "v2")

    request = {
      model: default_model,
      input: [
        { role: "user", content: [ { type: "input_text", text: query } ] }
      ],
      tools: [ { type: "file_search", vector_store_ids: vector_store_ids } ]
    }

    Rails.logger.warn("OpenAI function call request: #{request.to_json}")

    response = client.responses.create(
      parameters: request
    )

    parse_response(response)
  rescue => e
    Rails.logger.warn("OpenAI function call failed: #{e.message}")
    Rails.logger.warn("OpenAI function call failed, response: #{e.response.dig(:body)}") if e.respond_to?(:response)
    raise e
  end

  private
    def ensure_vector_store_ids!
      if vector_store_ids.blank?
        raise ArgumentError, "No vector store IDs configured for this partner"
      end
    end

    def ensure_access_token!
      raise ArgumentError, "OpenAI access token is not configured" if openai_access_token.blank?
    end

    def parse_response(response)
      output_items = Array(response["output"])

      answer_chunks = []
      citations = []

      output_items.each do |item|
        next unless item["type"] == "message"

        Array(item["content"]).each do |content|
          text = content["text"] || content["refusal"]
          answer_chunks << text if text.present?

          Array(content["annotations"]).each do |annotation|
            citation = annotation["file_citation"]
            next if citation.blank?

            citations << {
              file_id: citation["file_id"],
              quote: annotation["quote"],
              start_index: annotation["start_index"],
              end_index: annotation["end_index"]
            }.compact
          end
        end
      end

      {
        response_id: response["id"],
        model: response["model"],
        answer: answer_chunks.join("\n").strip,
        citations: citations,
        usage: response["usage"]
      }
    end

    def vector_store_ids
      @vector_store_ids ||= begin
        ids = user.partner_metadata.fetch("vector_store_id_array", [])

        if ids.blank? && user.partner_key.present?
          partner_defaults = Partners.find(user.partner_key)&.default_metadata
          ids = partner_defaults.fetch("vector_store_id_array", []) if partner_defaults
        end

        Array(ids).compact_blank
      end
    end

    def default_model
      Provider::Openai::MODELS.first
    end

    def openai_access_token
      ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token.presence
    end

    def openai_client
      @openai_client ||= ::OpenAI::Client.new(access_token: openai_access_token)
    end
end
