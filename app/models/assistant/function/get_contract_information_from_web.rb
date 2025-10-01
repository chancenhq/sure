require "json"
require "net/http"
require "nokogiri"
require "openssl"
require "uri"

class Assistant::Function::GetContractInformationFromWeb < Assistant::Function
  ARTICLE_URL = "https://chancen.international/how-an-income-share-agreement-can-improve-access-to-quality-education-for-sub-saharan-africa/"
  VECTOR_STORE_ID = "vs_68dc734e717c8191b62f3b7062e9b8a0"
  FILE_SEARCH_MODEL = "gpt-4.1-mini"

  class << self
    def name
      "get_contract_information_from_web"
    end

    def description
      <<~DESC
        Use this to answer questions about CHANCEN International's Income Share Agreement (ISA) model for Sub-Saharan Africa.
        Provide the user's question in the `question` parameter and the function will return the most relevant sections of the
        source article so that you can cite and reference them in your response.
      DESC
    end
  end

  def params_schema
    build_schema(
      required: [ "question" ],
      properties: {
        "question" => {
          type: "string",
          description: "The question the user asked about the CHANCEN International ISA program"
        }
      }
    )
  end

  def call(params = {})
    question = params.fetch("question")

    file_search_sections = run_file_search(question)

    if file_search_sections.present?
      relevant_sections = file_search_sections
      all_sections = file_search_sections
      retrieval_strategy = "file_search"
    elsif false # TODO: uncomment this when we have a working way to fetch the article HTML
      all_sections = extract_sections(fetch_article_html)
      relevant_sections = select_relevant_sections(question, all_sections)
      retrieval_strategy = "http_fallback"
    else
      relevant_sections = []
      all_sections = []
      retrieval_strategy = "none"
    end

    {
      source_url: ARTICLE_URL,
      retrieved_at: Time.current.iso8601,
      question: question,
      sections: relevant_sections.map { |section| serialize_section(section) },
      metadata: {
        total_sections: all_sections.size,
        matched_sections: relevant_sections.size,
        retrieval_strategy: retrieval_strategy,
        vector_store_id: (VECTOR_STORE_ID if retrieval_strategy == "file_search")
      }.compact
    }
  end

  private
    Section = Struct.new(:heading, :content, :source, keyword_init: true) do
      def text
        Array(content).join(" ")
      end
    end

    def run_file_search(question)
      client = openai_client
      return [] unless client

      response = client.responses.create(parameters: file_search_parameters(question))
      Rails.logger.warn("OpenAI file search response: #{response.to_json}")
      parse_file_search_response(response)
    rescue ::OpenAI::Error, Faraday::Error => error
      Rails.logger.warn("OpenAI file search failed: #{error.message}")
      []
    rescue JSON::ParserError => error
      Rails.logger.warn("Failed to parse OpenAI file search response: #{error.message}")
      []
    end

    def file_search_parameters(question)
      {
        model: FILE_SEARCH_MODEL,
        temperature: 0,
        max_output_tokens: 600,
        input: [
          {
            role: "system",
            content: [
              {
                type: "text",
                text: "You retrieve authoritative details about CHANCEN International's Income Share Agreement for Sub-Saharan Africa. Use the provided tools to cite the most relevant excerpts and return them as structured data."
              }
            ]
          },
          {
            role: "user",
            content: [
              {
                type: "text",
                text: <<~PROMPT.squish
                  Question: #{question}

                  Provide up to five concise sections that directly answer the question using only the CHANCEN International ISA article.
                  For each section include a short heading and an array of sentences that can be cited in the final response.
                PROMPT
              }
            ]
          }
        ],
        tools: [
          { type: "file_search" }
        ],
        tool_resources: {
          file_search: {
            vector_store_ids: [ VECTOR_STORE_ID ]
          }
        },
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "contract_sections",
            schema: {
              type: "object",
              required: [ "sections" ],
              properties: {
                sections: {
                  type: "array",
                  maxItems: 5,
                  items: {
                    type: "object",
                    required: [ "heading", "content" ],
                    properties: {
                      heading: { type: "string" },
                      content: {
                        type: "array",
                        items: { type: "string" },
                        minItems: 1
                      },
                      source: { type: "string", nullable: true }
                    }
                  }
                }
              }
            }
          }
        }
      }
    end

    def parse_file_search_response(response)
      output = Array(response["output"]).find { |item| item["type"] == "output_text" }
      return [] unless output

      text_content = Array(output["content"]).find { |item| item["type"] == "text" }
      return [] unless text_content

      payload = JSON.parse(text_content["text"])
      sections = Array(payload["sections"]).filter_map do |section|
        heading = section["heading"].to_s.strip
        content = Array(section["content"]).map { |entry| entry.to_s.strip }.reject(&:blank?)
        source = section["source"].presence

        next if heading.blank? || content.empty?

        Section.new(heading: heading, content: content, source: source)
      end

      sections
    end

    def openai_client
      access_token = openai_access_token
      return if access_token.blank?

      @openai_client ||= ::OpenAI::Client.new(access_token: access_token)
    end

    def openai_access_token
      ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token.presence
    end

    def fetch_article_html
      uri = URI.parse(ARTICLE_URL)

      response = with_retries do
        http_response = perform_http_get(uri)
        raise RetryableHTTPError.new(http_response) if retryable_status?(http_response)

        http_response
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise StandardError, "Failed to retrieve article (status: #{response.code})"
      end

      response.body
    end

    def perform_http_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      if http.use_ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.cert_store = build_cert_store
      end

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "SureAssistant/1.0"

      http.request(request)
    end

    def with_retries(max_attempts: 3, base_delay: 0.5)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue RetryableHTTPError => error
        raise StandardError, "Failed to retrieve article (status: #{error.response.code})" if attempts >= max_attempts

        sleep(base_delay * attempts)
        retry
      rescue OpenSSL::SSL::SSLError, Timeout::Error, Errno::ECONNRESET, SocketError => error
        raise error if attempts >= max_attempts

        sleep(base_delay * attempts)
        retry
      end
    end

    def retryable_status?(response)
      response.code.to_i >= 500 && response.code.to_i < 600
    end

    def build_cert_store
      OpenSSL::X509::Store.new.tap(&:set_default_paths)
    rescue OpenSSL::X509::StoreError
      OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE || OpenSSL::X509::Store.new
    end

    class RetryableHTTPError < StandardError
      attr_reader :response

      def initialize(response)
        super("HTTP #{response.code}")
        @response = response
      end
    end

    def extract_sections(html)
      document = Nokogiri::HTML.parse(html)
      document.css("script, style, nav, header, footer, form").remove

      container = document.at_css("article") || document.at_css("main") || document.at_css("body")

      sections = []
      current_section = Section.new(heading: "Overview", content: [])

      container.css("h1, h2, h3, p, li").each do |node|
        text = node.text.squish
        next if text.blank?

        case node.name
        when "h1", "h2", "h3"
          sections << current_section if current_section.content.present?
          current_section = Section.new(heading: text, content: [])
        else
          current_section.content << text
        end
      end

      sections << current_section if current_section.content.present?
      sections
    end

    def select_relevant_sections(question, sections)
      return sections if question.blank?

      tokens = question.downcase.scan(/[a-z0-9']+/)
      return sections if tokens.empty?

      ranked = sections.map do |section|
        score = tokens.sum do |token|
          section.text.downcase.scan(token).size
        end
        [ section, score ]
      end

      ranked.sort_by! { |(_, score)| -score }
      filtered = ranked.take(5).select { |(_, score)| score.positive? }.map(&:first)
      filtered = sections.first(5) if filtered.empty?
      filtered
    end

    def serialize_section(section)
      {
        heading: section.heading,
        content: section.content,
        source: section.source
      }.compact
    end
end
