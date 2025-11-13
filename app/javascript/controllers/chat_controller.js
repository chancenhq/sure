import { Controller } from "@hotwired/stimulus";
import { getPostHog } from "services/posthog";

export default class extends Controller {
  static targets = ["messages", "form", "input"];
  static values = {
    chatId: String,
    userId: String,
    createdAt: String,
    isNew: Boolean,
  };

  connect() {
    this.#configureAutoScroll();
    this.#trackChatSession();
    this.messageSubmitTime = null;
    this.currentMessageNumber = 0;
    this.waitingForFirstToken = false;
  }

  disconnect() {
    if (this.messagesObserver) {
      this.messagesObserver.disconnect();
    }
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

  // Track message submission time for time-to-first-token calculation
  trackMessageSubmit() {
    this.messageSubmitTime = Date.now();
    this.currentMessageNumber++;
    this.waitingForFirstToken = true;
  }

  #configureAutoScroll() {
    this.messagesObserver = new MutationObserver((mutations) => {
      if (this.hasMessagesTarget) {
        this.#scrollToBottom();
      }

      // Track time to first token when assistant message appears
      if (this.waitingForFirstToken && this.messageSubmitTime) {
        // Check if an assistant message was added/updated
        const hasAssistantMessage = mutations.some((mutation) => {
          return Array.from(mutation.addedNodes).some((node) => {
            return (
              node.nodeType === 1 &&
              (node.querySelector('[role="assistant"]') ||
                (node.hasAttribute("role") &&
                  node.getAttribute("role") === "assistant"))
            );
          });
        });

        if (hasAssistantMessage) {
          const timeToFirstToken = Date.now() - this.messageSubmitTime;
          this.captureEvent("sure_chat_message_time_to_first_token", {
            time_to_first_token_ms: timeToFirstToken,
            message_number: this.currentMessageNumber,
          });
          this.waitingForFirstToken = false;
          this.messageSubmitTime = null;
        }
      }
    });

    // Listen to entire sidebar for changes, always try to scroll to the bottom
    this.messagesObserver.observe(this.element, {
      childList: true,
      subtree: true,
    });
  }

  #scrollToBottom = () => {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  };

  #trackChatSession() {
    if (!this.hasChatIdValue || !this.hasUserIdValue) return;

    const reopenCount = this.#getReopenCount();

    if (this.isNewValue || reopenCount === 0) {
      // New chat started
      this.captureEvent("sure_chat_started", {
        timestamp: this.createdAtValue || new Date().toISOString(),
      });
    } else {
      // Existing chat opened
      const newReopenCount = reopenCount + 1;
      this.#setReopenCount(newReopenCount);
      this.captureEvent("sure_chat_opened", {
        timestamp: new Date().toISOString(),
        reopen_count: newReopenCount,
      });
    }
  }

  #getReopenCount() {
    const key = `chat_${this.chatIdValue}_reopen_count`;
    return parseInt(localStorage.getItem(key) || "0", 10);
  }

  #setReopenCount(count) {
    const key = `chat_${this.chatIdValue}_reopen_count`;
    localStorage.setItem(key, count.toString());
  }

  captureEvent(eventName, properties = {}) {
    const posthog = getPostHog();
    if (!posthog) return;

    // Add chat ID and user ID to all events for grouping
    const eventProperties = {
      ...properties,
      chat_id: this.chatIdValue,
      user_id: this.userIdValue,
    };

    posthog.capture(eventName, eventProperties);
  }
}
