// src/gleebook/core.gleam

pub type Chapter {
  Chapter(title: String, path: String, children: List(Chapter))
}
