/**
 * Claude API integration for FIL(L)M
 * Sends captured bug reports to Claude for analysis
 */

import type { CaptureResult } from './types';

/**
 * Claude API configuration
 */
export interface ClaudeConfig {
  apiKey: string;
  model?: string;
  maxTokens?: number;
}

/**
 * Default Claude configuration
 */
const DEFAULT_CONFIG: Partial<ClaudeConfig> = {
  model: 'claude-sonnet-4-20250514',
  maxTokens: 4096,
};

/**
 * System prompt for bug analysis
 */
const SYSTEM_PROMPT = `You are a helpful web development assistant analyzing a bug report captured from a website.
You will receive:
1. A screenshot of the affected area
2. The DOM structure of the affected elements
3. Computed CSS styles for those elements
4. A user's note describing the issue

Analyze the information and provide:
1. A summary of the likely issue
2. Potential causes based on the DOM/CSS
3. Suggested fixes or debugging steps
4. Any patterns or anti-patterns you notice

Be concise but thorough. Focus on actionable insights.`;

/**
 * Format capture data for Claude API
 */
function formatCaptureForClaude(capture: CaptureResult): string {
  const parts: string[] = [];

  parts.push(`## Page Information`);
  parts.push(`- URL: ${capture.url}`);
  parts.push(`- Title: ${capture.title}`);
  parts.push(`- Captured: ${capture.timestamp}`);
  parts.push(`- Viewport: ${capture.viewport.width}x${capture.viewport.height}`);
  parts.push('');

  parts.push(`## User's Note`);
  parts.push(capture.note || '(No note provided)');
  parts.push('');

  parts.push(`## Selection`);
  parts.push(`- Type: ${capture.selection.type}`);
  parts.push(`- Region: x=${capture.selection.rect.x}, y=${capture.selection.rect.y}, ` +
    `width=${capture.selection.rect.width}, height=${capture.selection.rect.height}`);
  parts.push('');

  parts.push(`## DOM Structure`);
  parts.push('```json');
  parts.push(JSON.stringify(capture.dom, null, 2));
  parts.push('```');
  parts.push('');

  parts.push(`## Computed Styles`);
  parts.push('```json');
  parts.push(JSON.stringify(capture.styles, null, 2));
  parts.push('```');

  return parts.join('\n');
}

/**
 * Extract base64 image data for Claude vision
 */
function extractImageData(screenshot: string): { type: 'base64'; media_type: string; data: string } {
  // Handle data URL format
  const match = screenshot.match(/^data:image\/(\w+);base64,(.+)$/);
  if (match) {
    return {
      type: 'base64',
      media_type: `image/${match[1]}`,
      data: match[2],
    };
  }

  // Assume raw base64 PNG
  return {
    type: 'base64',
    media_type: 'image/png',
    data: screenshot,
  };
}

/**
 * Send a capture to Claude API for analysis
 */
export async function analyzeCaptureWithClaude(
  capture: CaptureResult,
  config: ClaudeConfig,
  userPrompt?: string
): Promise<string> {
  const { apiKey, model = DEFAULT_CONFIG.model, maxTokens = DEFAULT_CONFIG.maxTokens } = config;

  if (!apiKey) {
    throw new Error('Claude API key is required');
  }

  const textContent = formatCaptureForClaude(capture);
  const imageData = extractImageData(capture.screenshot);

  // Build the message content
  const content: Array<
    | { type: 'image'; source: { type: 'base64'; media_type: string; data: string } }
    | { type: 'text'; text: string }
  > = [
    {
      type: 'image',
      source: imageData,
    },
    {
      type: 'text',
      text: textContent,
    },
  ];

  if (userPrompt) {
    content.push({
      type: 'text',
      text: `\n## Additional Context from User\n${userPrompt}`,
    });
  }

  const requestBody = {
    model,
    max_tokens: maxTokens,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: 'user',
        content,
      },
    ],
  };

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Claude API error: ${response.status} - ${errorText}`);
  }

  const result = await response.json();

  // Extract text from response
  const textBlocks = result.content?.filter(
    (block: { type: string }) => block.type === 'text'
  );

  if (!textBlocks || textBlocks.length === 0) {
    throw new Error('No text response from Claude');
  }

  return textBlocks.map((block: { text: string }) => block.text).join('\n');
}

/**
 * Validate a Claude API key by making a minimal request
 */
export async function validateApiKey(apiKey: string): Promise<boolean> {
  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1,
        messages: [{ role: 'user', content: 'Hi' }],
      }),
    });

    // 200 or 400 (bad request but valid key) are acceptable
    // 401 means invalid key
    return response.status !== 401;
  } catch {
    return false;
  }
}
