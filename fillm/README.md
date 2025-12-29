# FIL(L)M - Fix It, LLM

A browser extension for capturing web page issues and sending them to an LLM for analysis.

## Features

- **Keyboard shortcut activation** - Configurable shortcut (default: `Cmd/Ctrl+Shift+F`)
- **Click or drag selection** - Click on an element or drag to select a region
- **DOM capture** - Captures the selected element and its descendants
- **Computed styles** - Extracts all computed CSS styles
- **Screenshot** - Captures the visible viewport, cropped to selection
- **Notes** - Add a description of the issue before saving
- **Export** - Download as JSON/ZIP bundle
- **Claude integration** - Send captures directly to Claude for analysis

## Installation

### Chrome

1. Run `npm install && npm run build:chrome`
2. Open Chrome and go to `chrome://extensions/`
3. Enable "Developer mode"
4. Click "Load unpacked" and select `dist/chrome`

### Safari

1. Run `npm install && npm run build:safari`
2. Open the Xcode project in `src/safari/xcode/FillM`
3. Build and run the project
4. Enable the extension in Safari Preferences → Extensions

## Usage

1. Press `Cmd+Shift+F` (Mac) or `Ctrl+Shift+F` (Windows/Linux) to activate
2. Click on an element or drag to select a region
3. Add a note describing the issue
4. Click "Download" to save as ZIP or "Send to Claude" to analyze

## Development

```bash
# Install dependencies
npm install

# Build for Chrome (with watch)
npm run dev

# Build for Chrome
npm run build:chrome

# Build for Safari
npm run build:safari

# Build for both
npm run build
```

## Bundle Format

The exported ZIP contains:

- `capture.json` - Full capture data
- `screenshot.png` - Cropped screenshot

### JSON Structure

```json
{
  "version": "1.0",
  "timestamp": "2025-01-15T10:30:00Z",
  "url": "https://example.com/page",
  "viewport": { "width": 1920, "height": 1080 },
  "selection": {
    "type": "region",
    "rect": { "x": 100, "y": 200, "width": 400, "height": 300 }
  },
  "note": "Button doesn't respond to clicks",
  "screenshot": "base64...",
  "dom": { ... },
  "styles": { ... }
}
```

## License

MIT
