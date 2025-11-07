import { Controller } from "@hotwired/stimulus";

const THINKING_TIMEOUT_MS = 30_000;

export default class extends Controller {
  static targets = ["messages", "form", "input"];
  static values = { chatId: String };

  connect() {
    this.#clearThinkingTimeout();

    if (!this.hasMessagesTarget) {
      return;
    }

    this.#configureAutoScroll();
    this.#initializeThinkingMonitor();
    this.#scrollToBottom();
  }

  disconnect() {
    if (this.messagesObserver) {
      this.messagesObserver.disconnect();
      this.messagesObserver = null;
    }

    this.#clearThinkingTimeout();
  }

  autoResize() {
    const input = this.inputTarget;
    const lineHeight = 20; // text-sm line-height (14px * 1.429 ≈ 20px)
    const maxLines = 3; // 3 lines = 60px total

    input.style.height = "auto";
    input.style.height = `${Math.min(input.scrollHeight, lineHeight * maxLines)}px`;
    input.style.overflowY =
      input.scrollHeight > lineHeight * maxLines ? "auto" : "hidden";
  }

  submitSampleQuestion(e) {
    this.inputTarget.value = e.target.dataset.chatQuestionParam;

    setTimeout(() => {
      this.formTarget.requestSubmit();
    }, 200);
  }

  // Newlines require shift+enter, otherwise submit the form (same functionality as ChatGPT and others)
  handleInputKeyDown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      this.formTarget.requestSubmit();
    }
  }

  #configureAutoScroll() {
    this.messagesObserver = new MutationObserver((mutations) => {
      let thinkingAdded = false;
      let thinkingRemoved = false;

      mutations.forEach((mutation) => {
        thinkingAdded ||= this.#mutationIncludesThinkingIndicator(mutation.addedNodes);
        thinkingRemoved ||= this.#mutationIncludesThinkingIndicator(
          mutation.removedNodes,
        );
      });

      if (thinkingAdded) {
        this.#startThinkingTimeout();
      }

      if (thinkingRemoved) {
        this.#clearThinkingTimeout();
      }

      this.#scrollToBottom();
    });

    this.messagesObserver.observe(this.messagesTarget, {
      childList: true,
      subtree: true,
    });
  }

  #initializeThinkingMonitor() {
    if (this.#findThinkingIndicator()) {
      this.#startThinkingTimeout();
    }
  }

  #mutationIncludesThinkingIndicator(nodes) {
    return Array.from(nodes || []).some((node) => this.#nodeContainsThinkingIndicator(node));
  }

  #nodeContainsThinkingIndicator(node) {
    if (!node) {
      return false;
    }

    if (node.nodeType === Node.ELEMENT_NODE) {
      if (node.id === "thinking-indicator") {
        return true;
      }

      if (typeof node.querySelector === "function") {
        return Boolean(node.querySelector("#thinking-indicator"));
      }
    }

    return false;
  }

  #findThinkingIndicator() {
    if (!this.hasMessagesTarget) {
      return null;
    }

    return this.messagesTarget.querySelector?.("#thinking-indicator") || null;
  }

  #startThinkingTimeout() {
    if (this.thinkingTimeoutId || this.didReportThinkingTimeout) {
      return;
    }

    this.didReportThinkingTimeout = false;
    this.thinkingTimeoutId = window.setTimeout(
      this.#handleThinkingTimeout,
      THINKING_TIMEOUT_MS,
    );
  }

  #clearThinkingTimeout() {
    if (this.thinkingTimeoutId) {
      window.clearTimeout(this.thinkingTimeoutId);
      this.thinkingTimeoutId = null;
    }

    this.didReportThinkingTimeout = false;
  }

  #handleThinkingTimeout = () => {
    this.thinkingTimeoutId = null;

    if (!this.#findThinkingIndicator() || this.didReportThinkingTimeout) {
      return;
    }

    this.didReportThinkingTimeout = true;

    if (window.posthog?.capture) {
      window.posthog.capture("chat_thinking_timeout", {
        chat_id: this.hasChatIdValue ? this.chatIdValue : null,
        message_count: this.#conversationMessageCount(),
        timeout_ms: THINKING_TIMEOUT_MS,
      });
    }
  };

  #conversationMessageCount() {
    if (!this.hasMessagesTarget) {
      return 0;
    }

    return this.messagesTarget.querySelectorAll(
      "[id^='user_message_'], [id^='assistant_message_']",
    ).length;
  }

  #scrollToBottom = () => {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  };
}
