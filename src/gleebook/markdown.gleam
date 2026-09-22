// src/gleebook/markdown.gleam
//
// Markdown -> Lustre renderer, driven by mork (CommonMark + GFM).
// jot was a *Djot* parser, which is why `**bold**`, `~~strike~~` and
// pipe tables never rendered correctly.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleebook_web/components
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import mork
import mork/document.{
  type Alignment, type Block, type Cell, type Destination, type Document,
  type Inline, type ListItem, type ListPack, type THead, Absolute, Anchor,
  Autolink, BlockQuote, BulletList, Center, Checkbox, Code, CodeSpan, Delim,
  EmailAutolink, Emphasis, Empty, Footnote, FullImage, FullLink, HardBreak,
  Heading, Highlight, HtmlBlock, InlineFootnote, InlineHtml, Left, LinkData,
  Newline, OrderedList, Paragraph, RawHtml, RefImage, RefLink, Relative, Right,
  SoftBreak, Strikethrough, Strong, Table, Text, ThematicBreak, Tight,
}

/// Entry point: converts Markdown text into a Lustre element tree.
pub fn render(content: String) -> Element(msg) {
  let doc =
    mork.configure()
    |> mork.tables(True)
    |> mork.tasklists(True)
    |> mork.parse_with_options(content)

  let blocks = list.map(doc.blocks, render_block(doc, _))

  h.div(
    [a.class("gleebook-prose")],
    list.append(blocks, [render_footnotes(doc)]),
  )
}

// -- Blocks --

fn render_block(doc: Document, block: Block) -> Element(msg) {
  case block {
    // A paragraph that is only an image (or YouTube embed) is rendered bare,
    // because a block-level <div>/<img> inside <p> is invalid HTML.
    Paragraph(_raw, inlines) ->
      case inlines {
        [FullImage(_, _) as image] | [RefImage(_, _) as image] ->
          render_inline(doc, image)
        _ ->
          h.p([a.class("my-4 leading-relaxed")], render_inlines(doc, inlines))
      }

    Heading(level, id, _raw, inlines) -> {
      let content = render_inlines(doc, inlines)
      let id_attr = case id {
        "" -> []
        id -> [a.id(id)]
      }
      case level {
        1 -> h.h1([a.class("text-3xl font-bold mt-8 mb-4"), ..id_attr], content)
        2 ->
          h.h2(
            [
              a.class(
                "text-2xl font-bold mt-8 mb-4 border-b border-current/20 pb-2",
              ),
              ..id_attr
            ],
            content,
          )
        3 -> h.h3([a.class("text-xl font-bold mt-6 mb-3"), ..id_attr], content)
        4 -> h.h4([a.class("text-lg font-bold mt-6 mb-2"), ..id_attr], content)
        5 ->
          h.h5([a.class("text-base font-bold mt-4 mb-2"), ..id_attr], content)
        _ ->
          h.h6(
            [
              a.class("text-sm font-bold mt-4 mb-2 uppercase tracking-wide"),
              ..id_attr
            ],
            content,
          )
      }
    }

    Code(lang, text) -> components.code_block(option.unwrap(lang, "text"), text)

    // Blockquotes become callouts, keeping inline formatting intact.
    BlockQuote(blocks) ->
      components.callout(list.map(blocks, render_block(doc, _)))

    BulletList(pack, items) ->
      h.ul(
        [a.class("list-disc pl-6 space-y-1 my-4")],
        list.map(items, render_list_item(doc, pack, _)),
      )

    OrderedList(pack, items, start) -> {
      let start_attr = case start {
        Some(n) if n != 1 -> [a.attribute("start", int.to_string(n))]
        _ -> []
      }
      h.ol(
        [a.class("list-decimal pl-6 space-y-1 my-4"), ..start_attr],
        list.map(items, render_list_item(doc, pack, _)),
      )
    }

    Table(header, rows) -> render_table(doc, header, rows)

    ThematicBreak -> h.hr([a.class("border-t border-current/20 my-8")])

    // Security: never emit raw HTML from content files.
    HtmlBlock(_raw) ->
      h.div(
        [
          a.class(
            "text-red-400 font-bold border border-red-500/30 p-3 rounded bg-red-500/10 my-4 text-sm",
          ),
        ],
        [h.text("⚠️ Raw HTML blocks are disabled for security reasons.")],
      )

    Empty | Newline -> element.none()
  }
}

/// CommonMark: paragraphs inside a *tight* list item are not wrapped in <p>,
/// which is what keeps the bullet and its text on the same line.
fn render_list_item(
  doc: Document,
  pack: ListPack,
  item: ListItem,
) -> Element(msg) {
  let children =
    list.flat_map(item.blocks, fn(block) {
      case pack, block {
        Tight, Paragraph(_, inlines) -> render_inlines(doc, inlines)
        _, other -> [render_block(doc, other)]
      }
    })
  h.li([a.class("[&>ul]:my-1 [&>ol]:my-1")], children)
}

fn render_table(
  doc: Document,
  header: List(THead),
  rows: List(List(Cell)),
) -> Element(msg) {
  let cell_class = "p-3 sm:p-4 "

  let header_cells =
    list.map(header, fn(th) {
      h.th(
        [a.class(cell_class <> align_class(th.align))],
        render_inlines(doc, th.inlines),
      )
    })

  let body_rows =
    list.map(rows, fn(row) {
      let cells =
        list.index_map(row, fn(cell, i) {
          let align = case list.drop(header, i) {
            [th, ..] -> th.align
            [] -> Left
          }
          h.td(
            [a.class(cell_class <> align_class(align))],
            render_inlines(doc, cell.inlines),
          )
        })
      h.tr([a.class("hover:bg-slate-700/10 transition-colors")], cells)
    })

  h.div(
    [
      a.class(
        "overflow-x-auto my-6 border border-slate-700/40 rounded-lg shadow-sm",
      ),
    ],
    [
      h.table([a.class("w-full text-sm border-collapse")], [
        h.thead(
          [a.class("bg-slate-800/50 border-b border-slate-700/40 font-bold")],
          [h.tr([], header_cells)],
        ),
        h.tbody([a.class("divide-y divide-slate-700/20")], body_rows),
      ]),
    ],
  )
}

fn align_class(align: Alignment) -> String {
  case align {
    Left -> "text-left"
    Center -> "text-center"
    Right -> "text-right"
  }
}

fn render_footnotes(doc: Document) -> Element(msg) {
  let notes =
    doc.footnotes
    |> dict.to_list
    |> list.sort(fn(x, y) { int.compare({ x.1 }.num, { y.1 }.num) })

  case notes {
    [] -> element.none()
    notes ->
      h.section([a.class("mt-12 pt-6 border-t border-current/20 text-sm")], [
        h.ol(
          [a.class("list-decimal pl-6 space-y-2")],
          list.map(notes, fn(pair) {
            let #(label, data) = pair
            h.li(
              [a.id("fn-" <> label), a.class("[&>p]:my-0")],
              list.map(data.blocks, render_block(doc, _)),
            )
          }),
        ),
      ])
  }
}

// -- Inlines --

fn render_inlines(doc: Document, inlines: List(Inline)) -> List(Element(msg)) {
  list.map(inlines, render_inline(doc, _))
}

fn render_inline(doc: Document, inline: Inline) -> Element(msg) {
  case inline {
    Text(text) -> h.text(text)
    SoftBreak -> h.text("\n")
    HardBreak -> h.br([])

    Strong(inner) ->
      h.strong([a.class("font-bold text-current")], render_inlines(doc, inner))
    Emphasis(inner) ->
      h.em([a.class("italic text-current")], render_inlines(doc, inner))
    Strikethrough(inner) ->
      h.del([a.class("line-through")], render_inlines(doc, inner))
    Highlight(inner) ->
      h.mark(
        [a.class("bg-yellow-200 dark:bg-yellow-800")],
        render_inlines(doc, inner),
      )

    CodeSpan(code) ->
      h.code(
        [
          a.class(
            "font-mono text-[0.85em] bg-black/10 dark:bg-white/10 px-1.5 py-0.5 rounded",
          ),
        ],
        [h.text(code)],
      )

    FullLink(text, data) -> render_link(doc, text, data)
    RefLink(text, label) ->
      case document.lookup_link(doc, label) {
        Ok(data) -> render_link(doc, text, data)
        Error(_) ->
          element.fragment([
            h.text("["),
            ..list.append(render_inlines(doc, text), [h.text("]")])
          ])
      }

    Autolink(uri, text) ->
      h.a([a.href(uri), a.class(link_class)], [
        h.text(option.unwrap(text, uri)),
      ])
    EmailAutolink(mail) ->
      h.a([a.href("mailto:" <> mail), a.class(link_class)], [h.text(mail)])

    FullImage(text, data) -> render_image(plain_text(text), data)
    RefImage(text, label) ->
      case document.lookup_link(doc, label) {
        Ok(data) -> render_image(plain_text(text), data)
        Error(_) -> h.text("![" <> plain_text(text) <> "]")
      }

    Footnote(num, label) ->
      h.sup([a.class("text-xs")], [
        h.a([a.href("#fn-" <> label), a.class("text-[#ffaff3]")], [
          h.text("[" <> int.to_string(num) <> "]"),
        ]),
      ])
    InlineFootnote(num, _text) ->
      h.sup([a.class("text-xs text-[#ffaff3]")], [
        h.text("[" <> int.to_string(num) <> "]"),
      ])

    Checkbox(checked) ->
      h.input([
        a.type_("checkbox"),
        a.checked(checked),
        a.disabled(True),
        a.class("mr-2 align-middle"),
      ])

    // Security: strip the tags, keep any visible text.
    InlineHtml(_tag, _attrs, children) ->
      element.fragment(render_inlines(doc, children))
    RawHtml(_) -> element.none()

    // Unmatched `*` / `_` runs that never became emphasis: show literally.
    Delim(style, len, _, _) -> h.text(string.repeat(style, len))
  }
}

const link_class = "underline decoration-current/30 hover:decoration-current transition-colors"

fn render_link(
  doc: Document,
  text: List(Inline),
  data: document.LinkData,
) -> Element(msg) {
  let LinkData(dest, title) = data
  let title_attr = case title {
    Some(t) -> [a.attribute("title", t)]
    None -> []
  }
  h.a(
    [a.href(resolve_destination(dest)), a.class(link_class), ..title_attr],
    render_inlines(doc, text),
  )
}

fn render_image(alt_text: String, data: document.LinkData) -> Element(msg) {
  let LinkData(dest, title) = data
  let dest_str = resolve_destination(dest)
  let lower_dest = string.lowercase(dest_str)

  let is_video =
    string.ends_with(lower_dest, ".mp4")
    || string.ends_with(lower_dest, ".webm")
    || string.ends_with(lower_dest, ".ogg")

  case components.youtube_id(dest_str) {
    Some(id) -> components.youtube_embed(id, alt_text)
    None ->
      case is_video {
        True -> components.video(dest_str, alt_text, title)
        False -> components.image(dest_str, alt_text, title)
      }
  }
}

// -- Helpers --

/// Flatten inlines to plain text (used for alt text).
fn plain_text(inlines: List(Inline)) -> String {
  inlines
  |> list.map(fn(i) {
    case i {
      Text(t) -> t
      CodeSpan(c) -> c
      SoftBreak -> " "
      HardBreak -> "\n"
      Autolink(uri, text) -> option.unwrap(text, uri)
      EmailAutolink(m) -> m
      Strong(inner)
      | Emphasis(inner)
      | Strikethrough(inner)
      | Highlight(inner)
      | FullLink(inner, _)
      | RefLink(inner, _)
      | FullImage(inner, _)
      | RefImage(inner, _)
      | InlineFootnote(_, inner)
      | InlineHtml(_, _, inner) -> plain_text(inner)
      _ -> ""
    }
  })
  |> string.concat
}

/// Relative `.md` links become `.html` so intra-book links keep working.
fn resolve_destination(dest: Destination) -> String {
  case dest {
    Absolute(uri) -> uri
    Relative(uri) -> md_to_html(uri)
    Anchor(id) ->
      case string.starts_with(id, "#") {
        True -> id
        False -> "#" <> id
      }
  }
}

fn md_to_html(uri: String) -> String {
  case string.split_once(uri, "#") {
    Ok(#(path, anchor)) -> replace_md_suffix(path) <> "#" <> anchor
    Error(_) -> replace_md_suffix(uri)
  }
}

fn replace_md_suffix(path: String) -> String {
  case string.ends_with(path, ".md") {
    True -> string.drop_end(path, 3) <> ".html"
    False -> path
  }
}
