import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["messages", "form", "input"];
  static values = {
    chatId: String,
    userId: String,
  };

  connect() {
    this.#configureAutoScroll();
    this._chatOpenCountFallback = this._chatOpenCountFallback || new Map();
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

  #configureAutoScroll() {
    this.messagesObserver = new MutationObserver((_mutations) => {
      if (this.hasMessagesTarget) {
        this.#scrollToBottom();
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

  captureEvent(eventName, eventData = {}) {
    if (!window.posthog || typeof window.posthog.capture !== "function") {
      return;
    }

    const {
      chatId: providedChatId,
      userId: providedUserId,
      properties: additionalProperties = {},
      timestamp,
      ...rest
    } = eventData;

    const chatId = this.#resolveChatId(providedChatId);
    const userId = this.#resolveUserId(providedUserId);

    const properties = { ...additionalProperties };

    if (chatId) {
      properties.chat_id = chatId;
    }

    if (userId) {
      properties.user_id = userId;
    }

    const nowIso = new Date().toISOString();

    switch (eventName) {
      case "sure_chat_started": {
        const startedAt = this.#formatIsoTimestamp(
          rest.startedAt || timestamp || nowIso,
        );
        if (startedAt) {
          properties.started_at = startedAt;
        }
        break;
      }
      case "sure_chat_opened": {
        const openedAt = this.#formatIsoTimestamp(
          rest.openedAt || timestamp || nowIso,
        );
        if (openedAt) {
          properties.opened_at = openedAt;
        }

        const openCountValue =
          rest.openCount ?? this.#incrementChatOpenCount(chatId);
        const openCount = this.#coerceNumber(openCountValue);
        if (Number.isFinite(openCount)) {
          properties.open_count = openCount;
        }
        break;
      }
      case "sure_chat_message_time_to_first_token": {
        const questionAskedAt = this.#formatIsoTimestamp(
          rest.questionAskedAt,
        );
        if (questionAskedAt) {
          properties.question_asked_at = questionAskedAt;
        }

        const firstTokenAt = this.#formatIsoTimestamp(
          rest.firstTokenAt || timestamp,
        );
        if (firstTokenAt) {
          properties.first_token_at = firstTokenAt;
        }

        const timeToFirstTokenValue =
          rest.timeToFirstTokenMs ??
          this.#computeDurationMs(questionAskedAt, firstTokenAt);
        const timeToFirstTokenMs = this.#coerceNumber(timeToFirstTokenValue);

        if (Number.isFinite(timeToFirstTokenMs)) {
          properties.time_to_first_token_ms = timeToFirstTokenMs;
        }

        if (rest.messageNumber != null) {
          const messageNumber = this.#coerceNumber(rest.messageNumber);
          if (Number.isFinite(messageNumber)) {
            properties.message_number = messageNumber;
          }
        }

        break;
      }
      default: {
        Object.assign(properties, rest);
      }
    }

    const groups = this.#buildGroups(chatId, userId);
    const captureOptions = groups ? { groups } : undefined;

    if (captureOptions) {
      window.posthog.capture(eventName, properties, captureOptions);
    } else {
      window.posthog.capture(eventName, properties);
    }
  }

  #resolveChatId(providedChatId) {
    if (providedChatId) {
      return String(providedChatId);
    }

    if (this.hasChatIdValue) {
      return this.chatIdValue;
    }

    if (this.element.dataset.chatId) {
      return this.element.dataset.chatId;
    }

    if (this.hasFormTarget) {
      const action = this.formTarget.getAttribute("action");
      if (action) {
        const match = action.match(/\/chats\/(\d+)/);
        if (match) {
          return match[1];
        }
      }
    }

    return null;
  }

  #resolveUserId(providedUserId) {
    if (providedUserId) {
      return String(providedUserId);
    }

    if (this.hasUserIdValue) {
      return this.userIdValue;
    }

    if (this.element.dataset.userId) {
      return this.element.dataset.userId;
    }

    const appLayoutElement = document.querySelector(
      "[data-controller~='app-layout']",
    );

    if (appLayoutElement?.dataset?.appLayoutUserIdValue) {
      return appLayoutElement.dataset.appLayoutUserIdValue;
    }

    return null;
  }

  #buildGroups(chatId, userId) {
    const groups = {};

    if (chatId) {
      groups.chat = String(chatId);
    }

    if (userId) {
      groups.user = String(userId);
    }

    return Object.keys(groups).length > 0 ? groups : null;
  }

  #formatIsoTimestamp(value) {
    if (!value) {
      return null;
    }

    const date = this.#parseDate(value);
    return date ? date.toISOString() : null;
  }

  #computeDurationMs(start, end) {
    const startDate = this.#parseDate(start);
    const endDate = this.#parseDate(end);

    if (!startDate || !endDate) {
      return null;
    }

    return Math.max(0, endDate.getTime() - startDate.getTime());
  }

  #parseDate(value) {
    if (value instanceof Date) {
      return Number.isNaN(value.getTime()) ? null : value;
    }

    if (typeof value === "number") {
      const dateFromNumber = new Date(value);
      return Number.isNaN(dateFromNumber.getTime()) ? null : dateFromNumber;
    }

    if (typeof value === "string") {
      const dateFromString = new Date(value);
      return Number.isNaN(dateFromString.getTime()) ? null : dateFromString;
    }

    return null;
  }

  #coerceNumber(value) {
    if (value == null) {
      return null;
    }

    if (typeof value === "number") {
      return value;
    }

    if (typeof value === "string" && value.trim() === "") {
      return null;
    }

    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
  }

  #incrementChatOpenCount(chatId) {
    if (!chatId) {
      return null;
    }

    const storageKey = `sure:chat:${chatId}:open_count`;

    try {
      const existingValue = window.sessionStorage.getItem(storageKey);
      const currentCount = Number.parseInt(existingValue ?? "0", 10);
      const nextCount = Number.isFinite(currentCount) ? currentCount + 1 : 1;
      window.sessionStorage.setItem(storageKey, nextCount);
      return nextCount;
    } catch (_error) {
      const currentCount = this._chatOpenCountFallback.get(chatId) || 0;
      const nextCount = currentCount + 1;
      this._chatOpenCountFallback.set(chatId, nextCount);
      return nextCount;
    }
  }
}
