/**
 * Note modal for FIL(L)M
 * Allows user to add a description before saving/sending the capture
 */

import type { CaptureResult } from '../core/types';

export interface NoteModalCallbacks {
  onDownload: (capture: CaptureResult) => void;
  onSendToClaude: (capture: CaptureResult) => void;
  onCancel: () => void;
}

export interface NoteModalOptions {
  /** Whether Claude API is configured */
  claudeEnabled: boolean;
  /** Estimated capture size */
  captureSize?: string;
}

/**
 * Note modal manager
 * Shows a modal for the user to add notes before saving
 */
export class NoteModal {
  private modal: HTMLDivElement | null = null;
  private styleElement: HTMLStyleElement | null = null;
  private capture: Partial<CaptureResult>;
  private callbacks: NoteModalCallbacks;
  private options: NoteModalOptions;

  constructor(
    capture: Partial<CaptureResult>,
    callbacks: NoteModalCallbacks,
    options: NoteModalOptions
  ) {
    this.capture = capture;
    this.callbacks = callbacks;
    this.options = options;
  }

  /**
   * Show the modal
   */
  show(): void {
    if (this.modal) return;

    this.injectStyles();
    this.createModal();
    this.attachEventListeners();

    // Focus the textarea
    setTimeout(() => {
      const textarea = this.modal?.querySelector('textarea');
      textarea?.focus();
    }, 100);
  }

  /**
   * Hide and remove the modal
   */
  hide(): void {
    this.removeEventListeners();
    this.removeModal();
    this.removeStyles();
  }

  /**
   * Inject CSS styles
   */
  private injectStyles(): void {
    if (this.styleElement) return;

    this.styleElement = document.createElement('style');
    this.styleElement.textContent = `
      .fillm-modal-backdrop {
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        background: rgba(0, 0, 0, 0.6);
        z-index: 2147483647;
        display: flex;
        align-items: center;
        justify-content: center;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }

      .fillm-modal {
        background: white;
        border-radius: 12px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        width: 90%;
        max-width: 500px;
        overflow: hidden;
      }

      .fillm-modal-header {
        padding: 20px 24px;
        border-bottom: 1px solid #eee;
      }

      .fillm-modal-header h2 {
        margin: 0;
        font-size: 18px;
        font-weight: 600;
        color: #333;
      }

      .fillm-modal-header p {
        margin: 8px 0 0;
        font-size: 14px;
        color: #666;
      }

      .fillm-modal-body {
        padding: 20px 24px;
      }

      .fillm-modal-body label {
        display: block;
        font-size: 14px;
        font-weight: 500;
        color: #333;
        margin-bottom: 8px;
      }

      .fillm-modal-body textarea {
        width: 100%;
        min-height: 120px;
        padding: 12px;
        border: 1px solid #ddd;
        border-radius: 8px;
        font-size: 14px;
        font-family: inherit;
        resize: vertical;
        box-sizing: border-box;
      }

      .fillm-modal-body textarea:focus {
        outline: none;
        border-color: #4A90D9;
        box-shadow: 0 0 0 3px rgba(74, 144, 217, 0.1);
      }

      .fillm-modal-body textarea::placeholder {
        color: #999;
      }

      .fillm-modal-preview {
        margin-top: 16px;
        padding: 12px;
        background: #f5f5f5;
        border-radius: 8px;
        font-size: 13px;
        color: #666;
      }

      .fillm-modal-preview img {
        max-width: 100%;
        max-height: 150px;
        border-radius: 4px;
        margin-bottom: 8px;
      }

      .fillm-modal-footer {
        padding: 16px 24px;
        border-top: 1px solid #eee;
        display: flex;
        justify-content: flex-end;
        gap: 12px;
      }

      .fillm-btn {
        padding: 10px 20px;
        border-radius: 6px;
        font-size: 14px;
        font-weight: 500;
        cursor: pointer;
        border: none;
        transition: all 0.2s;
      }

      .fillm-btn-secondary {
        background: #f0f0f0;
        color: #333;
      }

      .fillm-btn-secondary:hover {
        background: #e0e0e0;
      }

      .fillm-btn-primary {
        background: #4A90D9;
        color: white;
      }

      .fillm-btn-primary:hover {
        background: #3a7bc0;
      }

      .fillm-btn-claude {
        background: #D97706;
        color: white;
      }

      .fillm-btn-claude:hover {
        background: #B45309;
      }

      .fillm-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      .fillm-modal-meta {
        font-size: 12px;
        color: #999;
        margin-top: 8px;
      }
    `;
    document.head.appendChild(this.styleElement);
  }

  /**
   * Remove styles
   */
  private removeStyles(): void {
    this.styleElement?.remove();
    this.styleElement = null;
  }

  /**
   * Create the modal DOM
   */
  private createModal(): void {
    this.modal = document.createElement('div');
    this.modal.className = 'fillm-modal-backdrop';

    const screenshotPreview = this.capture.screenshot
      ? `<img src="${this.capture.screenshot}" alt="Capture preview" />`
      : '';

    const metaInfo = [];
    if (this.capture.url) {
      try {
        metaInfo.push(new URL(this.capture.url).hostname);
      } catch {
        metaInfo.push(this.capture.url);
      }
    }
    if (this.options.captureSize) {
      metaInfo.push(this.options.captureSize);
    }

    this.modal.innerHTML = `
      <div class="fillm-modal">
        <div class="fillm-modal-header">
          <h2>Describe the Issue</h2>
          <p>Add a note to help explain what's wrong</p>
        </div>
        <div class="fillm-modal-body">
          <label for="fillm-note">What's the problem?</label>
          <textarea
            id="fillm-note"
            placeholder="E.g., Button doesn't respond to clicks, layout is broken on mobile, text is cut off..."
          ></textarea>
          ${screenshotPreview ? `
            <div class="fillm-modal-preview">
              ${screenshotPreview}
              ${metaInfo.length > 0 ? `<div class="fillm-modal-meta">${metaInfo.join(' • ')}</div>` : ''}
            </div>
          ` : ''}
        </div>
        <div class="fillm-modal-footer">
          <button class="fillm-btn fillm-btn-secondary" data-action="cancel">Cancel</button>
          <button class="fillm-btn fillm-btn-primary" data-action="download">Download ZIP</button>
          ${this.options.claudeEnabled ? `
            <button class="fillm-btn fillm-btn-claude" data-action="claude">Send to Claude</button>
          ` : ''}
        </div>
      </div>
    `;

    document.body.appendChild(this.modal);
  }

  /**
   * Remove the modal
   */
  private removeModal(): void {
    this.modal?.remove();
    this.modal = null;
  }

  /**
   * Attach event listeners
   */
  private attachEventListeners(): void {
    this.modal?.addEventListener('click', this.handleClick);
    document.addEventListener('keydown', this.handleKeyDown);
  }

  /**
   * Remove event listeners
   */
  private removeEventListeners(): void {
    this.modal?.removeEventListener('click', this.handleClick);
    document.removeEventListener('keydown', this.handleKeyDown);
  }

  /**
   * Get the note text from the textarea
   */
  private getNote(): string {
    const textarea = this.modal?.querySelector('textarea') as HTMLTextAreaElement | null;
    return textarea?.value.trim() || '';
  }

  /**
   * Build the complete capture result
   */
  private buildCaptureResult(): CaptureResult {
    return {
      version: '1.0',
      timestamp: new Date().toISOString(),
      url: this.capture.url || window.location.href,
      title: this.capture.title || document.title,
      viewport: this.capture.viewport || {
        width: window.innerWidth,
        height: window.innerHeight,
        scrollX: window.scrollX,
        scrollY: window.scrollY,
      },
      selection: this.capture.selection || {
        type: 'element',
        rect: { x: 0, y: 0, width: 0, height: 0 },
      },
      note: this.getNote(),
      screenshot: this.capture.screenshot || '',
      dom: this.capture.dom || [],
      styles: this.capture.styles || {},
    };
  }

  /**
   * Handle click events
   */
  private handleClick = (e: MouseEvent): void => {
    const target = e.target as HTMLElement;

    // Close if clicking backdrop
    if (target.classList.contains('fillm-modal-backdrop')) {
      this.hide();
      this.callbacks.onCancel();
      return;
    }

    // Handle button clicks
    const button = target.closest('[data-action]') as HTMLElement | null;
    if (!button) return;

    const action = button.dataset.action;

    if (action === 'cancel') {
      this.hide();
      this.callbacks.onCancel();
    } else if (action === 'download') {
      const capture = this.buildCaptureResult();
      this.hide();
      this.callbacks.onDownload(capture);
    } else if (action === 'claude') {
      const capture = this.buildCaptureResult();
      this.hide();
      this.callbacks.onSendToClaude(capture);
    }
  };

  /**
   * Handle keyboard events
   */
  private handleKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'Escape') {
      this.hide();
      this.callbacks.onCancel();
    } else if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      // Cmd/Ctrl+Enter to download
      const capture = this.buildCaptureResult();
      this.hide();
      this.callbacks.onDownload(capture);
    }
  };

  /**
   * Update the screenshot preview
   */
  updateScreenshot(screenshot: string): void {
    this.capture.screenshot = screenshot;
    const img = this.modal?.querySelector('.fillm-modal-preview img') as HTMLImageElement | null;
    if (img) {
      img.src = screenshot;
    }
  }
}

/**
 * Show the note modal
 */
export function showNoteModal(
  capture: Partial<CaptureResult>,
  callbacks: NoteModalCallbacks,
  options: NoteModalOptions
): NoteModal {
  const modal = new NoteModal(capture, callbacks, options);
  modal.show();
  return modal;
}
