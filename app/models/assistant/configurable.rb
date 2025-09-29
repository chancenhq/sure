module Assistant::Configurable
  extend ActiveSupport::Concern

  DEFAULT_PROMPT_TEMPLATE = <<~PROMPT.freeze
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
    - Format dates in the user's preferred format: {{preferred_date_format}}

    #### User's preferred currency

    Sure is a multi-currency app where each user has a "preferred currency" setting.

    When no currency is specified, use the user's preferred currency for formatting and displaying monetary values.

    - Symbol: {{preferred_currency_symbol}}
    - ISO code: {{preferred_currency_iso_code}}
    - Default precision: {{preferred_currency_default_precision}}
    - Default format: {{preferred_currency_default_format}}
      - Separator: {{preferred_currency_separator}}
      - Delimiter: {{preferred_currency_delimiter}}

    ### Rules about financial advice

    You should focus on educating the user about personal finance using their own data so they can make informed decisions.

    - Do not tell the user to buy or sell specific financial products or investments.
    - Do not make assumptions about the user's financial situation. Use the functions available to get the data you need.

    ### Function calling rules

    - Use the functions available to you to get user financial data and enhance your responses
    - For functions that require dates, use the current date as your reference point: {{current_date}}
    - If you suspect that you do not have enough data to 100% accurately answer, be transparent about it and state exactly what
      the data you're presenting represents and what context it is in (i.e. date range, account, etc.)
  PROMPT

  PROMPT_TOKENS = {
    "{{preferred_currency_symbol}}" => :preferred_currency_symbol,
    "{{preferred_currency_iso_code}}" => :preferred_currency_iso_code,
    "{{preferred_currency_default_precision}}" => :preferred_currency_default_precision,
    "{{preferred_currency_default_format}}" => :preferred_currency_default_format,
    "{{preferred_currency_separator}}" => :preferred_currency_separator,
    "{{preferred_currency_delimiter}}" => :preferred_currency_delimiter,
    "{{preferred_date_format}}" => :preferred_date_format,
    "{{current_date}}" => :current_date
  }.freeze

  class_methods do
    def config_for(chat)
      preferred_currency = Money::Currency.new(chat.user.family.currency)
      preferred_date_format = chat.user.family.date_format

      {
        instructions: final_instructions(preferred_currency, preferred_date_format),
        functions: default_functions
      }
    end

    private
      def default_functions
        [
          Assistant::Function::GetTransactions,
          Assistant::Function::GetAccounts,
          Assistant::Function::GetBalanceSheet,
          Assistant::Function::GetIncomeStatement
        ]
      end

      def final_instructions(preferred_currency, preferred_date_format)
        template = Setting.assistant_system_prompt_template.presence || DEFAULT_PROMPT_TEMPLATE
        format_instructions(template, preferred_currency, preferred_date_format)
      end

      def format_instructions(template, preferred_currency, preferred_date_format)
        replacements = {
          "{{preferred_currency_symbol}}" => preferred_currency.symbol,
          "{{preferred_currency_iso_code}}" => preferred_currency.iso_code,
          "{{preferred_currency_default_precision}}" => preferred_currency.default_precision,
          "{{preferred_currency_default_format}}" => preferred_currency.default_format,
          "{{preferred_currency_separator}}" => preferred_currency.separator,
          "{{preferred_currency_delimiter}}" => preferred_currency.delimiter,
          "{{preferred_date_format}}" => preferred_date_format,
          "{{current_date}}" => Date.current
        }

        replacements.reduce(template) do |result, (token, value)|
          result.gsub(token, value.to_s)
        end
      end
  end
end
