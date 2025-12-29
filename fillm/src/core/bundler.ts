/**
 * Bundle creation utilities for FIL(L)M
 * Creates JSON and ZIP bundles from capture data
 */

import type { CaptureResult } from './types';

// Dynamic import for JSZip to handle environments where it might not be available
let JSZip: typeof import('jszip') | null = null;

async function loadJSZip(): Promise<typeof import('jszip')> {
  if (!JSZip) {
    JSZip = await import('jszip');
  }
  return JSZip;
}

/**
 * Current bundle format version
 */
export const BUNDLE_VERSION = '1.0';

/**
 * Create a capture result object with all required fields
 */
export function createCaptureResult(
  data: Omit<CaptureResult, 'version' | 'timestamp'>
): CaptureResult {
  return {
    version: BUNDLE_VERSION,
    timestamp: new Date().toISOString(),
    ...data,
  };
}

/**
 * Convert a CaptureResult to a JSON string
 */
export function toJSON(capture: CaptureResult): string {
  return JSON.stringify(capture, null, 2);
}

/**
 * Parse a JSON string to a CaptureResult
 */
export function fromJSON(json: string): CaptureResult {
  return JSON.parse(json) as CaptureResult;
}

/**
 * Extract the base64 image data from a data URL
 */
function extractBase64(dataUrl: string): string {
  const match = dataUrl.match(/^data:image\/\w+;base64,(.+)$/);
  return match ? match[1] : dataUrl;
}

/**
 * Convert base64 to binary array
 */
function base64ToBytes(base64: string): Uint8Array {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

/**
 * Create a ZIP bundle from capture data
 */
export async function createZipBundle(capture: CaptureResult): Promise<Blob> {
  const JSZipModule = await loadJSZip();
  const zip = new JSZipModule.default();

  // Create a copy without the screenshot for the JSON
  const jsonData: CaptureResult = {
    ...capture,
    screenshot: '[see screenshot.png]',
  };

  // Add JSON file
  zip.file('capture.json', JSON.stringify(jsonData, null, 2));

  // Add screenshot as separate file
  if (capture.screenshot) {
    const base64Data = extractBase64(capture.screenshot);
    const imageBytes = base64ToBytes(base64Data);
    zip.file('screenshot.png', imageBytes);
  }

  // Generate ZIP blob
  return zip.generateAsync({ type: 'blob' });
}

/**
 * Create a JSON-only bundle (includes base64 screenshot inline)
 */
export function createJSONBundle(capture: CaptureResult): Blob {
  const json = toJSON(capture);
  return new Blob([json], { type: 'application/json' });
}

/**
 * Generate a filename for the bundle
 */
export function generateFilename(capture: CaptureResult, extension: string): string {
  const date = new Date(capture.timestamp);
  const dateStr = date.toISOString().replace(/[:.]/g, '-').slice(0, 19);

  // Extract domain from URL
  let domain = 'unknown';
  try {
    domain = new URL(capture.url).hostname.replace(/[^a-zA-Z0-9]/g, '-');
  } catch {
    // Keep default
  }

  return `fillm-${domain}-${dateStr}.${extension}`;
}

/**
 * Trigger a download of a blob
 */
export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * Download capture as ZIP bundle
 */
export async function downloadAsZip(capture: CaptureResult): Promise<void> {
  const blob = await createZipBundle(capture);
  const filename = generateFilename(capture, 'zip');
  downloadBlob(blob, filename);
}

/**
 * Download capture as JSON bundle
 */
export function downloadAsJSON(capture: CaptureResult): void {
  const blob = createJSONBundle(capture);
  const filename = generateFilename(capture, 'json');
  downloadBlob(blob, filename);
}

/**
 * Get the size of a capture result in bytes (approximate)
 */
export function estimateSize(capture: CaptureResult): number {
  const json = toJSON(capture);
  return new Blob([json]).size;
}

/**
 * Format bytes to human readable string
 */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
