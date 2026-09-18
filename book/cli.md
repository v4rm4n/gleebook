# CLI Reference

Gleebook comes with built-in commands for scaffolding, building, and serving your documentation locally.

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

### As a Gleam dependency

If you already have a Gleam project, or want one to host the book, add Gleebook
and run it through `gleam run`:

```bash
gleam add gleebook@1
gleam run -m gleebook init
```

The commands below are written in this form. With the standalone release, replace
`gleam run -m gleebook` with `gleebook`.