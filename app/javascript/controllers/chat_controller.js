import { Controller } from "@hotwired/stimulus";

const pendingHistoryUpdatesByFrameId = new Map();

function normalizeUrl(value) {
  if (!value) {
    return null;
  }

  try {
    return new URL(value, window.location.origin).toString();
  } catch (_error) {
    return null;
  }
}

function queuePendingHistoryUpdate({ frameId, action, url }) {
  const normalizedUrl = normalizeUrl(url);

  if (!frameId || !normalizedUrl) {
    return;
  }

  pendingHistoryUpdatesByFrameId.set(frameId, {
    action,
    url: normalizedUrl,
  });
}

function peekPendingHistoryUpdate(frameId) {
  return pendingHistoryUpdatesByFrameId.get(frameId) || null;
}

function clearPendingHistoryUpdate(frameId) {
  pendingHistoryUpdatesByFrameId.delete(frameId);
}

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

  updateUrl(event) {
    const link = event.currentTarget;

    if (!link || typeof link.getAttribute !== "function") {
      return;
    }

    const href = link.getAttribute("href");

    if (!href || !window.Turbo?.navigator?.history) {
      return;
    }

    const nextLocation = new URL(href, window.location.origin);

    if (!nextLocation.pathname.startsWith("/chats")) {
      return;
    }
    const frameId =
      link.getAttribute("data-turbo-frame") || link.closest("turbo-frame")?.id;

    if (!frameId) {
      return;
    }

    const historyMethod = link.dataset.turboAction === "replace" ? "replace" : "push";

    queuePendingHistoryUpdate({
      frameId,
      action: historyMethod,
      url: nextLocation,
    });
  }

  recordFrameVisit(event) {
    const frame = event?.target;
    const frameId = frame?.id;
    const history = window.Turbo?.navigator?.history;

    if (!history || !frameId) {
      return;
    }

    const responseUrl =
      event.detail?.fetchResponse?.response?.url || event.detail?.fetchResponse?.url;
    const nextUrlCandidate = normalizeUrl(responseUrl) || normalizeUrl(frame?.src);

    if (!nextUrlCandidate) {
      return;
    }

    const candidateLocation = new URL(nextUrlCandidate);

    // Only handle chat routes
    if (!candidateLocation.pathname.startsWith("/chats")) {
      return;
    }

    const currentLocation = window.Turbo.navigator.location || new URL(window.location.href);

    const pendingUpdate = frameId ? peekPendingHistoryUpdate(frameId) : null;

    // If this render corresponds to a queued history update (from a link click),
    // honor the requested action (push/replace) but only if pathnames match.
    if (pendingUpdate) {
      const { action } = pendingUpdate;
      const pendingLocation = new URL(pendingUpdate.url);

      if (candidateLocation.pathname !== pendingLocation.pathname) {
        return;
      }

      if (typeof history[action] !== "function") {
        return;
      }

      if (currentLocation.href === candidateLocation.href) {
        return;
      }

      history[action](candidateLocation);
      clearPendingHistoryUpdate(frameId);
      return;
    }

    // No pending update (e.g., form submission returned a frame render).
    // If we're on a chats route and the URL changed, push it so the address bar matches.
    if (currentLocation.href !== candidateLocation.href) {
      history.push(candidateLocation);
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
