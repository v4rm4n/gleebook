# Markdown Test Suite

This page tests the full spectrum of standard Markdown elements, code syntax highlighting, and custom components within Gleebook.

## Text Formatting

You can write text in **bold**, _italic_, ~~strikethrough~~, or `inline code`. Here is a blockquote:

> Gleam is a type-safe, compiled language for building concurrent systems that scale.

---

## Code Highlighting

Supports a plethora of languages.

```gleam
import gleam/io

pub fn main() {
  io.println("Hello from Gleebook!")
}
```

```javascript
// Theme switcher helper
const theme = localStorage.getItem('gleebook-theme') || 'cyberpunk';
document.documentElement.setAttribute('data-theme', theme);
```

## Lists & Tables

- First item
- Second item
    - Nested sub-item
    - Another sub-item
- Third item

|Feature|Support|Mode|
|-|-|-|
|Live Reload|Yes|Local|
|Syntax Highlighting|Yes|Tokyonight|
|Static Build|Yes|HTML5|
