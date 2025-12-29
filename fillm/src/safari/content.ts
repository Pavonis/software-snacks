/**
 * Content script for FIL(L)M Safari extension
 * Runs in the context of web pages to handle selection and DOM extraction
 *
 * This is largely identical to the Chrome version but uses the browser API
 */

import type {
  ExtensionMessage,
  Selection,
  CaptureResult,
  ExtensionSettings,
  ScreenshotResponse,
} from '../core/types';
import { DEFAULT_SETTINGS } from '../core/types';
import { extractCapture } from '../core/dom-extractor';
import { getViewport, cropScreenshot, clampToViewport, padRect } from '../core/capture';
import { downloadAsZip, formatBytes, estimateSize } from '../core/bundler';
import { analyzeCaptureWithClaude } from '../core/claude-api';
import { SelectionOverlay } from '../ui/selection-overlay';
import { NoteModal } from '../ui/note-modal';

// Use browser API with chrome fallback
const api = typeof browser !== 'undefined' ? browser : chrome;

let currentOverlay: SelectionOverlay | null = null;
let currentModal: NoteModal | null = null;
let settings: ExtensionSettings = { ...DEFAULT_SETTINGS };

/**
 * Initialize by loading settings
 */
async function init(): Promise<void> {
  try {
    const response = await api.runtime.sendMessage({ type: 'GET_SETTINGS' });
    if (response) {
      settings = { ...DEFAULT_SETTINGS, ...response };
    }
  } catch (error) {
    console.error('Failed to load settings:', error);
  }
}

/**
 * Listen for messages from background script
 */
api.runtime.onMessage.addListener((
  message: ExtensionMessage,
  _sender: chrome.runtime.MessageSender,
  sendResponse: (response: unknown) => void
) => {
  if (message.type === 'ACTIVATE_SELECTION') {
    activateSelection();
    sendResponse({ success: true });
  }
  return true;
});

/**
 * Activate selection mode
 */
function activateSelection(): void {
  if (currentOverlay || currentModal) {
    return;
  }

  currentOverlay = new SelectionOverlay({
    onSelectionComplete: handleSelectionComplete,
    onCancel: handleCancel,
  });

  currentOverlay.activate();
}

/**
 * Handle selection completion
 */
async function handleSelectionComplete(selection: Selection): Promise<void> {
  currentOverlay = null;

  const extractionOptions = {
    includeStyles: true,
    styleProperties: settings.fullStyles ? undefined : undefined,
  };

  const { dom, styles } = extractCapture(selection.elements, extractionOptions);

  const viewport = getViewport();
  const paddedRect = padRect(selection.rect, 10);
  const clampedRect = clampToViewport(paddedRect, viewport);

  const partialCapture: Partial<CaptureResult> = {
    url: window.location.href,
    title: document.title,
    viewport,
    selection: {
      type: selection.type,
      rect: clampedRect,
    },
    dom,
    styles,
    screenshot: '',
  };

  showNoteModal(partialCapture, clampedRect);
}

/**
 * Show the note modal
 */
function showNoteModal(
  partialCapture: Partial<CaptureResult>,
  rect: { x: number; y: number; width: number; height: number }
): void {
  requestScreenshot().then(async (fullScreenshot) => {
    if (fullScreenshot && currentModal) {
      const viewport = getViewport();
      try {
        const croppedScreenshot = await cropScreenshot(fullScreenshot, rect, viewport);
        partialCapture.screenshot = croppedScreenshot;
        currentModal.updateScreenshot(croppedScreenshot);
      } catch (error) {
        console.error('Failed to crop screenshot:', error);
        partialCapture.screenshot = fullScreenshot;
        currentModal.updateScreenshot(fullScreenshot);
      }
    }
  });

  const estimatedSize = partialCapture.dom
    ? formatBytes(estimateSize(partialCapture as CaptureResult))
    : undefined;

  currentModal = new NoteModal(
    partialCapture,
    {
      onDownload: handleDownload,
      onSendToClaude: handleSendToClaude,
      onCancel: handleCancel,
    },
    {
      claudeEnabled: !!settings.claudeApiKey,
      captureSize: estimatedSize,
    }
  );

  currentModal.show();
}

/**
 * Request screenshot from background script
 */
async function requestScreenshot(): Promise<string | null> {
  try {
    const response = await api.runtime.sendMessage({
      type: 'CAPTURE_SCREENSHOT',
    }) as ScreenshotResponse;

    if (response.error) {
      console.error('Screenshot error:', response.error);
      return null;
    }

    return response.screenshot;
  } catch (error) {
    console.error('Failed to request screenshot:', error);
    return null;
  }
}

/**
 * Handle download action
 */
async function handleDownload(capture: CaptureResult): Promise<void> {
  currentModal = null;

  try {
    await downloadAsZip(capture);
  } catch (error) {
    console.error('Download failed:', error);
    alert('Failed to download capture. Please try again.');
  }
}

/**
 * Handle send to Claude action
 */
async function handleSendToClaude(capture: CaptureResult): Promise<void> {
  currentModal = null;

  if (!settings.claudeApiKey) {
    alert('Please configure your Claude API key in the extension settings.');
    return;
  }

  try {
    const loadingDiv = document.createElement('div');
    loadingDiv.style.cssText = `
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: rgba(0, 0, 0, 0.9);
      color: white;
      padding: 24px 48px;
      border-radius: 12px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 16px;
      z-index: 2147483647;
    `;
    loadingDiv.textContent = 'Analyzing with Claude...';
    document.body.appendChild(loadingDiv);

    const response = await analyzeCaptureWithClaude(capture, {
      apiKey: settings.claudeApiKey,
    });

    loadingDiv.remove();
    showClaudeResponse(response);
  } catch (error) {
    console.error('Claude API error:', error);
    alert(`Failed to analyze with Claude: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

/**
 * Show Claude's response in a modal
 */
function showClaudeResponse(response: string): void {
  const modal = document.createElement('div');
  modal.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.7);
    z-index: 2147483647;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  `;

  modal.innerHTML = `
    <div style="
      background: white;
      border-radius: 12px;
      width: 90%;
      max-width: 700px;
      max-height: 80vh;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    ">
      <div style="
        padding: 20px 24px;
        border-bottom: 1px solid #eee;
        display: flex;
        justify-content: space-between;
        align-items: center;
      ">
        <h2 style="margin: 0; font-size: 18px; color: #333;">Claude's Analysis</h2>
        <button id="fillm-close-response" style="
          background: #f0f0f0;
          border: none;
          padding: 8px 16px;
          border-radius: 6px;
          cursor: pointer;
          font-size: 14px;
        ">Close</button>
      </div>
      <div style="
        padding: 24px;
        overflow-y: auto;
        flex: 1;
      ">
        <pre style="
          white-space: pre-wrap;
          word-wrap: break-word;
          font-family: inherit;
          font-size: 14px;
          line-height: 1.6;
          color: #333;
          margin: 0;
        ">${escapeHtml(response)}</pre>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  const closeBtn = modal.querySelector('#fillm-close-response');
  closeBtn?.addEventListener('click', () => modal.remove());
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
  document.addEventListener('keydown', function handler(e) {
    if (e.key === 'Escape') {
      modal.remove();
      document.removeEventListener('keydown', handler);
    }
  });
}

/**
 * Escape HTML entities
 */
function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

/**
 * Handle cancel action
 */
function handleCancel(): void {
  currentOverlay = null;
  currentModal = null;
}

// TypeScript declaration for browser API
declare const browser: typeof chrome;

// Initialize
init();
