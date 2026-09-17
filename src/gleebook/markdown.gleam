// src/gleebook/markdown.gleam

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleebook_web/components
import jot.{
  type Container, type Destination, type Inline, BlockQuote, BulletList, Code,
  Codeblock, Delete, Div, Document, Emphasis, Footnote, Heading, Image, Insert,
  Linebreak, Link, Mark, MathDisplay, MathInline, NonBreakingSpace, OrderedList,
  Paragraph, RawBlock, Span, Strong, Subscript, Superscript, Symbol, Text,
  ThematicBreak,
}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h

/// Entry point: Converts raw djot/markdown text into a list of Lustre elements
pub fn render(content: String) -> Element(msg) {
  let Document(containers, _refs, _ref_attrs, _footnotes) = jot.parse(content)
  h.div(
    [a.class("gleebook-prose space-y-6")],
    list.map(containers, render_container),
  )
}

fn render_container(container: Container) -> Element(msg) {
  case container {
    // Standard Prose
    Paragraph(_attrs, inlines) -> h.p([], list.map(inlines, render_inline))

    // Headings (H1 - H6)
    Heading(_attrs, level, inlines) -> {
      let content = list.map(inlines, render_inline)
      case level {
        1 -> h.h1([a.class("text-3xl font-bold mt-8 mb-4")], content)
        2 ->
          h.h2(
            [
              a.class(
                "text-2xl font-bold mt-8 mb-4 border-b border-current/20 pb-2",
              ),
            ],
            content,
          )
        3 -> h.h3([a.class("text-xl font-bold mt-6 mb-3")], content)
        4 -> h.h4([a.class("text-lg font-bold mt-6 mb-2")], content)
        5 -> h.h5([a.class("text-base font-bold mt-4 mb-2")], content)
        _ ->
          h.h6(
            [a.class("text-sm font-bold mt-4 mb-2 uppercase tracking-wide")],
            content,
          )
      }
    }

    // Custom Component: Code Blocks
    Codeblock(_attrs, language, code) -> {
      let lang = case language {
        Some(l) -> l
        None -> "text"
      }
      components.code_block(lang, code)
    }

    // Custom Component: Blockquotes mapped to Callouts
    BlockQuote(_attrs, items) -> {
      let raw_text = extract_text_from_containers(items)
      components.callout(raw_text)
    }

    // Unordered Lists
    BulletList(_layout, _style, items) -> {
      let rendered_items =
        list.map(items, fn(item_containers) {
          h.li([a.class("mb-1")], list.map(item_containers, render_container))
        })
      h.ul([a.class("list-disc list-inside space-y-1 my-4")], rendered_items)
    }

    // Ordered Lists
    OrderedList(_layout, _punctuation, _ordinal, _start, items) -> {
      let rendered_items =
        list.map(items, fn(item_containers) {
          h.li([a.class("mb-1")], list.map(item_containers, render_container))
        })
      h.ol([a.class("list-decimal list-inside space-y-1 my-4")], rendered_items)
    }

    // Thematic Breaks (---)
    ThematicBreak -> h.hr([a.class("border-t border-current/20 my-8")])

    // Security: Disable raw HTML execution to prevent XSS
    RawBlock(_content) -> {
      h.div(
        [
          a.class(
            "text-red-400 font-bold border border-red-500/30 p-3 rounded bg-red-500/10 my-4 text-sm",
          ),
        ],
        [h.text("⚠️ Raw HTML blocks are disabled for security reasons.")],
      )
    }

    // Div wrappers (::: class_name)
    Div(class, _attrs, items) -> {
      let class_str = case class {
        Some(c) -> c
        None -> ""
      }
      h.div([a.class(class_str)], list.map(items, render_container))
    }
  }
}

fn render_inline(inline: Inline) -> Element(msg) {
  case inline {
    Text(text) -> h.text(text)
    NonBreakingSpace -> h.text(" ")
    Linebreak -> h.br([])

    Strong(inlines) ->
      h.strong([a.class("font-bold")], list.map(inlines, render_inline))
    Emphasis(inlines) ->
      h.em([a.class("italic")], list.map(inlines, render_inline))
    Delete(inlines) ->
      h.del([a.class("line-through")], list.map(inlines, render_inline))
    Insert(inlines) ->
      h.ins([a.class("underline")], list.map(inlines, render_inline))
    Mark(inlines) ->
      h.mark(
        [a.class("bg-yellow-200 dark:bg-yellow-800")],
        list.map(inlines, render_inline),
      )
    Superscript(inlines) -> h.sup([], list.map(inlines, render_inline))
    Subscript(inlines) -> h.sub([], list.map(inlines, render_inline))

    Code(code) ->
      h.code(
        [
          a.class(
            "font-mono text-[0.85em] bg-black/10 dark:bg-white/10 px-1.5 py-0.5 rounded",
          ),
        ],
        [h.text(code)],
      )

    MathInline(code) -> h.span([a.class("math-inline italic")], [h.text(code)])
    MathDisplay(code) ->
      h.div([a.class("math-display my-4 text-center")], [h.text(code)])
    Symbol(sym) ->
      h.span([a.class("symbol font-mono")], [h.text(":" <> sym <> ":")])
    Footnote(ref) ->
      h.sup([a.class("text-xs text-[#ffaff3]")], [h.text("[" <> ref <> "]")])
    Span(_attrs, inlines) -> h.span([], list.map(inlines, render_inline))

    Link(_attrs, content, destination) -> {
      let dest_str = resolve_destination(destination)
      h.a(
        [
          a.href(dest_str),
          a.class(
            "underline decoration-current/30 hover:decoration-current transition-colors",
          ),
        ],
        list.map(content, render_inline),
      )
    }

    Image(_attrs, content, destination) -> {
      let dest_str = resolve_destination(destination)
      let alt_text = extract_text_from_inlines(content)

      // Use the new youtube_id function to check if it's a video
      case components.youtube_id(dest_str) {
        Some(id) -> components.youtube_embed(id, alt_text)
        None -> {
          // If it's not a YouTube link, render a standard image
          h.img([
            a.src(dest_str),
            a.alt(alt_text),
            a.class(
              "rounded-lg shadow-md max-w-full h-auto my-4 border border-current/10",
            ),
          ])
        }
      }
    }
  }
}

// -- Helpers to extract raw strings for specific components --

fn extract_text_from_containers(containers: List(Container)) -> String {
  containers
  |> list.map(fn(c) {
    case c {
      Paragraph(_, inlines) -> extract_text_from_inlines(inlines)
      _ -> ""
    }
  })
  |> string.join("\n")
}

fn extract_text_from_inlines(inlines: List(Inline)) -> String {
  inlines
  |> list.map(fn(i) {
    case i {
      Text(t) -> t
      Code(c) -> c
      MathInline(m) | MathDisplay(m) -> m
      Strong(inner) | Emphasis(inner) | Link(_, inner, _) | Span(_, inner) ->
        extract_text_from_inlines(inner)
      _ -> ""
    }
  })
  |> string.join("")
}

fn resolve_destination(dest: Destination) -> String {
  case dest {
    // Automatically rewrite internal .md links to .html
    jot.Url(url) -> string.replace(url, ".md", ".html")
    jot.Reference(ref) -> "#" <> ref
  }
}
