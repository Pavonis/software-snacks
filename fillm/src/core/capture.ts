/**
 * Screenshot capture and cropping utilities for FIL(L)M
 */

import type { Rect, Viewport } from './types';

/**
 * Get current viewport information
 */
export function getViewport(): Viewport {
  return {
    width: window.innerWidth,
    height: window.innerHeight,
    scrollX: window.scrollX,
    scrollY: window.scrollY,
  };
}

/**
 * Crop a base64 image to the specified rectangle
 * Returns a promise that resolves to the cropped base64 image
 */
export async function cropScreenshot(
  base64Image: string,
  rect: Rect,
  viewport: Viewport
): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();

    img.onload = () => {
      try {
        // Calculate scale factor (screenshot might be at device pixel ratio)
        const scaleX = img.width / viewport.width;
        const scaleY = img.height / viewport.height;

        // Create canvas for cropping
        const canvas = document.createElement('canvas');
        canvas.width = rect.width * scaleX;
        canvas.height = rect.height * scaleY;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('Failed to get canvas context'));
          return;
        }

        // Draw cropped region
        ctx.drawImage(
          img,
          rect.x * scaleX,
          rect.y * scaleY,
          rect.width * scaleX,
          rect.height * scaleY,
          0,
          0,
          canvas.width,
          canvas.height
        );

        // Export as base64
        const croppedBase64 = canvas.toDataURL('image/png');
        resolve(croppedBase64);
      } catch (error) {
        reject(error);
      }
    };

    img.onerror = () => {
      reject(new Error('Failed to load screenshot image'));
    };

    // Handle base64 with or without data URL prefix
    if (base64Image.startsWith('data:')) {
      img.src = base64Image;
    } else {
      img.src = `data:image/png;base64,${base64Image}`;
    }
  });
}

/**
 * Calculate the bounding rectangle for an element
 */
export function getElementRect(element: Element): Rect {
  const bounds = element.getBoundingClientRect();
  return {
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  };
}

/**
 * Calculate the bounding rectangle that encompasses all given elements
 */
export function getCombinedRect(elements: Element[]): Rect {
  if (elements.length === 0) {
    return { x: 0, y: 0, width: 0, height: 0 };
  }

  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;

  for (const element of elements) {
    const bounds = element.getBoundingClientRect();
    minX = Math.min(minX, bounds.left);
    minY = Math.min(minY, bounds.top);
    maxX = Math.max(maxX, bounds.right);
    maxY = Math.max(maxY, bounds.bottom);
  }

  return {
    x: minX,
    y: minY,
    width: maxX - minX,
    height: maxY - minY,
  };
}

/**
 * Clamp a rectangle to the viewport bounds
 */
export function clampToViewport(rect: Rect, viewport: Viewport): Rect {
  const x = Math.max(0, Math.min(rect.x, viewport.width));
  const y = Math.max(0, Math.min(rect.y, viewport.height));
  const width = Math.min(rect.width, viewport.width - x);
  const height = Math.min(rect.height, viewport.height - y);

  return { x, y, width, height };
}

/**
 * Add padding to a rectangle
 */
export function padRect(rect: Rect, padding: number): Rect {
  return {
    x: rect.x - padding,
    y: rect.y - padding,
    width: rect.width + padding * 2,
    height: rect.height + padding * 2,
  };
}

/**
 * Check if a rectangle has valid dimensions
 */
export function isValidRect(rect: Rect): boolean {
  return rect.width > 0 && rect.height > 0;
}

/**
 * Convert a rectangle from page coordinates to viewport coordinates
 */
export function pageToViewportRect(rect: Rect, viewport: Viewport): Rect {
  return {
    x: rect.x - viewport.scrollX,
    y: rect.y - viewport.scrollY,
    width: rect.width,
    height: rect.height,
  };
}

/**
 * Convert a rectangle from viewport coordinates to page coordinates
 */
export function viewportToPageRect(rect: Rect, viewport: Viewport): Rect {
  return {
    x: rect.x + viewport.scrollX,
    y: rect.y + viewport.scrollY,
    width: rect.width,
    height: rect.height,
  };
}
