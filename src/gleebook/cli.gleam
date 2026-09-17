// src/gleebook/cli.gleam
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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
  do_build()
}

pub fn do_build() {
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

  // 1. Unpack the tuple!
  let #(book_title, chapters) = parser.parse_summary(summary_content)
  let initial_theme = layout.CyberpunkPink

  let all_chapters = flatten_chapters(chapters)

  let has_errors =
    list.fold(all_chapters, False, fn(had_error, chapter) {
      let md_filename = string.replace(chapter.path, ".html", ".md")
      let source_path = "book/" <> md_filename

      // ... (keep file reading and markdown parsing exactly the same) ...
      let #(page_content, is_missing) = case simplifile.read(source_path) {
        Ok(content) -> #(content, False)
        Error(_) -> {
          error("Warning: Missing source file '" <> source_path <> "'")
          #("# 404\n\nPage `" <> md_filename <> "` not found.", True)
        }
      }

      let parsed_markdown = markdown.render(page_content)
      let dynamic_content = h.div([a.class("mt-4")], [parsed_markdown])

      let #(prev_chap, next_chap) =
        find_neighbors(all_chapters, chapter.path, None)

      // 2. Pass the dynamic book_title into render_page
      let page =
        layout.render_page(
          chapter.title <> " - " <> book_title,
          // Browser tab title
          book_title,
          // New Sidebar Title parameter
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

  // Write a random version number to trigger Live Reload in the browser
  let _ =
    simplifile.write(
      "build/gleebook/version.txt",
      int.to_string(int.random(1_000_000_000)),
    )
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
  use <- glint.command_help("Serve the compiled book locally")

  // 1. Define the flag using the new Glint API, which gives us a getter function
  use get_port <- glint.flag(
    glint.int_flag("port")
    |> glint.flag_default(8000)
    |> glint.flag_help("Port to serve on"),
  )

  use _, _, flags <- glint.command()

  // 2. Call the getter function with the `flags` to extract our value
  let port = result.unwrap(get_port(flags), 8000)

  info("Starting local development server...")

  // Do an initial build just to be safe
  do_build()

  // Spawn the file watcher as a concurrent background process
  let _watcher_pid = process.spawn(fn() { watcher_loop(get_file_stats()) })

  success("Gleebook is live at http://localhost:" <> int.to_string(port))
  info("Watching book/ directory for changes... Press Ctrl+C to stop.")

  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(port)
    |> mist.bind("localhost")
    |> mist.start()

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

fn get_file_stats() -> dict.Dict(String, Int) {
  // Recursively gets all files in the book directory
  let files = result.unwrap(simplifile.get_files("book"), [])

  list.fold(files, dict.new(), fn(acc, file) {
    let mtime = case simplifile.file_info(file) {
      Ok(info) -> info.mtime_seconds
      Error(_) -> 0
    }
    dict.insert(acc, file, mtime)
  })
}

fn watcher_loop(last_stats: dict.Dict(String, Int)) {
  // Sleep for 1 second
  process.sleep(1000)

  let current_stats = get_file_stats()

  // If the timestamps don't match, a file was saved!
  case current_stats != last_stats {
    True -> {
      info("File change detected! Rebuilding...")
      do_build()
      watcher_loop(current_stats)
    }
    False -> watcher_loop(current_stats)
  }
}
