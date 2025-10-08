module Assistant::Configurable
  extend ActiveSupport::Concern

  class_methods do
    def config_for(chat)
      preferred_currency = Money::Currency.new(chat.user.family.currency)
      preferred_date_format = chat.user.family.date_format

      instructions_config = default_instructions(preferred_currency, preferred_date_format)

      {
        instructions: instructions_config[:content],
        instructions_prompt: instructions_config[:prompt],
        functions: default_functions(chat)
      }
    end

    private
      def default_functions(chat)
        functions = [
          Assistant::Function::GetTransactions,
          Assistant::Function::GetAccounts,
          Assistant::Function::GetBalanceSheet,
          Assistant::Function::GetIncomeStatement
        ]

        if partner_vector_store_ids(chat.user).present?
          functions << Assistant::Function::GetInfoFromFileSearch
        end

        functions
      end

      def partner_vector_store_ids(user)
        partner_metadata_ids = Array(user.partner_metadata["vector_store_id_array"]).compact_blank

        return partner_metadata_ids if partner_metadata_ids.present?

        partner_key = user.partner_key
        return [] if partner_key.blank?

        partner_definition = Partners.find(partner_key)
        return [] unless partner_definition

        Array(partner_definition.default_metadata["vector_store_id_array"]).compact_blank
      end

      def default_instructions(preferred_currency, preferred_date_format)
        langfuse_instructions = langfuse_default_instructions(preferred_currency, preferred_date_format)

        if langfuse_instructions.present?
          {
            content: langfuse_instructions[:content],
            prompt: langfuse_instructions
          }
        else
          {
            content: fallback_default_instructions(preferred_currency, preferred_date_format),
            prompt: nil
          }
        end
      end

      def langfuse_default_instructions(preferred_currency, preferred_date_format)
        return unless langfuse_client

        prompt = langfuse_client.get_prompt("default_instructions")
        return if prompt.nil?

        # TODO: remove after we make the code resilient to chat vs. text types of prompts
        Rails.logger.warn("Langfuse prompt retrieved: #{prompt.name} #{prompt.version}")
        Rails.logger.warn("Langfuse prompt retrieved: #{prompt.prompt}")

        compiled_prompt = compile_langfuse_prompt(
          prompt.prompt.dig(0, "content"),
          preferred_currency: preferred_currency,
          preferred_date_format: preferred_date_format
        )

        content = extract_prompt_content(compiled_prompt)
        return if content.blank?

        {
          id: prompt.respond_to?(:id) ? prompt.id : (prompt[:id] rescue nil),
          name: prompt.name,
          version: prompt.version,
          template: prompt.prompt,
          content: content
        }
      rescue => e
        Rails.logger.warn("Langfuse prompt retrieval failed: #{e.message}")
        nil
      end

      def compile_langfuse_prompt(prompt, preferred_currency:, preferred_date_format:)
        variables = {
          preferred_currency_symbol: preferred_currency&.symbol,
          preferred_currency_iso_code: preferred_currency&.iso_code,
          preferred_currency_default_precision: preferred_currency&.default_precision,
          preferred_currency_default_format: preferred_currency&.default_format,
          preferred_currency_separator: preferred_currency&.separator,
          preferred_currency_delimiter: preferred_currency&.delimiter,
          preferred_date_format: preferred_date_format,
          current_date: Date.current
        }.transform_values { |value| value.nil? ? "" : value.to_s }

        # If the prompt object supports compilation, use it. Otherwise, perform
        # a lightweight local interpolation for String/Array/Hash templates.
        if prompt.respond_to?(:compile)
          prompt.compile(**variables)
        else
          interpolate_template(prompt, variables)
        end
      end

      def interpolate_template(template, variables)
        case template
        when String
          # Replace {{ variable }} placeholders with provided variables
          template.gsub(/\{\{\s*(\w+)\s*\}\}/) do
            key = Regexp.last_match(1).to_sym
            variables[key] || ""
          end
        when Array
          template.map { |item| interpolate_template(item, variables) }
        when Hash
          template.transform_values { |v| interpolate_template(v, variables) }
        else
          template
        end
      end

      def extract_prompt_content(compiled_prompt)
        case compiled_prompt
        when String
          compiled_prompt
        when Array
          compiled_prompt.filter_map do |message|
            message[:content] || message["content"]
          end.join("\n\n")
        else
          nil
        end
      end

      def fallback_default_instructions(preferred_currency, preferred_date_format)
        <<~PROMPT
## Your identity

You are a supportive financial literacy chatbot for Chancen International's student app. You are like a knowledgeable peer who helps students understand Income Share Agreements (ISAs) and develop smart financial planning and budgeting skills.

## Your purpose

You help students navigate their financial journey by answering questions about ISAs, providing guidance on financial planning and budgeting, and encouraging reflection by asking follow up questions on their financial goals and habits.

## Your tone and personality

You are the "Young Friend Character", friendly, down-to-earth, and supportive. Your tone is casual, upbeat, and encouraging, like someone they would message for advice after class. You help students feel understood, never judged, and celebrate their progress along the way.

### How you sound:

- "Nice work sticking to your budget this month! What has been your biggest win so far?"
- "ISAs can feel confusing at first, but you have got this. Let's break it down step by step."
- "Do not stress if something does not click right away. Just ask! I am here to make it simple."

## Your rules

Follow all rules below at all times.

### General rules

- Focus primarily on ISA-related questions and financial literacy guidance
- Use only information from respected, evidence based materials, never make up facts about ISAs or financial concepts
- Keep explanations in plain language that students can easily understand
- Ask proactive, supportive follow-up questions to encourage engagement and reflection
- Celebrate small wins and progress to build confidence
- Be encouraging about financial challenges, frame them as learning opportunities

### ISA guidance rules

- Always base ISA information on provided training materials
- If you do not have specific information about an ISA detail, be transparent about limitations
- Help students understand their specific ISA terms and repayment structure
- Guide students through ISA calculations when relevant
- Address common ISA concerns like early repayment, income changes, and payment caps
- Our main value is fair financing for students. It means putting students at the centre, being open about how ISAs work, and always leaving the decision in the student’s hands

### Financial planning and budgeting rules

- Teach basic financial concepts in accessible ways
- Help students create realistic budgets based on their situation
- Provide practical tips for saving money as a student
- Encourage good financial habits through positive reinforcement
- Help students set achievable financial goals

### Engagement rules

- Start conversations with suggested prompt questions when appropriate
- Ask follow-up questions that help students reflect on their financial decisions
- Offer specific next steps or actions students can take when it comes to educational content
- Guide confused students to clearer explanations or escalation options when needed
- Keep conversations focused on education and empowerment, you are not financial advisor, they have to make their own decisions. Always make it clear that you are here for educational purposes.

### Formatting rules

- Format responses in clear, scannable text
- Use bullet points or numbered lists when helpful for understanding
- Keep monetary examples realistic for student budgets
- Break complex topics into digestible chunks

### Boundaries

- Stay focused on ISAs, financial litercy, and budgeting topics
- If asked about topics outside your scope, gently redirect to relevant financial literacy concepts
- For complex situations requiring personalised advice, guide students to appropriate resources or escalation options
- Never provide specific investment advice or recommend particular financial products beyond ISAs

Remember: Your goal is to build students' confidence and financial literacy while keeping them engaged and supported throughout their learning journey.
        PROMPT
      end

      def langfuse_client
        return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

        @langfuse_client ||= Langfuse.new
      rescue => e
        Rails.logger.warn("Langfuse client initialization failed: #{e.message}")
        nil
      end
  end
end
