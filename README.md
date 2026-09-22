# gleebook

[![Package Version](https://img.shields.io/hexpm/v/gleebook)](https://hex.pm/packages/gleebook)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://gleebook.hexdocs.pm/)

A fast, zero-config static site generator for books and documentation, written in Gleam. Point it at a folder of Markdown files and a `SUMMARY.md`, and it builds a themed, searchable-by-eye site with a collapsible sidebar, syntax highlighting and live reload — in the spirit of mdBook, but built on Lustre, Wisp and Mist.

## Demo-projects

[gleebook](https://v4rm4n.github.io/gleebook/) (This project!)
[my personal static website](https://v4rm4n.github.io/)

## Features

- **Asset embeds** - Any images/videos will be automatically scanned for and rendered when `![alt](source)` is used!
- **Type-safe generation** — every page is rendered through Lustre's typed element tree; there is no string templating.
- **Instant watcher & live reload** — `serve` rebuilds when a file in `book/` changes and the browser reloads itself.
- **Collapsible, resizable sidebar** — nested chapters use native `<details>` accordions; width and collapsed state are remembered per browser.
- **Two themes out of the box** — *Cyberpunk Pink* (dark) and *Rust Olive* (light), with a toggle in the sidebar and a `?theme=` URL parameter.
- **CommonMark + GFM Markdown** — tables, strikethrough, task lists and footnotes are supported.
- **Code blocks with a copy button** — Gleam is highlighted natively via `contour`; every other language goes through highlight.js.
- **Callouts and embeds** — blockquotes render as accented callouts, and a YouTube link in image syntax becomes a privacy-friendly embed.
- **Safe by default** — raw HTML in Markdown is never emitted into the page.
- **Plain static output** — the result is a folder of HTML you can host anywhere.

## Installation

### Standalone release (no Gleam toolchain required)

Every [GitHub release](https://github.com/v4rm4n/gleebook/releases) ships a prebuilt
`gleebook` binary (currently only for linux-amd64).No Gleam compiler and no host project needed.

```bash
# Download the latest release and make it executable
# Download release from https://github.com/v4rm4n/gleebook/releases/tag/v0.1.1
chmod +x gleebook

# Optional: put it on your PATH
mv gleebook ~/.local/bin/
```

Then run it from the directory that contains (or will contain) your `book/` folder:

```bash
gleebook init
gleebook serve --port=3000
gleebook build
```

On Windows, run it through the Erlang launcher instead: `escript gleebook build`.

### As a Gleam dependency

If you already have a Gleam project, or want one to host the book, add Gleebook
and run it through `gleam run`:

```bash
gleam add gleebook@1
gleam run -m gleebook init
```

The commands below are written in this form. With the standalone release, replace
`gleam run -m gleebook` with `gleebook`.


## Writing your book

### `book/SUMMARY.md`

The summary defines the book title and the sidebar. The first level-one heading is the title; each list item is a chapter, and indenting by two spaces nests it under the item above.

```markdown
# My Book

- [Introduction](index.md)
- [Getting Started](getting-started.md)
  - [Installation](getting-started/installation.md)
  - [First Steps](getting-started/first-steps.md)
- [Reference]()
  - [CLI](reference/cli.md)
  - [Configuration](reference/config.md)
```

An entry with an empty link, like `[Reference]()`, is a label-only group: it appears in the sidebar as a heading for its children but has no page of its own. Chapters can live in subdirectories; the output mirrors the same structure.

Links between pages are written with the `.md` extension (so they work in your editor and on GitHub) and are rewritten to `.html` at build time.

### Markdown support

| Syntax | Result |
| --- | --- |
| `**bold**`, `*italic*`, `~~strike~~`, `` `code` `` | Inline formatting |
| `# … ######` | Headings |
| `- item` / `1. item` | Bullet and ordered lists, nested by indentation |
| `- [ ] task` / `- [x] done` | Task lists |
| `> note` | Rendered as an accented callout box |
| `\| a \| b \|` with a `\| - \| - \|` row | Tables (`:-:` centre, `-:` right) |
| `[^1]` and `[^1]: …` | Footnotes, collected at the end of the page |
| `![alt](image.png)` | Images |
| `![title](https://youtu.be/…)` | Embedded YouTube player |
| ` ```gleam ` | Highlighted code block with a copy button |
| `---` | Thematic break |

Raw HTML blocks are replaced with a warning in the rendered page rather than being passed through.

## Theming

The sidebar toggle switches between the two built-in themes and remembers the choice in `localStorage`. You can also force a theme with a query parameter, which is preserved as you navigate:

```
index.html?theme=cyberpunk
index.html?theme=olive
```

To customise colours, create `book/custom.css`. It is copied into the build and loaded after the built-in styles, so you can override any of the theme variables:

```css
[data-theme='cyberpunk'] {
  --gb-bg: #0b0b12;
  --gb-accent: #7dd3fc;
}

[data-theme='olive'] {
  --gb-accent: #b45309;
}
```

Variables available on both themes:

| Variable | Purpose |
| --- | --- |
| `--gb-bg`, `--gb-text` | Page background and body text |
| `--gb-sidebar`, `--gb-border` | Sidebar background and borders |
| `--gb-accent` | Brand colour, links, active nav item |
| `--gb-nav-text`, `--gb-nav-hover`, `--gb-nav-active` | Sidebar link states |
| `--gb-code-bg`, `--gb-code-bar`, `--gb-code-bar-text` | Code block body and title bar |
| `--gb-callout` | Callout background |
| `--gb-syn-keyword`, `--gb-syn-func`, `--gb-syn-string`, `--gb-syn-num`, `--gb-syn-comment`, `--gb-syn-punct` | Syntax highlighting palette |

Any other CSS works too — the content column carries the `gleebook-prose` class, so `.gleebook-prose h2 { … }` is a safe hook.

## Project layout

```
my_book/
├── gleam.toml
├── assets/              # static files, copied to build/gleebook/assets/
├── book/
│   ├── SUMMARY.md       # title + sidebar structure
│   ├── custom.css       # optional theme overrides
│   ├── index.md
│   └── ...
└── build/
    └── gleebook/        # generated site (git-ignore this)
        ├── index.html
        ├── assets/
        └── ...
```

## Deploying

`build/gleebook/` is a self-contained static site. Deploy it like any other: GitHub Pages, Netlify, Cloudflare Pages, an S3 bucket, or a plain web server. Links are relative, so the site works from a sub-path as well as from a domain root.

## CLI reference

| Command | Description |
| --- | --- |
| `gleam run -m gleebook init` | Create `book/` with a starter `SUMMARY.md` and `index.md` |
| `gleam run -m gleebook build` | Compile the book into `build/gleebook/` |
| `gleam run -m gleebook serve [--port N]` | Build, then serve locally with file watching and live reload (default port 8000) |

`build` exits with an error summary if any chapter listed in `SUMMARY.md` has no matching Markdown file; a placeholder 404 page is generated in its place so the rest of the site still builds.

## Requirements

- Gleam 1.13 or later
- Erlang/OTP 28 or later

## Development

```sh
gleam build            # Build the project
gleam test             # Run the tests
gleam run -m gleebook serve   # Dogfood the docs in ./book
```

Further documentation can be found at <https://gleebook.hexdocs.pm/>.

## Licence

Apache-2.0 — see [LICENSE](LICENSE).
