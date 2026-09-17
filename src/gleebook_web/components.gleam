// src/gleebook_web/components.gleam

import contour
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
        [a.class("language-gleam")],
        highlighted_html,
      )
    }
    _ -> {
      h.code([a.class("language-" <> language)], [h.text(raw_code)])
    }
  }

  h.div(
    [
      a.class(
        "code-block-container relative my-8 rounded-lg overflow-hidden border transition-all duration-200 shadow-md group",
      ),
    ],
    [
      h.div(
        [
          a.class(
            "code-block-bar flex items-center justify-between px-4 py-2 border-b",
          ),
        ],
        [
          h.div([a.class("flex items-center space-x-3")], [
            h.div([a.class("flex space-x-1.5")], [
              h.div([a.class("w-2.5 h-2.5 rounded-full bg-slate-400/40")], []),
              h.div([a.class("w-2.5 h-2.5 rounded-full bg-slate-400/40")], []),
              h.div([a.class("w-2.5 h-2.5 rounded-full bg-slate-400/40")], []),
            ]),
            h.span(
              [
                a.class("text-[10px] font-bold uppercase tracking-[0.2em] pl-1"),
              ],
              [h.text(language)],
            ),
          ]),

          h.button(
            [
              a.attribute("onclick", js_copy_handler),
              a.class(
                "text-[9px] font-mono px-2 py-0.5 rounded border transition-all cursor-pointer active:scale-95",
              ),
            ],
            [h.text("COPY")],
          ),
        ],
      ),

      h.pre(
        [
          a.class(
            "p-5 overflow-x-auto text-sm font-mono leading-relaxed bg-transparent",
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
        "callout-box relative my-6 p-4 pl-5 border-l-4 rounded-r-md shadow-sm",
      ),
    ],
    [h.p([a.class("text-sm font-medium tracking-wide")], [h.text(text)])],
  )
}
