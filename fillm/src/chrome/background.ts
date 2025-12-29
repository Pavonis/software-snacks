/**
 * Background service worker for FIL(L)M Chrome extension
 * Handles keyboard shortcuts and screenshot capture
 */

import type {
  ExtensionMessage,
  ScreenshotResponse,
  ExtensionSettings,
} from '../core/types';
import { DEFAULT_SETTINGS } from '../core/types';

/**
 * Listen for keyboard shortcut commands
 */
chrome.commands.onCommand.addListener(async (command) => {
  if (command === 'activate-capture') {
    await activateCapture();
  }
});

/**
 * Listen for messages from content scripts and popup
 */
chrome.runtime.onMessage.addListener((message: ExtensionMessage, sender, sendResponse) => {
  handleMessage(message, sender, sendResponse);
  return true; // Keep the message channel open for async response
});

/**
 * Handle incoming messages
 */
async function handleMessage(
  message: ExtensionMessage,
  sender: chrome.runtime.MessageSender,
  sendResponse: (response: unknown) => void
): Promise<void> {
  switch (message.type) {
    case 'CAPTURE_SCREENSHOT':
      await handleScreenshotRequest(sender.tab?.id, sendResponse);
      break;

    case 'GET_SETTINGS':
      const settings = await getSettings();
      sendResponse(settings);
      break;

    case 'SAVE_SETTINGS':
      await saveSettings(message.payload as Partial<ExtensionSettings>);
      sendResponse({ success: true });
      break;

    default:
      sendResponse({ error: 'Unknown message type' });
  }
}

/**
 * Activate capture mode in the current tab
 */
async function activateCapture(): Promise<void> {
  try {
    // Get the current active tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id) {
      console.error('No active tab found');
      return;
    }

    // Check if we can inject into this tab
    if (!tab.url || tab.url.startsWith('chrome://') || tab.url.startsWith('chrome-extension://')) {
      console.warn('Cannot inject into this page');
      return;
    }

    // Inject the content script if needed
    try {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ['content.js'],
      });
    } catch (error) {
      // Script might already be injected
      console.log('Script injection skipped (may already be present):', error);
    }

    // Send activation message
    await chrome.tabs.sendMessage(tab.id, { type: 'ACTIVATE_SELECTION' });
  } catch (error) {
    console.error('Failed to activate capture:', error);
  }
}

/**
 * Handle screenshot request from content script
 */
async function handleScreenshotRequest(
  tabId: number | undefined,
  sendResponse: (response: ScreenshotResponse) => void
): Promise<void> {
  if (!tabId) {
    sendResponse({ screenshot: '', error: 'No tab ID provided' });
    return;
  }

  try {
    // Capture the visible tab
    const dataUrl = await chrome.tabs.captureVisibleTab(undefined, {
      format: 'png',
      quality: 100,
    });

    sendResponse({ screenshot: dataUrl });
  } catch (error) {
    console.error('Screenshot capture failed:', error);
    sendResponse({
      screenshot: '',
      error: error instanceof Error ? error.message : 'Screenshot failed',
    });
  }
}

/**
 * Get extension settings from storage
 */
async function getSettings(): Promise<ExtensionSettings> {
  try {
    const result = await chrome.storage.sync.get('settings');
    return { ...DEFAULT_SETTINGS, ...result.settings };
  } catch (error) {
    console.error('Failed to get settings:', error);
    return DEFAULT_SETTINGS;
  }
}

/**
 * Save extension settings to storage
 */
async function saveSettings(updates: Partial<ExtensionSettings>): Promise<void> {
  try {
    const current = await getSettings();
    const updated = { ...current, ...updates };
    await chrome.storage.sync.set({ settings: updated });
  } catch (error) {
    console.error('Failed to save settings:', error);
  }
}

/**
 * Listen for extension installation/update
 */
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    console.log('FIL(L)M extension installed');
    // Could open onboarding page here
  } else if (details.reason === 'update') {
    console.log('FIL(L)M extension updated');
  }
});
