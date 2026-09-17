// src/gleebook/core.gleam

pub type Chapter {
  Chapter(title: String, path: String, sub_chapters: List(Chapter))
}
