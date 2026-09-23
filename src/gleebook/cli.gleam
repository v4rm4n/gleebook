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
import gleebook/template
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

  case template.scaffold("book") {
    Ok(written) -> {
      list.each(written, fn(path) { info("Created " <> path) })
      success(
        "Book scaffolded! Run `gleam run -m gleebook serve` to preview it.",
      )
    }
    Error(template.AlreadyExists(path)) ->
      error(path <> " already exists; refusing to overwrite an existing book.")
    Error(template.WriteFailed(path, reason)) ->
      error(
        "Could not write " <> path <> ": " <> simplifile.describe_error(reason),
      )
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

  // 1. Ensure the output directory exists as a proper folder
  let _ = simplifile.create_directory_all("build/gleebook")

  copy_base_assets()
  copy_book_files()

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

  let #(book_title, chapters) = parser.parse_summary(summary_content)
  let initial_theme = layout.CyberpunkPink

  let all_chapters = flatten_pages(chapters)

  // --- ORPHAN PAGE DETECTION ---
  // Find all .md files in the book that aren't in SUMMARY.md
  let all_files = result.unwrap(simplifile.get_files("book"), [])
  let hidden_chapters =
    all_files
    |> list.filter(fn(path) {
      string.ends_with(path, ".md") && path != "book/SUMMARY.md"
    })
    |> list.filter_map(fn(file_path) {
      let relative_md = string.drop_start(file_path, 5)
      let html_path = string.replace(relative_md, ".md", ".html")

      // Check if this file is already handled by the summary
      let is_in_summary = list.any(all_chapters, fn(c) { c.path == html_path })

      case is_in_summary {
        True -> Error(Nil)
        // Skip it, it's already in the sidebar
        False -> {
          // It's a hidden page! Try to extract an H1 title from it.
          let title = case simplifile.read(file_path) {
            Ok(content) -> {
              let lines = string.split(content, "\n")
              list.find_map(lines, fn(line) {
                let trimmed = string.trim(line)
                case string.starts_with(trimmed, "# ") {
                  True -> Ok(string.drop_start(trimmed, 2) |> string.trim)
                  False -> Error(Nil)
                }
              })
              |> result.unwrap(relative_md)
            }
            Error(_) -> relative_md
          }
          Ok(core.Chapter(title: title, path: html_path, children: []))
        }
      }
    })

  // Combine standard pages and hidden pages for the build loop
  let pages_to_build = list.append(all_chapters, hidden_chapters)
  // -----------------------------

  let has_errors =
    list.fold(pages_to_build, False, fn(had_error, chapter) {
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

      // Pass `all_chapters` here so hidden pages don't accidentally link to each other via Next/Prev!
      let #(prev_chap, next_chap) =
        find_neighbors(all_chapters, chapter.path, None)

      let page =
        layout.render_page(
          chapter.title <> " - " <> book_title,
          book_title,
          chapters,
          chapter.path,
          dynamic_content,
          initial_theme,
          prev_chap,
          next_chap,
        )

      let html_string = element.to_document_string(page)
      let out_path = "build/gleebook/" <> chapter.path

      // Create nested target subdirectories dynamically
      let target_dir =
        out_path
        |> string.split("/")
        |> list.reverse
        |> list.drop(1)
        |> list.reverse
        |> string.join("/")

      let _ = simplifile.create_directory_all(target_dir)

      case simplifile.write(out_path, html_string) {
        Ok(_) -> {
          info("Compiled " <> out_path)
          had_error || is_missing
        }
        Error(err) -> {
          error(
            "Failed writing '"
            <> out_path
            <> "': "
            <> simplifile.describe_error(err),
          )
          True
        }
      }
    })

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

  use get_port <- glint.flag(
    glint.int_flag("port")
    |> glint.flag_default(8000)
    |> glint.flag_help("Port to serve on"),
  )

  use _, _, flags <- glint.command()

  let port = result.unwrap(get_port(flags), 8000)

  info("Starting local development server...")
  do_build()

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
  case req.path {
    "/" -> wisp.redirect("/index.html")
    _ -> {
      use <- wisp.serve_static(req, under: "/", from: "build/gleebook")
      wisp.not_found()
    }
  }
}

fn get_file_stats() -> dict.Dict(String, Int) {
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
  process.sleep(1000)
  let current_stats = get_file_stats()
  case current_stats != last_stats {
    True -> {
      info("File change detected! Rebuilding...")
      do_build()
      watcher_loop(current_stats)
    }
    False -> watcher_loop(current_stats)
  }
}

fn flatten_pages(chapters: List(core.Chapter)) -> List(core.Chapter) {
  list.flat_map(chapters, fn(c) {
    let rest = flatten_pages(c.children)
    case c.path {
      "" -> rest
      _ -> [c, ..rest]
    }
  })
}

/// Copies built-in CSS and SVG assets from priv/ to the build directory.
fn copy_base_assets() -> Nil {
  let target = "build/gleebook/assets"
  let _ = simplifile.delete(target)

  case wisp.priv_directory("gleebook") {
    Ok(priv) -> {
      let priv_assets = priv <> "/assets"
      case simplifile.is_directory(priv_assets) {
        Ok(True) -> {
          let _ = simplifile.copy_directory(priv_assets, target)
          Nil
        }
        _ -> Nil
      }
    }
    Error(_) -> Nil
  }
  let _ = simplifile.create_directory_all(target)
  Nil
}

/// Recursively copies all non-markdown files (like images) from the book/ 
/// directory directly into the build/gleebook/ output, preserving structure.
fn copy_book_files() -> Nil {
  case simplifile.get_files("book") {
    Ok(files) -> {
      list.each(files, fn(file) {
        let is_md = string.ends_with(file, ".md")
        let is_css = string.ends_with(file, "custom.css")

        case is_md || is_css {
          True -> Nil
          False -> {
            // file path looks like "book/nest1/image.jpg"
            // we want to move it to "build/gleebook/nest1/image.jpg"
            let relative_path = string.drop_start(file, 5)
            // drop "book/"
            let dest_file = "build/gleebook/" <> relative_path

            let dest_dir =
              dest_file
              |> string.split("/")
              |> list.reverse
              |> list.drop(1)
              |> list.reverse
              |> string.join("/")

            let _ = simplifile.create_directory_all(dest_dir)
            let _ = simplifile.copy_file(file, dest_file)
            Nil
          }
        }
      })
    }
    Error(_) -> Nil
  }
}
