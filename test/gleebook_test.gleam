import gleebook/cli
import gleeunit
import gleeunit/should
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn init_creates_files_test() {
  // 1. Run the core init logic
  let _ = cli.do_init()

  // 2. Assert the files actually exist (handling the Result wrapper)
  simplifile.is_directory("book") |> should.equal(Ok(True))
  simplifile.is_file("book/SUMMARY.md") |> should.equal(Ok(True))
  simplifile.is_file("book/index.md") |> should.equal(Ok(True))

  // 3. Assert the content is correct
  let assert Ok(summary_content) = simplifile.read("book/SUMMARY.md")
  summary_content |> should.equal("# Summary\n\n- [Introduction](index.md)\n")

  // 4. Clean up after the test so it doesn't leave artifacts
  let assert Ok(_) = simplifile.delete("book")
}
