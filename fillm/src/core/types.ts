/**
 * Core type definitions for FIL(L)M browser extension
 */

/** Rectangle coordinates for selection region */
export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** Viewport dimensions */
export interface Viewport {
  width: number;
  height: number;
  scrollX: number;
  scrollY: number;
}

/** Selection type - either a single element click or a dragged region */
export type SelectionType = 'element' | 'region';

/** Selection result from the overlay */
export interface Selection {
  type: SelectionType;
  rect: Rect;
  /** Target element(s) at selection point/within region */
  elements: Element[];
}

/** Serialized DOM node structure */
export interface DOMNode {
  nodeType: number;
  tagName?: string;
  attributes?: Record<string, string>;
  textContent?: string;
  children?: DOMNode[];
  /** Unique identifier for style mapping */
  nodeId: string;
}

/** Computed styles for an element, keyed by nodeId */
export type ComputedStylesMap = Record<string, Record<string, string>>;

/** Complete capture result */
export interface CaptureResult {
  version: string;
  timestamp: string;
  url: string;
  title: string;
  viewport: Viewport;
  selection: {
    type: SelectionType;
    rect: Rect;
  };
  note: string;
  /** Base64 encoded PNG screenshot */
  screenshot: string;
  /** Serialized DOM tree of captured element(s) */
  dom: DOMNode[];
  /** Computed styles for all captured elements */
  styles: ComputedStylesMap;
}

/** Options for DOM extraction */
export interface ExtractionOptions {
  /** Include computed styles (default: true) */
  includeStyles?: boolean;
  /** Maximum depth to traverse (default: unlimited) */
  maxDepth?: number;
  /** CSS properties to capture (default: all) */
  styleProperties?: string[];
}

/** Extension settings stored in browser storage */
export interface ExtensionSettings {
  /** Claude API key */
  claudeApiKey?: string;
  /** Custom keyboard shortcut */
  keyboardShortcut: string;
  /** Default action after capture: 'download' | 'claude' | 'ask' */
  defaultAction: 'download' | 'claude' | 'ask';
  /** Include full computed styles or filtered set */
  fullStyles: boolean;
}

/** Default extension settings */
export const DEFAULT_SETTINGS: ExtensionSettings = {
  keyboardShortcut: 'Ctrl+Shift+F',
  defaultAction: 'ask',
  fullStyles: false,
};

/** Message types for extension communication */
export type MessageType =
  | 'ACTIVATE_SELECTION'
  | 'SELECTION_COMPLETE'
  | 'CAPTURE_SCREENSHOT'
  | 'SCREENSHOT_RESULT'
  | 'SEND_TO_CLAUDE'
  | 'CLAUDE_RESPONSE'
  | 'GET_SETTINGS'
  | 'SAVE_SETTINGS';

/** Base message structure */
export interface ExtensionMessage<T = unknown> {
  type: MessageType;
  payload?: T;
}

/** Screenshot request payload */
export interface ScreenshotRequest {
  rect?: Rect;
}

/** Screenshot response payload */
export interface ScreenshotResponse {
  screenshot: string;
  error?: string;
}

/** Selection complete payload */
export interface SelectionCompletePayload {
  selection: Selection;
  dom: DOMNode[];
  styles: ComputedStylesMap;
  note: string;
}

/** Claude API request payload */
export interface ClaudeRequestPayload {
  capture: CaptureResult;
  prompt?: string;
}

/** Claude API response payload */
export interface ClaudeResponsePayload {
  response: string;
  error?: string;
}

/** Filtered set of commonly useful CSS properties */
export const FILTERED_STYLE_PROPERTIES = [
  // Layout
  'display',
  'position',
  'top',
  'right',
  'bottom',
  'left',
  'float',
  'clear',
  'z-index',
  'overflow',
  'overflow-x',
  'overflow-y',

  // Box model
  'width',
  'height',
  'min-width',
  'min-height',
  'max-width',
  'max-height',
  'margin',
  'margin-top',
  'margin-right',
  'margin-bottom',
  'margin-left',
  'padding',
  'padding-top',
  'padding-right',
  'padding-bottom',
  'padding-left',
  'border',
  'border-width',
  'border-style',
  'border-color',
  'border-radius',
  'box-sizing',

  // Flexbox
  'flex',
  'flex-direction',
  'flex-wrap',
  'justify-content',
  'align-items',
  'align-content',
  'align-self',
  'flex-grow',
  'flex-shrink',
  'flex-basis',
  'gap',

  // Grid
  'grid-template-columns',
  'grid-template-rows',
  'grid-column',
  'grid-row',
  'grid-gap',

  // Typography
  'font-family',
  'font-size',
  'font-weight',
  'font-style',
  'line-height',
  'text-align',
  'text-decoration',
  'text-transform',
  'letter-spacing',
  'white-space',
  'word-wrap',
  'word-break',

  // Colors & backgrounds
  'color',
  'background',
  'background-color',
  'background-image',
  'background-position',
  'background-size',
  'background-repeat',
  'opacity',

  // Visual effects
  'box-shadow',
  'text-shadow',
  'transform',
  'transition',
  'visibility',
  'cursor',
  'pointer-events',
];
