# Custom Theming

Place this optional file inside your `book/` directory to get your own theme overrides. 

Gleebook will automatically pick it up during the build process:

```css
/* custom.css */
/* This replaces the Lucy (Dark) Theme */
[data-theme='cyberpunk'] {
  --gb-bg: #282a36;
  --gb-text: #f8f8f2;
  --gb-sidebar: #44475a;
  --gb-border: #6272a4;
  --gb-accent: #ff79c6;
  --gb-nav-text: #f8f8f2;
  --gb-nav-hover: rgba(255, 121, 198, 0.1);
  --gb-nav-active: rgba(255, 121, 198, 0.2);
  --gb-code-bg: #21222c;
  --gb-code-bar: #191a21;
  --gb-callout: rgba(255, 121, 198, 0.1);
}

/* This replaces the Olive (Light) Theme */
[data-theme='olive'] {
  --gb-bg: #fdf6e3;
  --gb-text: #657b83;
  --gb-sidebar: #eee8d5;
  --gb-border: #93a1a1;
  --gb-accent: #268bd2;
  --gb-nav-text: #586e75;
  --gb-nav-hover: #e8dfcb;
  --gb-nav-active: #d6ccb5;
  --gb-code-bg: #fdf6e3;
  --gb-code-bar: #eee8d5;
  --gb-callout: #eee8d5;
}

/* Optional: They can hide Lucy if it doesn't match their new vibe */
.theme-lucies { display: none !important; }
```