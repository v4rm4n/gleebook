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

  // 1. Ensure target directory structure exists
  let assert Ok(_) = simplifile.create_directory_all("build/gleebook/assets")

  // 2. Copy assets so they live at build/gleebook/assets/
  let _ = simplifile.copy_directory("assets", "build/gleebook/assets")

  let mock_chapters = [
    Chapter("Introduction", "index.html", []),
    Chapter("Getting Started", "setup.html", []),
    Chapter("Advanced Gleam", "advanced.html", []),
  ]

  let initial_theme = layout.CyberpunkPink

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

  let page =
    layout.render_page(
      "Gleebook Preview",
      mock_chapters,
      mock_content,
      initial_theme,
    )

  let html_string = element.to_document_string(page)

  // 3. Write index.html right inside build/gleebook/
  let assert Ok(_) = simplifile.write("build/gleebook/index.html", html_string)

  success("Build complete! Open build/gleebook/index.html in your browser.")
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
