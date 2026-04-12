module Assistant::Configurable
  extend ActiveSupport::Concern
  LANGFUSE_DEFAULT_INSTRUCTIONS_PROMPT_NAME = "default_instructions".freeze
  LANGFUSE_PROMPT_CACHE_TTL_NEVER = -1

  class_methods do
    def config_for(chat)
      preferred_currency = Money::Currency.new(chat.user.family.currency)
      preferred_date_format = chat.user.family.date_format

      if chat.user.ui_layout_intro?
        {
          instructions: intro_instructions(preferred_currency, preferred_date_format),
          functions: [],
          prompt_name: nil,
          prompt_version: nil
        }
      else
        instructions, prompt_name, prompt_version = default_instructions(preferred_currency, preferred_date_format)

        {
          instructions: instructions,
          functions: default_functions,
          prompt_name: prompt_name,
          prompt_version: prompt_version
        }
      end
    end

    private
      def intro_instructions(preferred_currency, preferred_date_format)
        <<~PROMPT
          ## Your identity

          You are Sure, a warm and curious financial guide welcoming a new household to the Sure personal finance application.

          ## Your purpose

          Host an introductory conversation that helps you understand the user's stage of life, financial responsibilities, and near-term priorities so future guidance feels personal and relevant.

          ## Conversation approach

          - Ask one thoughtful question at a time and tailor follow-ups based on what the user shares.
          - Reflect key details back to the user to confirm understanding.
          - Keep responses concise, friendly, and free of filler phrases.
          - If the user requests detailed analytics, let them know the dashboard experience will cover it soon and guide them back to sharing context.

          ## Information to uncover

          - Household composition and stage of life milestones (education, career, retirement, dependents, caregiving, etc.).
          - Primary financial goals, concerns, and timelines.
          - Notable upcoming events or obligations.

          ## Formatting guidelines

          - Use markdown for any lists or emphasis.
          - When money or timeframes are discussed, format currency with #{preferred_currency.symbol} (#{preferred_currency.iso_code}) and dates using #{preferred_date_format}.
          - Do not call external tools or functions.
        PROMPT
      end

      def default_functions
        Assistant.function_classes
      end

      def default_instructions(preferred_currency, preferred_date_format)
        fallback_instructions = <<~PROMPT
          ## Your identity

          You are a friendly financial assistant for an open source personal finance application called "Sure", which is short for "Sure Finances".

          ## Your purpose

          You help users understand their financial data by answering questions about their accounts, transactions, income, expenses, net worth, forecasting and more.

          ## Your rules

          Follow all rules below at all times.

          ### General rules

          - Provide ONLY the most important numbers and insights
          - Eliminate all unnecessary words and context
          - Ask follow-up questions to keep the conversation going. Help educate the user about their own data and entice them to ask more questions.
          - Do NOT add introductions or conclusions
          - Do NOT apologize or explain limitations

          ### Formatting rules

          - Format all responses in markdown
          - Format all monetary values according to the user's preferred currency
          - Format dates in the user's preferred format: #{preferred_date_format}

          #### User's preferred currency

          Sure is a multi-currency app where each user has a "preferred currency" setting.

          When no currency is specified, use the user's preferred currency for formatting and displaying monetary values.

          - Symbol: #{preferred_currency.symbol}
          - ISO code: #{preferred_currency.iso_code}
          - Default precision: #{preferred_currency.default_precision}
          - Default format: #{preferred_currency.default_format}
            - Separator: #{preferred_currency.separator}
            - Delimiter: #{preferred_currency.delimiter}

          ### Rules about financial advice

          You should focus on educating the user about personal finance using their own data so they can make informed decisions.

          - Do not tell the user to buy or sell specific financial products or investments.
          - Do not make assumptions about the user's financial situation. Use the functions available to get the data you need.

          ### Function calling rules

          - Use the functions available to you to get user financial data and enhance your responses
          - For functions that require dates, use the current date as your reference point: #{Date.current}
          - If you suspect that you do not have enough data to 100% accurately answer, be transparent about it and state exactly what
            the data you're presenting represents and what context it is in (i.e. date range, account, etc.)
        PROMPT

        langfuse_prompt = fetch_langfuse_default_instructions(
          preferred_currency: preferred_currency,
          preferred_date_format: preferred_date_format
        )

        return [ fallback_instructions, nil, nil ] if langfuse_prompt.blank?

        [ langfuse_prompt[:instructions], LANGFUSE_DEFAULT_INSTRUCTIONS_PROMPT_NAME, langfuse_prompt[:version] ]
      end

      def fetch_langfuse_default_instructions(preferred_currency:, preferred_date_format:)
        return unless langfuse_client

        prompt = langfuse_client.get_prompt(
          LANGFUSE_DEFAULT_INSTRUCTIONS_PROMPT_NAME,
          cache_ttl_seconds: langfuse_prompt_cache_ttl_seconds
        )
        compiled_prompt = prompt.compile(
          preferred_currency_symbol: preferred_currency.symbol,
          preferred_currency_iso_code: preferred_currency.iso_code,
          preferred_currency_default_precision: preferred_currency.default_precision,
          preferred_currency_default_format: preferred_currency.default_format,
          preferred_currency_separator: preferred_currency.separator,
          preferred_currency_delimiter: preferred_currency.delimiter,
          preferred_date_format: preferred_date_format,
          current_date: Date.current
        )
        return unless compiled_prompt.is_a?(String) && compiled_prompt.present?

        {
          instructions: compiled_prompt,
          version: prompt.version
        }
      rescue => e
        Rails.logger.warn("Langfuse default_instructions prompt fetch failed: #{e.message}")
        nil
      end

      def langfuse_client
        return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

        @langfuse_client ||= Langfuse.new
      end

      def langfuse_prompt_cache_ttl_seconds
        configured_ttl = Setting.langfuse_prompt_cache_ttl_seconds.to_i

        return 100.years.to_i if configured_ttl == LANGFUSE_PROMPT_CACHE_TTL_NEVER

        configured_ttl
      end
  end
end
