/**
 * DOM extraction utilities for FIL(L)M
 * Extracts DOM structure and computed styles from selected elements
 */

import type {
  DOMNode,
  ComputedStylesMap,
  ExtractionOptions,
  Rect,
} from './types';
import { FILTERED_STYLE_PROPERTIES } from './types';

let nodeIdCounter = 0;

/**
 * Generate a unique node ID for style mapping
 */
function generateNodeId(): string {
  return `node-${++nodeIdCounter}`;
}

/**
 * Reset the node ID counter (useful for testing)
 */
export function resetNodeIdCounter(): void {
  nodeIdCounter = 0;
}

/**
 * Serialize a DOM element and its descendants to a plain object
 */
export function serializeElement(
  element: Element,
  options: ExtractionOptions = {},
  depth = 0
): DOMNode {
  const { maxDepth } = options;

  // Check depth limit
  if (maxDepth !== undefined && depth > maxDepth) {
    return {
      nodeType: element.nodeType,
      nodeId: generateNodeId(),
      tagName: element.tagName.toLowerCase(),
      textContent: '[max depth reached]',
    };
  }

  const nodeId = generateNodeId();
  const node: DOMNode = {
    nodeType: element.nodeType,
    nodeId,
    tagName: element.tagName.toLowerCase(),
  };

  // Extract attributes
  if (element.attributes.length > 0) {
    node.attributes = {};
    for (const attr of Array.from(element.attributes)) {
      node.attributes[attr.name] = attr.value;
    }
  }

  // Extract children
  const children: DOMNode[] = [];
  for (const child of Array.from(element.childNodes)) {
    if (child.nodeType === Node.ELEMENT_NODE) {
      children.push(serializeElement(child as Element, options, depth + 1));
    } else if (child.nodeType === Node.TEXT_NODE) {
      const text = child.textContent?.trim();
      if (text) {
        children.push({
          nodeType: Node.TEXT_NODE,
          nodeId: generateNodeId(),
          textContent: text,
        });
      }
    }
  }

  if (children.length > 0) {
    node.children = children;
  }

  return node;
}

/**
 * Extract computed styles for an element
 */
export function extractComputedStyles(
  element: Element,
  options: ExtractionOptions = {}
): Record<string, string> {
  const computed = window.getComputedStyle(element);
  const styles: Record<string, string> = {};

  const properties = options.styleProperties ??
    (options.includeStyles !== false ? FILTERED_STYLE_PROPERTIES : []);

  for (const prop of properties) {
    const value = computed.getPropertyValue(prop);
    if (value && value !== 'none' && value !== 'normal' && value !== 'auto') {
      styles[prop] = value;
    }
  }

  return styles;
}

/**
 * Extract computed styles for an element and all its descendants
 */
export function extractStylesRecursive(
  element: Element,
  domNode: DOMNode,
  options: ExtractionOptions = {}
): ComputedStylesMap {
  const stylesMap: ComputedStylesMap = {};

  // Extract styles for this element
  if (domNode.tagName) {
    stylesMap[domNode.nodeId] = extractComputedStyles(element, options);
  }

  // Recursively extract styles for children
  if (domNode.children) {
    const elementChildren = Array.from(element.children);
    let elementIndex = 0;

    for (const childNode of domNode.children) {
      if (childNode.tagName && elementIndex < elementChildren.length) {
        const childStyles = extractStylesRecursive(
          elementChildren[elementIndex],
          childNode,
          options
        );
        Object.assign(stylesMap, childStyles);
        elementIndex++;
      }
    }
  }

  return stylesMap;
}

/**
 * Get all elements that intersect with a given rectangle
 */
export function getElementsInRect(rect: Rect): Element[] {
  const elements: Element[] = [];
  const allElements = document.querySelectorAll('*');

  for (const element of Array.from(allElements)) {
    const bounds = element.getBoundingClientRect();

    // Check if element intersects with selection rect
    const intersects =
      bounds.left < rect.x + rect.width &&
      bounds.right > rect.x &&
      bounds.top < rect.y + rect.height &&
      bounds.bottom > rect.y;

    if (intersects) {
      // Only include if this is a leaf element or contains significant content
      const isLeaf = element.children.length === 0;
      const hasDirectText = Array.from(element.childNodes).some(
        (n) => n.nodeType === Node.TEXT_NODE && n.textContent?.trim()
      );

      if (isLeaf || hasDirectText) {
        elements.push(element);
      }
    }
  }

  return elements;
}

/**
 * Get the deepest element at a given point
 */
export function getElementAtPoint(x: number, y: number): Element | null {
  return document.elementFromPoint(x, y);
}

/**
 * Find the common ancestor of multiple elements
 */
export function findCommonAncestor(elements: Element[]): Element | null {
  if (elements.length === 0) return null;
  if (elements.length === 1) return elements[0];

  // Get all ancestors for the first element
  const getAncestors = (el: Element): Element[] => {
    const ancestors: Element[] = [];
    let current: Element | null = el;
    while (current) {
      ancestors.push(current);
      current = current.parentElement;
    }
    return ancestors;
  };

  const firstAncestors = getAncestors(elements[0]);

  // Find the first ancestor that contains all elements
  for (const ancestor of firstAncestors) {
    if (elements.every((el) => ancestor.contains(el))) {
      return ancestor;
    }
  }

  return document.body;
}

/**
 * Extract DOM and styles for selected elements
 */
export function extractCapture(
  elements: Element[],
  options: ExtractionOptions = {}
): { dom: DOMNode[]; styles: ComputedStylesMap } {
  resetNodeIdCounter();

  const dom: DOMNode[] = [];
  const styles: ComputedStylesMap = {};

  for (const element of elements) {
    const serialized = serializeElement(element, options);
    dom.push(serialized);

    if (options.includeStyles !== false) {
      const elementStyles = extractStylesRecursive(element, serialized, options);
      Object.assign(styles, elementStyles);
    }
  }

  return { dom, styles };
}

/**
 * Generate a CSS selector for an element
 */
export function generateSelector(element: Element): string {
  if (element.id) {
    return `#${element.id}`;
  }

  const parts: string[] = [];
  let current: Element | null = element;

  while (current && current !== document.body) {
    let selector = current.tagName.toLowerCase();

    if (current.id) {
      selector = `#${current.id}`;
      parts.unshift(selector);
      break;
    }

    if (current.className && typeof current.className === 'string') {
      const classes = current.className.trim().split(/\s+/).slice(0, 2);
      if (classes.length > 0 && classes[0]) {
        selector += `.${classes.join('.')}`;
      }
    }

    // Add nth-child if needed for uniqueness
    const parent = current.parentElement;
    if (parent) {
      const siblings = Array.from(parent.children).filter(
        (s) => s.tagName === current!.tagName
      );
      if (siblings.length > 1) {
        const index = siblings.indexOf(current) + 1;
        selector += `:nth-child(${index})`;
      }
    }

    parts.unshift(selector);
    current = current.parentElement;
  }

  return parts.join(' > ');
}
