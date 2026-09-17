# CLI Reference

Gleebook comes with built-in commands for scaffolding, building, and serving your documentation locally.

## Commands

### Initialize a Book
Scaffold a new `book/` directory with a default `SUMMARY.md` and index page:

```bash
gleam run -m gleebook init
```

### Build Static Site
Compile all Markdown pages into production-ready static HTML files inside build/gleebook/:

```bash
gleam run -m gleebook build
```

### Serve & Live Reload
Launch the local development server with active file watching and automatic browser refreshes:

```bash
# Default port (8000)
gleam run -m gleebook serve

# Custom port
gleam run -m gleebook serve --port=3000
```