// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import { initPostHog } from "services/posthog";

Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.target);
};

// Initialize PostHog on page load
document.addEventListener("DOMContentLoaded", () => {
  initPostHog();
});
