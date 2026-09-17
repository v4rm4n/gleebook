// src/gleebook/cli.gleam

import gleam/io
import gleam_community/ansi
import gleebook/core.{Chapter}
import gleebook_web/components
import gleebook_web/layout
import glint
import lustre/element
import lustre/element/html as h
import simplifile

pub fn init() -> glint.Command(Nil) {
  use <- glint.command_help("Scaffold a new book directory")
  use _, _, _ <- glint.command()

  info("Initializing new book...")

  // Call the core logic
  case do_init() {
    Ok(_) -> success("Created book/ directory, SUMMARY.md, and index.md!")
    Error(_) -> error("Failed to initialize the book.")
  }
}

pub fn do_init() {
  let assert Ok(_) = simplifile.create_directory_all("book")

  let summary = "# Summary\n\n- [Introduction](index.md)\n"
  let assert Ok(_) = simplifile.write(to: "book/SUMMARY.md", contents: summary)

  let index = "# Welcome\n\nThis is your first page.\n"
  simplifile.write(to: "book/index.md", contents: index)
}

pub fn build() -> glint.Command(Nil) {
  use <- glint.command_help("Compile the markdown book into static HTML")
  use _, _, _ <- glint.command()

  info("Building book...")

  // 1. Setup build directory
  let assert Ok(_) = simplifile.create_directory_all("build")

  // 2. Create mock chapters to see the sidebar in action
  let mock_chapters = [
    Chapter("Introduction", "index.html", []),
    Chapter("Getting Started", "setup.html", []),
    Chapter("Advanced Gleam", "advanced.html", []),
  ]

  // Default initial theme (user can toggle in browser via sidebar button)
  let initial_theme = layout.CyberpunkPink

  // 3. Components now style themselves dynamically via CSS data-theme!
  let mock_content =
    h.div([], [
      h.h1([], [h.text("Welcome to Gleebook")]),
      h.p([], [
        h.text(
          "This is what your beautifully rendered markdown will look like.",
        ),
      ]),

      components.callout(
        "Pro Tip: You can build beautiful reusable UI components in Lustre!",
      ),

      components.code_block(
        "gleam",
        "pub fn main() {\n  io.println(\"Hello, contour!\")\n}",
      ),

      components.code_block("bash", "gleam run -m gleebook build"),
    ])

  // 4. Render layout with default theme
  let page =
    layout.render_page(
      "Gleebook Preview",
      mock_chapters,
      mock_content,
      initial_theme,
    )

  // 5. Convert Lustre elements to an HTML string
  let html_string = element.to_document_string(page)

  // 6. Write it to disk
  let assert Ok(_) = simplifile.write("build/index.html", html_string)

  success("Build complete! Open build/index.html in your browser.")
}

pub fn info(message: String) {
  io.println(ansi.blue("▶ ") <> message)
}

pub fn success(message: String) {
  io.println(ansi.green("✔ " <> message))
}

pub fn error(message: String) {
  io.println(ansi.red("✖ " <> message))
}
