#!/usr/bin/env node

const { chromium } = require('playwright');

async function run() {
  const email = process.env.COMPANION_EMAIL;
  const password = process.env.COMPANION_PASSWORD;

  if (!email || !password) {
    throw new Error('Missing COMPANION_EMAIL or COMPANION_PASSWORD environment variables');
  }

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  page.setDefaultTimeout(60000);
  page.setDefaultNavigationTimeout(60000);

  try {
    await page.goto('https://companion.chancen.tech/sessions/new', { waitUntil: 'networkidle' });

    await page.fill('input[name="session[email]"]', email);
    await page.fill('input[name="session[password]"]', password);

    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle', { timeout: 60000 });

    // Ensure we are authenticated by navigating to the chats page explicitly.
    await page.goto('https://companion.chancen.tech/chats/new', { waitUntil: 'networkidle' });

    const chatFormSelector = '#chat-form textarea';
    await page.waitForSelector(chatFormSelector, { timeout: 30000 });

    await page.fill(chatFormSelector, 'Hi');

    await Promise.all([
      page.waitForURL((url) => url.includes('/chats/'), { waitUntil: 'networkidle' }),
      page.click('#chat-form button[type="submit"]'),
    ]);

    const assistantSelector = '#messages [id^="assistant_message_"] .prose--ai-chat';

    await page.waitForSelector('#messages', { timeout: 30000 });

    const initialAssistantCount = await page.locator(assistantSelector).count();

    await page.waitForFunction(
      ({ selector, minimumCount }) => {
        return document.querySelectorAll(selector).length > minimumCount;
      },
      { selector: assistantSelector, minimumCount: initialAssistantCount },
      { timeout: 120000 }
    );

    const assistantMessages = page.locator(assistantSelector);
    const latestMessage = await assistantMessages.nth(-1).innerText();

    if (!latestMessage || latestMessage.trim().length === 0) {
      throw new Error('Assistant response is empty');
    }

    console.log('Assistant responded with:', latestMessage.trim());
  } finally {
    await browser.close();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
