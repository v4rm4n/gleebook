// src/gleebook/cli.gleam
import gleam/io
import gleam/list
import gleam/string
import gleam_community/ansi
import gleebook/markdown
import gleebook/parser
import gleebook_web/layout
import glint
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import simplifile

pub fn init() -> glint.Command(Nil) {
  use <- glint.command_help("Scaffold a new book directory")
  use _, _, _ <- glint.command()

  info("Initializing new book...")

  case do_init() {
    Ok(_) -> success("Created book/ directory with sample pages!")
    Error(_) -> error("Failed to initialize the book.")
  }
}

pub fn do_init() {
  let assert Ok(_) = simplifile.create_directory_all("book")
  let summary =
    "# Summary\n\n- [Introduction](index.md)\n- [Next Page](next_page.md)\n"
  let assert Ok(_) = simplifile.write(to: "book/SUMMARY.md", contents: summary)

  let index = "# Welcome\n\nThis is your first page.\n"
  let assert Ok(_) = simplifile.write(to: "book/index.md", contents: index)
}

pub fn build() -> glint.Command(Nil) {
  use <- glint.command_help("Compile the markdown book into static HTML")
  use _, _, _ <- glint.command()

  info("Building book...")

  let assert Ok(_) = simplifile.create_directory_all("build/gleebook/assets")
  let _ = simplifile.copy_directory("assets", "build/gleebook/assets")

  let summary_content = case simplifile.read("book/SUMMARY.md") {
    Ok(content) -> content
    Error(_) -> {
      error(
        "Could not read book/SUMMARY.md. Did you run `gleam run -m gleebook init`?",
      )
      panic
    }
  }

  let chapters = parser.parse_summary(summary_content)
  let initial_theme = layout.CyberpunkPink

  let has_errors =
    list.fold(chapters, False, fn(had_error, chapter) {
      let md_filename = string.replace(chapter.path, ".html", ".md")
      let source_path = "book/" <> md_filename

      let #(page_content, is_missing) = case simplifile.read(source_path) {
        Ok(content) -> #(content, False)
        Error(_) -> {
          error("Warning: Missing source file '" <> source_path <> "'")
          #("# 404\n\nPage `" <> md_filename <> "` not found.", True)
        }
      }

      let parsed_markdown = markdown.render(page_content)
      let dynamic_content = h.div([a.class("mt-4")], [parsed_markdown])

      let page =
        layout.render_page(
          chapter.title <> " - Gleebook",
          chapters,
          chapter.path,
          dynamic_content,
          initial_theme,
        )

      let html_string = element.to_document_string(page)
      let out_path = "build/gleebook/" <> chapter.path

      case simplifile.write(out_path, html_string) {
        Ok(_) -> {
          info("Compiled " <> out_path)
          had_error || is_missing
        }
        Error(_) -> {
          error(
            "Markdown routing failed: Invalid link target for '"
            <> chapter.title
            <> "' -> "
            <> out_path,
          )
          True
        }
      }
    })

  case has_errors {
    True -> error("Build completed with errors. Check the logs above.")
    False ->
      success("Build complete! Open build/gleebook/index.html in your browser.")
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
