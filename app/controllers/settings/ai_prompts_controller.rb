class Settings::AiPromptsController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "AI Prompts", nil ]
    ]
    @family = Current.family
    @assistant_config = Assistant.config_for(OpenStruct.new(user: Current.user))
    @prompt_template = Setting.assistant_system_prompt_template.presence || Assistant::Configurable::DEFAULT_PROMPT_TEMPLATE
    @prompt_tokens = Assistant::Configurable::PROMPT_TOKENS
  end

  def update
    template = ai_prompt_params[:assistant_system_prompt_template].to_s.strip
    Setting.assistant_system_prompt_template = template.presence

    redirect_to settings_ai_prompts_path, notice: t(".success")
  end

  private
    def ai_prompt_params
      params.require(:setting).permit(:assistant_system_prompt_template)
    end
end
