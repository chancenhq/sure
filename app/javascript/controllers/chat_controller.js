import { Controller } from "@hotwired/stimulus";

let sharedPendingHistoryUpdate = null;

function setPendingHistoryUpdate(update) {
  sharedPendingHistoryUpdate = update;
}

function consumePendingHistoryUpdate() {
  const update = sharedPendingHistoryUpdate;
  sharedPendingHistoryUpdate = null;
  return update;
}

export default class extends Controller {
  static targets = ["messages", "form", "input"];

  connect() {
    this.#configureAutoScroll();
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
    const historyMethod = link.dataset.turboAction === "replace" ? "replace" : "push";

    setPendingHistoryUpdate({ action: historyMethod, url: nextLocation });
  }

  recordFrameVisit(event) {
    const pendingUpdate = consumePendingHistoryUpdate();

    const history = window.Turbo?.navigator?.history;

    if (!pendingUpdate || !history) {
      return;
    }

    const { action } = pendingUpdate;
    const responseUrl =
      event.detail?.fetchResponse?.response?.url || event.detail?.fetchResponse?.url;
    const nextLocation = responseUrl
      ? new URL(responseUrl, window.location.origin)
      : pendingUpdate.url;
    const currentLocation = window.Turbo.navigator.location || new URL(window.location.href);

    if (typeof history[action] !== "function") {
      return;
    }

    if (!nextLocation.pathname.startsWith("/chats")) {
      return;
    }

    if (currentLocation.href === nextLocation.href) {
      return;
    }

    history[action](nextLocation);
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
}
