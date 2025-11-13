import posthog from "posthog-js";

let initialized = false;

export function initPostHog() {
  if (initialized) return posthog;

  // Read PostHog configuration from meta tags
  const apiKeyMeta = document.querySelector('meta[name="posthog-api-key"]');
  const hostMeta = document.querySelector('meta[name="posthog-host"]');

  const apiKey = apiKeyMeta?.getAttribute("content");
  const host = hostMeta?.getAttribute("content") || "https://us.i.posthog.com";

  if (apiKey) {
    posthog.init(apiKey, {
      api_host: host,
      loaded: (posthog) => {
        if (process.env.NODE_ENV === "development") {
          console.log("PostHog loaded successfully");
        }
      },
    });
    initialized = true;
  } else if (process.env.NODE_ENV === "development") {
    console.warn(
      "PostHog API key not found. Set POSTHOG_API_KEY to enable analytics.",
    );
  }

  return posthog;
}

export function getPostHog() {
  return initialized ? posthog : null;
}

export { posthog };
