// src/gleebook_web/components.gleam

import contour
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h

pub fn code_block(language: String, raw_code: String) -> Element(msg) {
  let js_copy_handler =
    "
    const code = this.closest('.code-block-container').querySelector('code').innerText;
    navigator.clipboard.writeText(code);
    const btn = this;
    const originalText = btn.innerText;
    btn.innerText = 'COPIED!';
    btn.classList.add('text-emerald-400', 'border-emerald-400/50');
    setTimeout(() => {
      btn.innerText = originalText;
      btn.classList.remove('text-emerald-400', 'border-emerald-400/50');
    }, 2000);
    "

  let code_element = case language {
    "gleam" -> {
      let highlighted_html = contour.to_html(raw_code)
      element.unsafe_raw_html(
        "",
        "code",
        [a.class("language-gleam block break-normal whitespace-pre")],
        highlighted_html,
      )
    }
    _ -> {
      h.code(
        [
          a.class(
            "language-" <> language <> " block break-normal whitespace-pre",
          ),
        ],
        [h.text(raw_code)],
      )
    }
  }

  h.div(
    [
      a.class(
        "code-block-container relative my-8 w-full max-w-full rounded-lg overflow-hidden border transition-all duration-200 shadow-md group",
      ),
    ],
    [
      h.div(
        [
          a.class(
            "code-block-bar flex items-center justify-between px-4 py-2 border-b w-full overflow-hidden",
          ),
        ],
        [
          h.div([a.class("flex items-center space-x-3 min-w-0 flex-1")], [
            h.div([a.class("flex space-x-1.5 flex-shrink-0")], [
              h.div([a.class("w-2.5 h-2.5 rounded-full bg-slate-400/40")], []),
              h.div([a.class("w-2.5 h-2.5 rounded-full bg-slate-400/40")], []),
              h.div([a.class("w-2.5 h-2.5 rounded-full bg-slate-400/40")], []),
            ]),
            h.span(
              [
                a.class(
                  "text-[10px] font-bold uppercase tracking-[0.2em] pl-1 truncate",
                ),
              ],
              [h.text(language)],
            ),
          ]),

          h.button(
            [
              a.attribute("onclick", js_copy_handler),
              a.class(
                "text-[9px] font-mono px-2 py-0.5 rounded border transition-all cursor-pointer active:scale-95 flex-shrink-0 ml-2",
              ),
            ],
            [h.text("COPY")],
          ),
        ],
      ),

      // FIX: Added !border-0, !bg-transparent, and !m-0 to override prose defaults
      h.pre(
        [
          a.class(
            "p-4 sm:p-5 overflow-x-auto text-xs sm:text-sm font-mono leading-relaxed w-full max-w-full !border-0 !bg-transparent !m-0",
          ),
        ],
        [code_element],
      ),
    ],
  )
}

pub fn callout(text: String) -> Element(msg) {
  h.div(
    [
      a.class(
        "callout-box relative my-6 p-4 pl-5 border-l-4 rounded-r-md shadow-sm w-full max-w-full overflow-hidden break-words",
      ),
    ],
    [
      h.p(
        [a.class("text-xs sm:text-sm font-medium tracking-wide break-words")],
        [
          h.text(text),
        ],
      ),
    ],
  )
}

pub fn youtube_embed(url: String) -> Element(msg) {
  let video_id = case string.split(url, "v=") {
    [_, id_part, ..] ->
      id_part |> string.split("&") |> list.first |> result.unwrap(id_part)
    _ ->
      case string.split(url, "youtu.be/") {
        [_, id_part, ..] ->
          id_part |> string.split("?") |> list.first |> result.unwrap(id_part)
        _ ->
          case string.split(url, "embed/") {
            [_, id_part, ..] ->
              id_part
              |> string.split("?")
              |> list.first
              |> result.unwrap(id_part)
            _ -> "dQw4w9WgXcQ"
          }
      }
  }

  // Use a completely bare URL. No origin parameters, no nocookie domain.
  let clean_embed_url = "https://www.youtube.com/embed/" <> video_id

  h.div(
    [
      a.class(
        "aspect-video w-full rounded-lg overflow-hidden my-8 shadow-lg border border-slate-700/30 bg-black",
      ),
    ],
    [
      h.iframe([
        a.src(clean_embed_url),
        a.class("w-full h-full border-0"),
        a.attribute(
          "allow",
          "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture",
        ),
        a.attribute("allowfullscreen", "true"),
      ]),
    ],
  )
}
