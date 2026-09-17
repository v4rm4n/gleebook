// src/gleebook/parser.gleam

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleebook/core.{type Chapter, Chapter}

pub fn parse_summary(content: String) -> #(String, List(Chapter)) {
  let lines = string.split(content, "\n")

  // Extract title from the first H1, default to "GLEEBOOK" if none exists
  let title =
    list.find_map(lines, fn(line) {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "# ") {
        True -> Ok(string.drop_start(trimmed, 2) |> string.trim)
        False -> Error(Nil)
      }
    })
    |> result.unwrap("GLEEBOOK")

  let chapters = build_tree(lines, [])

  #(title, chapters)
}

/// Recursively inserts a chapter into the tree based on its indentation depth
fn insert_chapter(
  chapters: List(Chapter),
  new_chapter: Chapter,
  target_depth: Int,
  current_depth: Int,
) -> List(Chapter) {
  case chapters {
    [] -> [new_chapter]
    _ if current_depth < target_depth -> {
      // We haven't reached the target depth, so insert into the LAST chapter's children
      let reversed = list.reverse(chapters)
      case reversed {
        [last, ..rest] -> {
          let updated_last =
            Chapter(
              ..last,
              children: insert_chapter(
                last.children,
                new_chapter,
                target_depth,
                current_depth + 1,
              ),
            )
          list.reverse([updated_last, ..rest])
        }
        [] -> [new_chapter]
      }
    }
    _ -> list.append(chapters, [new_chapter])
  }
}

fn build_tree(lines: List(String), acc: List(Chapter)) -> List(Chapter) {
  case lines {
    [] -> acc
    [line, ..rest] -> {
      case parse_markdown_link(line) {
        Some(#(title, path, indent)) -> {
          let chapter = Chapter(title:, path:, children: [])
          let new_acc = insert_chapter(acc, chapter, indent, 0)
          build_tree(rest, new_acc)
        }
        None -> build_tree(rest, acc)
      }
    }
  }
}

fn parse_markdown_link(line: String) -> Option(#(String, String, Int)) {
  let indent = get_indent_level(line)
  let trimmed = string.trim_start(line)

  case
    string.starts_with(trimmed, "- [") || string.starts_with(trimmed, "* [")
  {
    True -> {
      case string.split_once(trimmed, "](") {
        Ok(#(left, right)) -> {
          let title = string.drop_start(left, 3)
          let path =
            right
            |> string.split_once(")")
            |> result.map(fn(pair) { pair.0 })
            |> result.unwrap("")

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
  let spaces = string.length(line) - string.length(string.trim_start(line))
  spaces / 2
}
