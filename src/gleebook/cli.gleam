// src/gleebook/cli.gleam

import gleam/io
import gleam_community/ansi
import glint
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

  let summary_result = simplifile.read(from: "book/SUMMARY.md")

  case summary_result {
    Ok(_markdown) -> {
      success("Found SUMMARY.md! Ready to parse.")
      // TODO: Parse the chapters!
    }
    Error(_) -> {
      error("Could not find book/SUMMARY.md. Did you run `gleebook init`?")
    }
  }
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
