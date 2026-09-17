// src/gleebook.gleam

import argv
import gleebook/cli
import glint

pub fn main() -> Nil {
  glint.new()
  |> glint.with_name("gleebook")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: ["init"], do: cli.init())
  |> glint.add(at: ["build"], do: cli.build())
  |> glint.run(argv.load().arguments)
}
