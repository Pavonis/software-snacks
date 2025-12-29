/**
 * Selection overlay for FIL(L)M
 * Handles click and drag-to-select interactions
 */

import type { Rect, Selection, SelectionType } from '../core/types';
import { getElementAtPoint, getElementsInRect } from '../core/dom-extractor';

export interface SelectionOverlayCallbacks {
  onSelectionComplete: (selection: Selection) => void;
  onCancel: () => void;
}

/**
 * Selection overlay manager
 * Creates a full-page overlay for selecting elements or regions
 */
export class SelectionOverlay {
  private overlay: HTMLDivElement | null = null;
  private selectionBox: HTMLDivElement | null = null;
  private highlightBox: HTMLDivElement | null = null;
  private instructionBox: HTMLDivElement | null = null;

  private isDragging = false;
  private startX = 0;
  private startY = 0;
  private currentX = 0;
  private currentY = 0;

  private callbacks: SelectionOverlayCallbacks;
  private styleElement: HTMLStyleElement | null = null;

  constructor(callbacks: SelectionOverlayCallbacks) {
    this.callbacks = callbacks;
  }

  /**
   * Activate the selection overlay
   */
  activate(): void {
    if (this.overlay) {
      return; // Already active
    }

    this.injectStyles();
    this.createOverlay();
    this.attachEventListeners();
  }

  /**
   * Deactivate and remove the selection overlay
   */
  deactivate(): void {
    this.removeEventListeners();
    this.removeOverlay();
    this.removeStyles();
  }

  /**
   * Inject CSS styles for the overlay
   */
  private injectStyles(): void {
    if (this.styleElement) return;

    this.styleElement = document.createElement('style');
    this.styleElement.textContent = `
      .fillm-overlay {
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        z-index: 2147483647;
        cursor: crosshair;
        background: rgba(0, 0, 0, 0.1);
      }

      .fillm-selection-box {
        position: fixed;
        border: 2px dashed #4A90D9;
        background: rgba(74, 144, 217, 0.1);
        pointer-events: none;
        z-index: 2147483647;
      }

      .fillm-highlight-box {
        position: fixed;
        border: 2px solid #FF6B6B;
        background: rgba(255, 107, 107, 0.1);
        pointer-events: none;
        z-index: 2147483646;
        transition: all 0.1s ease-out;
      }

      .fillm-instruction-box {
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        background: rgba(0, 0, 0, 0.85);
        color: white;
        padding: 12px 24px;
        border-radius: 8px;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 14px;
        z-index: 2147483647;
        pointer-events: none;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      }

      .fillm-instruction-box kbd {
        background: rgba(255, 255, 255, 0.2);
        padding: 2px 6px;
        border-radius: 4px;
        margin: 0 4px;
      }
    `;
    document.head.appendChild(this.styleElement);
  }

  /**
   * Remove injected styles
   */
  private removeStyles(): void {
    if (this.styleElement) {
      this.styleElement.remove();
      this.styleElement = null;
    }
  }

  /**
   * Create the overlay element
   */
  private createOverlay(): void {
    // Main overlay
    this.overlay = document.createElement('div');
    this.overlay.className = 'fillm-overlay';

    // Selection box (shown during drag)
    this.selectionBox = document.createElement('div');
    this.selectionBox.className = 'fillm-selection-box';
    this.selectionBox.style.display = 'none';

    // Highlight box (shown on hover)
    this.highlightBox = document.createElement('div');
    this.highlightBox.className = 'fillm-highlight-box';
    this.highlightBox.style.display = 'none';

    // Instruction box
    this.instructionBox = document.createElement('div');
    this.instructionBox.className = 'fillm-instruction-box';
    this.instructionBox.innerHTML = 'Click an element or drag to select a region. Press <kbd>Esc</kbd> to cancel.';

    document.body.appendChild(this.overlay);
    document.body.appendChild(this.selectionBox);
    document.body.appendChild(this.highlightBox);
    document.body.appendChild(this.instructionBox);
  }

  /**
   * Remove the overlay elements
   */
  private removeOverlay(): void {
    this.overlay?.remove();
    this.selectionBox?.remove();
    this.highlightBox?.remove();
    this.instructionBox?.remove();

    this.overlay = null;
    this.selectionBox = null;
    this.highlightBox = null;
    this.instructionBox = null;
  }

  /**
   * Attach event listeners
   */
  private attachEventListeners(): void {
    this.overlay?.addEventListener('mousedown', this.handleMouseDown);
    this.overlay?.addEventListener('mousemove', this.handleMouseMove);
    this.overlay?.addEventListener('mouseup', this.handleMouseUp);
    document.addEventListener('keydown', this.handleKeyDown);
  }

  /**
   * Remove event listeners
   */
  private removeEventListeners(): void {
    this.overlay?.removeEventListener('mousedown', this.handleMouseDown);
    this.overlay?.removeEventListener('mousemove', this.handleMouseMove);
    this.overlay?.removeEventListener('mouseup', this.handleMouseUp);
    document.removeEventListener('keydown', this.handleKeyDown);
  }

  /**
   * Handle mouse down - start selection
   */
  private handleMouseDown = (e: MouseEvent): void => {
    e.preventDefault();
    e.stopPropagation();

    this.isDragging = true;
    this.startX = e.clientX;
    this.startY = e.clientY;
    this.currentX = e.clientX;
    this.currentY = e.clientY;

    if (this.selectionBox) {
      this.selectionBox.style.display = 'block';
      this.updateSelectionBox();
    }

    // Hide highlight during drag
    if (this.highlightBox) {
      this.highlightBox.style.display = 'none';
    }
  };

  /**
   * Handle mouse move - update selection or highlight
   */
  private handleMouseMove = (e: MouseEvent): void => {
    if (this.isDragging) {
      this.currentX = e.clientX;
      this.currentY = e.clientY;
      this.updateSelectionBox();
    } else {
      // Highlight element under cursor
      this.updateHighlight(e.clientX, e.clientY);
    }
  };

  /**
   * Handle mouse up - complete selection
   */
  private handleMouseUp = (e: MouseEvent): void => {
    if (!this.isDragging) return;

    e.preventDefault();
    e.stopPropagation();

    this.isDragging = false;

    const rect = this.getSelectionRect();
    const isDrag = rect.width > 5 || rect.height > 5;

    let selection: Selection;

    if (isDrag) {
      // Drag selection - get all elements in the region
      const elements = getElementsInRect(rect);
      selection = {
        type: 'region' as SelectionType,
        rect,
        elements,
      };
    } else {
      // Click selection - get element at point
      // Temporarily hide overlay to get element underneath
      if (this.overlay) this.overlay.style.pointerEvents = 'none';
      const element = getElementAtPoint(e.clientX, e.clientY);
      if (this.overlay) this.overlay.style.pointerEvents = 'auto';

      if (element) {
        const bounds = element.getBoundingClientRect();
        selection = {
          type: 'element' as SelectionType,
          rect: {
            x: bounds.left,
            y: bounds.top,
            width: bounds.width,
            height: bounds.height,
          },
          elements: [element],
        };
      } else {
        // No element found, cancel
        this.deactivate();
        this.callbacks.onCancel();
        return;
      }
    }

    this.deactivate();
    this.callbacks.onSelectionComplete(selection);
  };

  /**
   * Handle keyboard events
   */
  private handleKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'Escape') {
      this.deactivate();
      this.callbacks.onCancel();
    }
  };

  /**
   * Update the selection box position and size
   */
  private updateSelectionBox(): void {
    if (!this.selectionBox) return;

    const rect = this.getSelectionRect();
    this.selectionBox.style.left = `${rect.x}px`;
    this.selectionBox.style.top = `${rect.y}px`;
    this.selectionBox.style.width = `${rect.width}px`;
    this.selectionBox.style.height = `${rect.height}px`;
  }

  /**
   * Update element highlight on hover
   */
  private updateHighlight(x: number, y: number): void {
    if (!this.highlightBox || !this.overlay) return;

    // Temporarily hide overlay to get element underneath
    this.overlay.style.pointerEvents = 'none';
    const element = getElementAtPoint(x, y);
    this.overlay.style.pointerEvents = 'auto';

    if (element && element !== document.body && element !== document.documentElement) {
      const bounds = element.getBoundingClientRect();
      this.highlightBox.style.display = 'block';
      this.highlightBox.style.left = `${bounds.left}px`;
      this.highlightBox.style.top = `${bounds.top}px`;
      this.highlightBox.style.width = `${bounds.width}px`;
      this.highlightBox.style.height = `${bounds.height}px`;
    } else {
      this.highlightBox.style.display = 'none';
    }
  }

  /**
   * Get the current selection rectangle
   */
  private getSelectionRect(): Rect {
    const x = Math.min(this.startX, this.currentX);
    const y = Math.min(this.startY, this.currentY);
    const width = Math.abs(this.currentX - this.startX);
    const height = Math.abs(this.currentY - this.startY);

    return { x, y, width, height };
  }
}

/**
 * Create and activate a selection overlay
 */
export function activateSelection(callbacks: SelectionOverlayCallbacks): SelectionOverlay {
  const overlay = new SelectionOverlay(callbacks);
  overlay.activate();
  return overlay;
}
