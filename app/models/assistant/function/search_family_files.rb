class Assistant::Function::SearchFamilyFiles < Assistant::Function
  class << self
    def name
      "search_family_files"
    end

    def description
      <<~DESCRIPTION
        Use this function to retrieve official information from Chancen
        International's ISA contract and policy documents stored in the partner
        vector store.

        Always call this tool whenever a student asks about Chancen, Income Share
        Agreements (ISAs), or ISA-related concepts, even if they do not say 'Chancen'
        or 'ISA'. ISA-related concepts include: repayment amounts/percentages,
        monthly contributions, when payments start/stop, repayment period, minimum
        income threshold, maximum repayment amount/cap, early/lump-sum settlement,
        pauses/exemptions (e.g., job loss), required proofs/documents, treatment of
        self-employed or business income, household income rules, service/administration
        fees (e.g., ~KES 300 + annual adjustment), commitment fees (e.g., ~KES 500 per term)
        and late commitment fees (e.g., ~KES 500 per week), late payment penalties,
        drop-out/withdrawal fees (e.g., ~KES 5,000), transaction/processing charges
        (bank/mobile money), events of default, recovery/CRB actions, guardians' obligations,
        travel/moving abroad, information requirements (KRA/NSSF, employer details),
        payment methods (standing order, mobile money), termination/settlement, data sharing,
        dispute resolution, and governing law. Do not use this tool for general budgeting
        or financial-literacy questions.
      DESCRIPTION
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "query" ],
      properties: {
        query: {
          type: "string",
          description: "The search query to find relevant information in the family's uploaded documents"
        },
        max_results: {
          type: "integer",
          description: "Maximum number of results to return (default: 10, max: 20)"
        }
      }
    )
  end

  def call(params = {})
    query = params["query"]
    max_results = (params["max_results"] || 10).to_i.clamp(1, 20)

    unless family.vector_store_id.present?
      return {
        success: false,
        error: "no_documents",
        message: "No documents have been uploaded to the family document store yet."
      }
    end

    adapter = VectorStore.adapter

    unless adapter
      return {
        success: false,
        error: "provider_not_configured",
        message: "No vector store is configured. Set VECTOR_STORE_PROVIDER or configure OpenAI."
      }
    end

    response = adapter.search(
      store_id: family.vector_store_id,
      query: query,
      max_results: max_results
    )

    unless response.success?
      return {
        success: false,
        error: "search_failed",
        message: "Failed to search documents: #{response.error&.message}"
      }
    end

    results = response.data

    if results.empty?
      return {
        success: true,
        results: [],
        message: "No matching documents found for the query."
      }
    end

    {
      success: true,
      query: query,
      result_count: results.size,
      results: results.map do |result|
        {
          content: result[:content],
          filename: result[:filename],
          score: result[:score]
        }
      end
    }
  rescue => e
    Rails.logger.error("SearchFamilyFiles error: #{e.class.name} - #{e.message}")
    {
      success: false,
      error: "search_failed",
      message: "An error occurred while searching documents: #{e.message.truncate(200)}"
    }
  end
end
