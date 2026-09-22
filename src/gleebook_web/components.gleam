// src/gleebook_web/components.gleam

import contour
import gleam/list
import gleam/option.{type Option, None, Some}
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

/// A callout now takes already-rendered children instead of a plain string,
/// so bold / links / code inside a blockquote survive.
pub fn callout(children: List(Element(msg))) -> Element(msg) {
  h.div(
    [
      a.class(
        "callout-box relative my-6 p-4 pl-5 border-l-4 rounded-r-md shadow-sm w-full max-w-full overflow-hidden break-words text-xs sm:text-sm font-medium tracking-wide [&>p]:my-0 [&>p+p]:mt-3",
      ),
    ],
    children,
  )
}

/// Pull the 11-char id out of any common YouTube URL shape.
pub fn youtube_id(url: String) -> Option(String) {
  let markers = [
    "youtube.com/watch?v=", "youtube.com/embed/", "youtube.com/shorts/",
    "youtube.com/live/", "youtube-nocookie.com/embed/", "youtu.be/",
  ]

  list.find_map(markers, fn(m) { string.split_once(url, m) })
  |> option.from_result
  |> option.map(fn(pair) {
    pair.1
    |> string.to_graphemes
    |> list.take_while(fn(c) { !list.contains(["&", "?", "#", "/", ")"], c) })
    |> string.concat
  })
}

pub fn youtube_embed(id: String, title: String) -> Element(msg) {
  h.div(
    [
      a.class(
        "not-prose my-6 aspect-video w-full overflow-hidden rounded-xl border code-block-container",
      ),
    ],
    [
      h.iframe([
        a.src("https://www.youtube-nocookie.com/embed/" <> id),
        a.attribute("title", title),
        a.attribute("loading", "lazy"),
        a.attribute("referrerpolicy", "strict-origin-when-cross-origin"),
        a.attribute(
          "allow",
          "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share",
        ),
        a.attribute("allowfullscreen", ""),
        a.class("w-full h-full"),
      ]),
    ],
  )
}

pub fn image(src: String, alt: String, title: Option(String)) -> Element(msg) {
  let attrs = [
    a.src(src),
    a.alt(alt),
    a.class(
      "rounded-lg border border-slate-700/30 max-w-full h-auto my-6 shadow-md object-contain",
    ),
    a.attribute("loading", "lazy"),
  ]

  let final_attrs = case title {
    Some(t) -> [a.title(t), ..attrs]
    None -> attrs
  }

  h.img(final_attrs)
}

pub fn video(src: String, alt: String, title: Option(String)) -> Element(msg) {
  let attrs = [
    a.src(src),
    a.class(
      "rounded-lg border border-slate-700/30 w-full h-auto my-6 shadow-md",
    ),
    a.attribute("controls", "true"),
    a.attribute("preload", "metadata"),
  ]

  // Use the provided title, or fallback to the alt text so it's accessible
  let final_attrs = case title {
    Some(t) -> [a.title(t), ..attrs]
    None -> [a.title(alt), ..attrs]
  }

  h.video(final_attrs, [
    h.text("Your browser does not support the video tag. "),
    h.a([a.href(src), a.class("text-[var(--gb-accent)] underline")], [
      h.text("Download the video here."),
    ]),
  ])
}
