/**
 * Popup script for FIL(L)M extension
 * Handles settings and quick actions
 */

import type { ExtensionSettings } from '../../core/types';
import { DEFAULT_SETTINGS } from '../../core/types';

// DOM elements
const captureBtn = document.getElementById('capture-btn') as HTMLButtonElement;
const shortcutDisplay = document.getElementById('shortcut-display') as HTMLElement;
const apiKeyInput = document.getElementById('api-key') as HTMLInputElement;
const toggleKeyBtn = document.getElementById('toggle-key') as HTMLButtonElement;
const apiStatus = document.getElementById('api-status') as HTMLElement;
const defaultActionSelect = document.getElementById('default-action') as HTMLSelectElement;
const fullStylesCheckbox = document.getElementById('full-styles') as HTMLInputElement;
const shortcutsLink = document.getElementById('shortcuts-link') as HTMLAnchorElement;

let settings: ExtensionSettings = { ...DEFAULT_SETTINGS };

/**
 * Load settings from storage
 */
async function loadSettings(): Promise<void> {
  try {
    const result = await chrome.storage.sync.get('settings');
    if (result.settings) {
      settings = { ...DEFAULT_SETTINGS, ...result.settings };
    }
    updateUI();
  } catch (error) {
    console.error('Failed to load settings:', error);
  }
}

/**
 * Save settings to storage
 */
async function saveSettings(): Promise<void> {
  try {
    await chrome.storage.sync.set({ settings });
  } catch (error) {
    console.error('Failed to save settings:', error);
  }
}

/**
 * Update UI with current settings
 */
function updateUI(): void {
  apiKeyInput.value = settings.claudeApiKey || '';
  defaultActionSelect.value = settings.defaultAction;
  fullStylesCheckbox.checked = settings.fullStyles;

  // Update API status
  if (settings.claudeApiKey) {
    apiStatus.textContent = '✓ API key configured';
    apiStatus.className = 'hint status-ok';
  } else {
    apiStatus.textContent = 'Required for Claude integration';
    apiStatus.className = 'hint';
  }

  // Load keyboard shortcut
  loadShortcut();
}

/**
 * Load the configured keyboard shortcut
 */
async function loadShortcut(): Promise<void> {
  try {
    const commands = await chrome.commands.getAll();
    const captureCommand = commands.find((cmd) => cmd.name === 'activate-capture');
    if (captureCommand?.shortcut) {
      shortcutDisplay.textContent = captureCommand.shortcut;
    }
  } catch (error) {
    console.error('Failed to load shortcut:', error);
  }
}

/**
 * Handle capture button click
 */
async function handleCapture(): Promise<void> {
  try {
    // Get current active tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id) return;

    // Send message to activate capture
    await chrome.tabs.sendMessage(tab.id, { type: 'ACTIVATE_SELECTION' });

    // Close popup
    window.close();
  } catch (error) {
    console.error('Failed to start capture:', error);
  }
}

/**
 * Handle API key toggle visibility
 */
function handleToggleKey(): void {
  const isPassword = apiKeyInput.type === 'password';
  apiKeyInput.type = isPassword ? 'text' : 'password';
  toggleKeyBtn.textContent = isPassword ? '🔒' : '👁';
}

/**
 * Handle API key change
 */
function handleApiKeyChange(): void {
  settings.claudeApiKey = apiKeyInput.value.trim() || undefined;
  saveSettings();
  updateUI();
}

/**
 * Handle default action change
 */
function handleDefaultActionChange(): void {
  settings.defaultAction = defaultActionSelect.value as ExtensionSettings['defaultAction'];
  saveSettings();
}

/**
 * Handle full styles toggle
 */
function handleFullStylesChange(): void {
  settings.fullStyles = fullStylesCheckbox.checked;
  saveSettings();
}

/**
 * Handle shortcuts link click
 */
function handleShortcutsLink(e: MouseEvent): void {
  e.preventDefault();
  chrome.tabs.create({ url: 'chrome://extensions/shortcuts' });
}

// Event listeners
captureBtn.addEventListener('click', handleCapture);
toggleKeyBtn.addEventListener('click', handleToggleKey);
apiKeyInput.addEventListener('change', handleApiKeyChange);
defaultActionSelect.addEventListener('change', handleDefaultActionChange);
fullStylesCheckbox.addEventListener('change', handleFullStylesChange);
shortcutsLink.addEventListener('click', handleShortcutsLink);

// Initialize
loadSettings();
