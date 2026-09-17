// src/gleebook_web/layout.gleam
import gleam/int.{to_string as int_to_string}
import gleam/list
import gleebook/core.{type Chapter}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h

pub fn render_page(
  title: String,
  chapters: List(Chapter),
  content: Element(msg),
) -> Element(msg) {
  h.html([a.lang("en"), a.class("antialiased")], [
    h.head([], [
      h.meta([a.charset("utf-8")]),
      h.meta([
        a.name("viewport"),
        a.content("width=device-width, initial-scale=1.0"),
      ]),
      h.title([], title),
      h.script([a.src("https://cdn.tailwindcss.com?plugins=typography")], ""),

      // Highlight.js CDN for general languages (Bash, JS, HTML, etc.)
      h.link([
        a.rel("stylesheet"),
        a.href(
          "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/tokyo-night-dark.min.css",
        ),
      ]),
      h.script(
        [
          a.src(
            "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js",
          ),
        ],
        "",
      ),
      h.script([], "hljs.highlightAll();"),

      h.style(
        [],
        "
        @keyframes textGlitch {
          0% { text-shadow: 0.5px 0 0 #ffaff3, -0.5px 0 0 #ff1493; transform: translate(0px, 0px); clip-path: inset(0 -10px 0 -10px); }
          20% { text-shadow: 0.5px 0 0 #ffaff3, -0.5px 0 0 #ff1493; transform: translate(0px, -1px); clip-path: inset(20% -10px 20% -10px); }
          40% { text-shadow: 0.5px 0 0 #ffaff3, -0.5px 0 0 #ff1493; transform: translate(0px, 1px); clip-path: inset(40% -10px 40% -10px); }
          100% { text-shadow: 0.5px 0 0 #ffaff3, -0.5px 0 0 #ff1493; transform: translate(0px, 0px); clip-path: inset(0 -10px 0 -10px); }
        }
        .glitch-hover:hover { animation: textGlitch 0.15s steps(2, start) forwards; }

        @keyframes drift-1 {
          0%, 100% { transform: translate(0px, 0px) rotate(0deg) scale(1); }
          33% { transform: translate(40px, -60px) rotate(120deg) scale(1.2); }
          66% { transform: translate(-30px, 30px) rotate(240deg) scale(0.8); }
        }
        
        @keyframes drift-2 {
          0%, 100% { transform: translate(0px, 0px) rotate(0deg) scale(1); }
          33% { transform: translate(-50px, 50px) rotate(-120deg) scale(1.3); }
          66% { transform: translate(40px, -40px) rotate(-240deg) scale(0.7); }
        }

        .lucy-1 { animation: drift-1 12s infinite ease-in-out; }
        .lucy-2 { animation: drift-2 15s infinite ease-in-out reverse; }
        .lucy-3 { animation: drift-1 18s infinite ease-in-out 5s; }
        ",
      ),
    ]),

    h.body(
      [
        a.class(
          "bg-[#0d0914] text-[#fffbe8] font-mono h-screen flex overflow-hidden relative z-0",
        ),
      ],
      [
        render_lucies(),
        render_sidebar(chapters),
        render_main(content),
      ],
    ),
  ])
}

fn render_lucies() -> Element(msg) {
  let indices = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25,
  ]

  h.div([a.class("fixed inset-0 z-[-1] overflow-hidden pointer-events-none")], [
    h.div(
      [
        a.class(
          "absolute top-[10%] left-[20%] w-[30rem] h-[30rem] bg-[#ffaff3]/5 rounded-full blur-[120px] lucy-1",
        ),
      ],
      [],
    ),
    h.div(
      [
        a.class(
          "absolute bottom-[10%] right-[20%] w-[35rem] h-[35rem] bg-[#ff1493]/5 rounded-full blur-[140px] lucy-2",
        ),
      ],
      [],
    ),
    ..list.map(indices, create_bubblegum_lucy)
  ])
}

fn render_sidebar(chapters: List(Chapter)) -> Element(msg) {
  h.aside(
    [
      a.class(
        "w-64 border-r border-[#ffaff3]/10 bg-[#0d0914]/60 backdrop-blur-xl p-4 overflow-y-auto relative z-10",
      ),
    ],
    [
      h.div(
        [
          a.class(
            "text-xl font-bold mb-6 text-[#ffaff3] tracking-widest glitch-hover cursor-default",
          ),
        ],
        [
          h.text("GLEEBOOK"),
        ],
      ),
      h.nav([a.class("space-y-1")], [
        h.ul([], list.map(chapters, render_sidebar_link)),
      ]),
    ],
  )
}

fn render_sidebar_link(chapter: Chapter) -> Element(msg) {
  h.li([], [
    h.a(
      [
        a.href(chapter.path),
        a.class(
          "block px-3 py-2 rounded-md text-sm font-medium text-slate-400 hover:bg-[#ffaff3]/10 hover:text-[#ffaff3] transition-all border border-transparent hover:border-[#ffaff3]/20",
        ),
      ],
      [h.text(chapter.title)],
    ),
  ])
}

fn render_main(content: Element(msg)) -> Element(msg) {
  h.main([a.class("flex-1 overflow-y-auto p-8 lg:p-12 relative z-10")], [
    h.div(
      [
        a.class(
          "max-w-3xl mx-auto prose prose-invert prose-headings:text-[#ffaff3] prose-a:text-[#ffaff3] hover:prose-a:text-[#f382e6] prose-a:transition-colors",
        ),
      ],
      [
        content,
      ],
    ),
  ])
}

fn create_bubblegum_lucy(index: Int) -> Element(msg) {
  let top_pos = int_to_string({ index * 23 } % 85 + 5) <> "%"
  let left_pos = int_to_string({ index * 37 } % 90 + 5) <> "%"
  let size = int_to_string({ index * 3 } % 4 + 2)
  let opacity = int_to_string({ index * 10 } % 40 + 30)
  let anim = "lucy-" <> int_to_string({ index % 3 } + 1)

  let class_str =
    "absolute top-["
    <> top_pos
    <> "] left-["
    <> left_pos
    <> "] "
    <> "w-"
    <> size
    <> " h-"
    <> size
    <> " "
    <> "bg-[#ffaff3] rounded-sm shadow-[0_0_12px_#ff1493] "
    <> anim
    <> " opacity-"
    <> opacity

  h.div([a.class(class_str)], [])
}
