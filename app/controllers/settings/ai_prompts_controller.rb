class Settings::AiPromptsController < ApplicationController
  layout "settings"

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "AI Prompts", nil ]
    ]
    @family = Current.family
    @assistant_config = Assistant.config_for(OpenStruct.new(user: Current.user))
  end

  def update
    Setting.langfuse_prompt_cache_ttl_seconds = ai_prompt_params[:langfuse_prompt_cache_ttl_seconds]

    redirect_to settings_ai_prompts_path, notice: t(".success")
  end

  private
    def ai_prompt_params
      params.require(:setting).permit(:langfuse_prompt_cache_ttl_seconds)
    end
end
