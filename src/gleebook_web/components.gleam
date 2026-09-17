// src/gleebook_web/components.gleam

import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h

/// A reusable, modern code block component.
/// This acts as the wrapper where `contour` will eventually inject its highlighted code.
pub fn code_block(language: String, raw_code: String) -> Element(msg) {
  // Escaping quotes and newlines safely for the inline JS clipboard handler
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

  h.div(
    [
      a.class(
        "code-block-container relative my-8 rounded-lg overflow-hidden border border-[#ffaff3]/20 bg-[#120d1c]/80 backdrop-blur-md shadow-[0_4px_30px_rgba(0,0,0,0.5)] transition-all hover:border-[#ffaff3]/40 hover:shadow-[0_0_15px_rgba(255,175,243,0.15)] group",
      ),
    ],
    [
      // Top header bar
      h.div(
        [
          a.class(
            "flex items-center justify-between px-4 py-2 bg-[#09060f]/80 border-b border-[#ffaff3]/10",
          ),
        ],
        [
          // Terminal Mac-style controls
          h.div([a.class("flex space-x-1.5")], [
            h.div(
              [
                a.class(
                  "w-2 h-2 rounded-full bg-[#ffaff3]/30 group-hover:bg-rose-500 transition-colors",
                ),
              ],
              [],
            ),
            h.div(
              [
                a.class(
                  "w-2 h-2 rounded-full bg-[#ffaff3]/30 group-hover:bg-amber-500 transition-colors",
                ),
              ],
              [],
            ),
            h.div(
              [
                a.class(
                  "w-2 h-2 rounded-full bg-[#ffaff3]/30 group-hover:bg-[#ffaff3] transition-colors",
                ),
              ],
              [],
            ),
          ]),

          // Action controls: Language tag + Copy button
          h.div([a.class("flex items-center space-x-3")], [
            h.span(
              [
                a.class(
                  "text-[10px] font-bold text-[#ffaff3] uppercase tracking-[0.2em] glitch-hover",
                ),
              ],
              [h.text(language)],
            ),

            // The interactive Copy Button
            h.button(
              [
                a.attribute("onclick", js_copy_handler),
                a.class(
                  "text-[9px] font-mono px-2 py-0.5 rounded border border-[#ffaff3]/20 text-[#ffaff3]/70 hover:text-[#ffaff3] hover:border-[#ffaff3]/50 transition-all cursor-pointer active:scale-95",
                ),
              ],
              [h.text("COPY")],
            ),
          ]),
        ],
      ),

      // Code Block Body
      h.pre(
        [
          a.class(
            "p-5 overflow-x-auto text-sm text-[#fffbe8] font-mono leading-relaxed",
          ),
        ],
        [
          h.code([a.class("language-" <> language)], [h.text(raw_code)]),
        ],
      ),
    ],
  )
}

pub fn callout(text: String) -> Element(msg) {
  h.div(
    [
      a.class(
        "relative my-6 p-4 pl-5 border-l-2 border-[#ffaff3] bg-gradient-to-r from-[#ffaff3]/10 to-transparent backdrop-blur-sm",
      ),
    ],
    [
      h.div(
        [
          a.class(
            "absolute left-0 top-0 w-2 h-2 bg-[#ffaff3] shadow-[0_0_8px_#ffaff3]",
          ),
        ],
        [],
      ),
      h.p([a.class("text-[#fffbe8] text-sm tracking-wide")], [h.text(text)]),
    ],
  )
}
