// src/gleebook/cli.gleam
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam_community/ansi
import gleebook/core
import gleebook/markdown
import gleebook/parser
import gleebook_web/layout
import glint
import lustre/attribute as a
import lustre/element
import lustre/element/html as h
import mist
import simplifile
import wisp
import wisp/wisp_mist

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

  // Safely copy custom.css ONLY if the user has actually created it
  case simplifile.is_file("book/custom.css") {
    Ok(True) -> {
      let _ =
        simplifile.copy_file("book/custom.css", "build/gleebook/custom.css")
      info("Included custom.css theme overrides.")
    }
    _ -> Nil
  }

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

  // Flatten the tree so we iterate over every single chapter regardless of depth
  let all_chapters = flatten_chapters(chapters)

  let has_errors =
    list.fold(all_chapters, False, fn(had_error, chapter) {
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

      // Find neighbors from the flattened list
      let #(prev_chap, next_chap) =
        find_neighbors(all_chapters, chapter.path, None)

      let page =
        layout.render_page(
          chapter.title <> " - Gleebook",
          chapters,
          chapter.path,
          dynamic_content,
          initial_theme,
          prev_chap,
          next_chap,
        )

      let html_string = element.to_document_string(page)
      let out_path = "build/gleebook/" <> chapter.path

      // --- NEW: Create the nested target directories dynamically ---
      let target_dir =
        out_path
        |> string.split("/")
        |> list.reverse
        |> list.drop(1)
        |> list.reverse
        |> string.join("/")

      let _ = simplifile.create_directory_all(target_dir)
      // -----------------------------------------------------------

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

fn flatten_chapters(chapters: List(core.Chapter)) -> List(core.Chapter) {
  list.flat_map(chapters, fn(c) { [c, ..flatten_chapters(c.children)] })
}

fn find_neighbors(
  chapters: List(core.Chapter),
  target_path: String,
  prev: Option(core.Chapter),
) -> #(Option(core.Chapter), Option(core.Chapter)) {
  case chapters {
    [] -> #(None, None)
    [c, next, ..] if c.path == target_path -> #(prev, Some(next))
    [c] if c.path == target_path -> #(prev, None)
    [c, ..rest] -> find_neighbors(rest, target_path, Some(c))
  }
}

pub fn serve() -> glint.Command(Nil) {
  use <- glint.command_help("Serve the compiled book locally on port 8000")
  use _, _, _ <- glint.command()

  info("Starting local development server...")
  success("Gleebook is live at http://localhost:8000")
  info("Press Ctrl+C to stop.")

  let secret_key_base = wisp.random_string(64)

  // Start the mist web server
  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.bind("localhost")
    |> mist.start()

  // Keep the process alive
  process.sleep_forever()
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  // 1. Automatically redirect the root URL to index.html
  case req.path {
    "/" -> wisp.redirect("/index.html")
    _ -> {
      // 2. Serve static files securely from the build directory
      use <- wisp.serve_static(req, under: "/", from: "build/gleebook")

      // 3. Fallback for 404s
      wisp.not_found()
    }
  }
}
