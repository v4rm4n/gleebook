// src/gleebook/core.gleam

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleebook/core.{type Chapter, Chapter}

/// Parses a `SUMMARY.md` string into a structured list of chapters
pub fn parse_summary(content: String) -> List(Chapter) {
  content
  |> string.split("\n")
  |> list_to_chapters([])
}

fn list_to_chapters(lines: List(String), acc: List(Chapter)) -> List(Chapter) {
  case lines {
    [] -> list.reverse(acc)
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case parse_markdown_link(trimmed) {
        Some(#(title, path, _indent_level)) -> {
          let chapter = Chapter(title:, path:, children: [])
          // For now, process flat list; nesting logic merges children based on indent_level
          list_to_chapters(rest, [chapter, ..acc])
        }
        None -> list_to_chapters(rest, acc)
      }
    }
  }
}

/// Helper to parse standard `-[Title](path.md)` links safely
fn parse_markdown_link(line: String) -> Option(#(String, String, Int)) {
  let indent = get_indent_level(line)
  let trimmed = string.trim_start(line)

  case
    string.starts_with(trimmed, "- [") || string.starts_with(trimmed, "* [")
  {
    True -> {
      case string.split_once(trimmed, "](") {
        Ok(#(left, right)) -> {
          // Changed from drop_left to drop_start
          let title = string.drop_start(left, 3)
          let path =
            right
            |> string.split_once(")")
            |> result.map(fn(pair) { pair.0 })
            |> result.unwrap("")

          // Sanitize path extension to .html for generated output
          let html_path = string.replace(path, ".md", ".html")
          Some(#(title, html_path, indent))
        }
        Error(_) -> None
      }
    }
    False -> None
  }
}

fn get_indent_level(line: String) -> Int {
  // Changed from trim_left to trim_start
  let spaces = string.length(line) - string.length(string.trim_start(line))
  spaces / 2
}
