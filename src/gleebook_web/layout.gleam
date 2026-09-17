// src/gleebook_web/layout.gleam
import gleam/int.{to_string as int_to_string}
import gleam/list
import gleam/string
import gleebook/core.{type Chapter}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h

pub type Theme {
  CyberpunkPink
  RustOlive
}

pub fn render_page(
  title: String,
  chapters: List(Chapter),
  current_path: String,
  content: Element(msg),
  default_theme: Theme,
) -> Element(msg) {
  let default_theme_str = case default_theme {
    CyberpunkPink -> "cyberpunk"
    RustOlive -> "olive"
  }

  let base_path = get_base_path(current_path)

  h.html(
    [
      a.lang("en"),
      a.class("antialiased"),
      a.attribute("data-theme", default_theme_str),
    ],
    [
      h.head([], [
        h.meta([a.charset("utf-8")]),
        h.meta([
          a.name("viewport"),
          a.content("width=device-width, initial-scale=1.0"),
        ]),
        h.title([], title),
        h.script([a.src("https://cdn.tailwindcss.com?plugins=typography")], ""),

        h.script(
          [],
          "
          tailwind.config = {
            darkMode: ['selector', '[data-theme=\"cyberpunk\"]'],
          }
          ",
        ),

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

        // Client-side controller updated to use URL params for bulletproof file:/// tracking
        h.script(
          [],
          "
          let savedTheme = new URLSearchParams(window.location.search).get('theme');
          if (!savedTheme) { try { savedTheme = localStorage.getItem('gleebook-theme'); } catch(e) {} }
          if (!savedTheme) { savedTheme = window.name; }
          
          if (savedTheme === 'cyberpunk' || savedTheme === 'olive') {
            document.documentElement.setAttribute('data-theme', savedTheme);
          }

          document.addEventListener('DOMContentLoaded', () => {
            // Automatically append current theme to all internal links clicked
            document.addEventListener('click', (e) => {
              const link = e.target.closest('a');
              if (link && link.href && (link.protocol === 'file:' || link.hostname === window.location.hostname)) {
                const currentTheme = document.documentElement.getAttribute('data-theme');
                if (currentTheme) {
                  try {
                    const url = new URL(link.href);
                    url.searchParams.set('theme', currentTheme);
                    link.href = url.toString();
                  } catch(err) {}
                }
              }
            });

            const sidebar = document.getElementById('sidebar');
            const handle = document.getElementById('sidebar-resizer');
            
            let savedWidth = null;
            let isCollapsed = false;
            try { 
              savedWidth = localStorage.getItem('gleebook-sidebar-width');
              isCollapsed = localStorage.getItem('gleebook-sidebar-collapsed') === 'true';
            } catch(e) {}

            if (sidebar) {
              if (savedWidth && !isCollapsed) {
                sidebar.style.width = savedWidth + 'px';
              }
              if (isCollapsed) {
                sidebar.classList.add('collapsed');
              }
            }

            if (handle && sidebar) {
              let isResizing = false;
              handle.addEventListener('mousedown', (e) => {
                isResizing = true;
                document.body.style.cursor = 'col-resize';
                document.body.style.userSelect = 'none';
              });
              document.addEventListener('mousemove', (e) => {
                if (!isResizing) return;
                const newWidth = Math.max(160, Math.min(e.clientX, 480));
                sidebar.style.width = newWidth + 'px';
                try { localStorage.setItem('gleebook-sidebar-width', newWidth); } catch(e) {}
              });
              document.addEventListener('mouseup', () => {
                if (isResizing) {
                  isResizing = false;
                  document.body.style.cursor = '';
                  document.body.style.userSelect = '';
                }
              });
            }
          });

          function toggleSidebar() {
            const sidebar = document.getElementById('sidebar');
            if (!sidebar) return;
            const collapsed = sidebar.classList.toggle('collapsed');
            try { localStorage.setItem('gleebook-sidebar-collapsed', collapsed); } catch(e) {}
          }
          ",
        ),

        render_theme_styles(),
      ]),

      h.body(
        [
          a.class(
            "theme-body font-mono h-screen flex overflow-hidden relative z-0",
          ),
        ],
        [
          render_lucies(base_path),
          render_sidebar(chapters, current_path, base_path),
          render_main(content),
        ],
      ),
    ],
  )
}

fn render_theme_styles() -> Element(msg) {
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

    @keyframes lucyBlink {
      0%, 90%, 100% { opacity: 0; }
      92%, 96% { opacity: 1; }
    }

    .lucy-1 { animation: drift-1 12s infinite ease-in-out; }
    .lucy-2 { animation: drift-2 15s infinite ease-in-out reverse; }
    .lucy-3 { animation: drift-1 18s infinite ease-in-out 5s; }

    .lucy-blink-overlay {
      animation: lucyBlink 4s infinite ease-in-out;
    }

    /* Sidebar Brand Lucy Hover & Rotation Styles */
    .brand-lucy-icon {
      transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    .brand-lucy:hover .brand-lucy-icon {
      transform: rotate(12deg) scale(1.15);
    }
    .brand-lucy .lucy-happy {
      opacity: 0;
      transition: opacity 0.2s ease-in-out;
    }
    .brand-lucy:hover .lucy-happy {
      opacity: 1;
    }
    .brand-lucy:hover .lucy-open {
      opacity: 0;
    }

    /* Collapsible Sidebar Mechanics */
    #sidebar {
      transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), width 0.05s ease-out;
      will-change: transform, width;
    }
    #sidebar.collapsed {
      transform: translateX(-100%);
      position: absolute;
    }

    #sidebar-resizer:hover, #sidebar-resizer:active {
      background-color: rgba(255, 175, 243, 0.4);
    }
    [data-theme='olive'] #sidebar-resizer:hover, [data-theme='olive'] #sidebar-resizer:active {
      background-color: rgba(163, 184, 153, 0.5);
    }

    /* --- CYBERPUNK PINK THEME --- */
    [data-theme='cyberpunk'] .theme-body { background-color: #0d0914; color: #fffbe8; }
    [data-theme='cyberpunk'] .theme-lucies { display: block; }
    
    [data-theme='cyberpunk'] .lucy-open { filter: drop-shadow(0 0 8px #ff1493); }
    [data-theme='cyberpunk'] .lucy-happy { filter: drop-shadow(0 0 12px #ff1493); }
    
    [data-theme='cyberpunk'] .theme-sidebar { background-color: rgba(13, 9, 20, 0.7); border-color: rgba(255, 175, 243, 0.15); backdrop-filter: blur(24px); }
    [data-theme='cyberpunk'] .theme-brand { color: #ffaff3; }
    [data-theme='cyberpunk'] .theme-nav-link { color: #94a3b8; }
    [data-theme='cyberpunk'] .theme-nav-link:hover { background-color: rgba(255, 175, 243, 0.1); color: #ffaff3; border-color: rgba(255, 175, 243, 0.2); }
    [data-theme='cyberpunk'] .theme-nav-link-active { background-color: rgba(255, 175, 243, 0.15); color: #ffaff3; border-left-color: #ffaff3; border-left-width: 4px; }
    
    [data-theme='cyberpunk'] .code-block-container { background-color: rgba(18, 13, 28, 0.8); border-color: rgba(255, 175, 243, 0.2); color: #fffbe8; }
    [data-theme='cyberpunk'] .code-block-container:hover { border-color: rgba(255, 175, 243, 0.5); box-shadow: 0 0 20px rgba(255, 175, 243, 0.2); }
    [data-theme='cyberpunk'] .code-block-bar { background-color: rgba(9, 6, 15, 0.8); border-color: rgba(255, 175, 243, 0.1); color: #ffaff3; }
    [data-theme='cyberpunk'] .callout-box { background-color: rgba(255, 175, 243, 0.1); border-color: #ffaff3; color: #fffbe8; }

    [data-theme='cyberpunk'] pre code .hl-keyword  { color: #ffaff3 !important; font-weight: bold; }
    [data-theme='cyberpunk'] pre code .hl-function { color: #818cf8 !important; }
    [data-theme='cyberpunk'] pre code .hl-module   { color: #c084fc !important; }
    [data-theme='cyberpunk'] pre code .hl-variant  { color: #f472b6 !important; }
    [data-theme='cyberpunk'] pre code .hl-operator { color: #f382e6 !important; }
    [data-theme='cyberpunk'] pre code .hl-string   { color: #4ade80 !important; }
    [data-theme='cyberpunk'] pre code .hl-number   { color: #fbbf24 !important; }
    [data-theme='cyberpunk'] pre code .hl-comment  { color: #64748b !important; font-style: italic; }

    /* --- RUST OLIVE THEME --- */
    [data-theme='olive'] .theme-body { background-color: #f2f4ef; color: #1a221b; font-family: ui-sans-serif, system-ui, sans-serif; }
    [data-theme='olive'] .theme-lucies { display: none !important; }
    [data-theme='olive'] .theme-sidebar { background-color: #3b473d; border-color: #2d382e; color: #e8ebe6; }
    [data-theme='olive'] .theme-brand { color: #a3b899; }
    [data-theme='olive'] .theme-nav-link { color: #c8d1c5; }
    [data-theme='olive'] .theme-nav-link:hover { background-color: #4a584d; color: #ffffff; }
    [data-theme='olive'] .theme-nav-link-active { background-color: #2d382e; color: #ffffff; border-left-color: #a3b899; border-left-width: 4px; }

    [data-theme='olive'] h1, [data-theme='olive'] h2, [data-theme='olive'] h3, [data-theme='olive'] h4 { color: #232d25 !important; font-weight: 700 !important; }
    [data-theme='olive'] p, [data-theme='olive'] li { color: #2b362c !important; }

    [data-theme='olive'] .prose strong { color: #1a221b !important; font-weight: 800; }
    [data-theme='olive'] .prose em { color: #2b362c !important; }
    [data-theme='olive'] .prose pre { background-color: rgba(59, 71, 61, 0.1); color: #1a221b; }

    [data-theme='olive'] .callout-box { background-color: #dbe2d7; border-color: #3b473d; color: #1a221b; font-weight: 500; }
    [data-theme='olive'] .code-block-container { background-color: #e2e8df; border-color: #3b473d; color: #1a221b; }
    [data-theme='olive'] .code-block-container:hover { border-color: #232d25; box-shadow: 0 4px 14px rgba(35, 45, 37, 0.18); }
    [data-theme='olive'] .code-block-bar { background-color: #cbd4c6; border-color: #3b473d; color: #232d25; font-weight: 700; }
    [data-theme='olive'] .code-block-bar span { color: #232d25 !important; opacity: 1 !important; }
    [data-theme='olive'] .code-block-bar button { color: #232d25 !important; border-color: #3b473d !important; font-weight: 600; }
    [data-theme='olive'] .code-block-bar button:hover { background-color: #3b473d !important; color: #ffffff !important; }

    [data-theme='olive'] .hljs { background: transparent !important; color: #1a221b !important; }
    [data-theme='olive'] pre code { color: #1a221b !important; font-weight: 600; }
    
    [data-theme='olive'] pre code .hl-keyword, [data-theme='olive'] .hljs-keyword { color: #6b21a8 !important; font-weight: bold; }
    [data-theme='olive'] pre code .hl-function, [data-theme='olive'] .hljs-title { color: #1d4ed8 !important; font-weight: 700; }
    [data-theme='olive'] pre code .hl-module { color: #0369a1 !important; }
    [data-theme='olive'] pre code .hl-variant { color: #c2410c !important; }
    [data-theme='olive'] pre code .hl-operator, [data-theme='olive'] .hljs-punctuation, [data-theme='olive'] .hljs-type, [data-theme='olive'] .hljs-built_in, [data-theme='olive'] .hljs-property, [data-theme='olive'] .hljs-params { color: #1a221b !important; }
    [data-theme='olive'] pre code .hl-string, [data-theme='olive'] .hljs-string { color: #15803d !important; }
    [data-theme='olive'] pre code .hl-number { color: #b45309 !important; }
    [data-theme='olive'] pre code .hl-comment, [data-theme='olive'] .hljs-comment { color: #64748b !important; font-style: italic; }

    /* Sun / Moon Toggle Switcher Knob */
    [data-theme='cyberpunk'] .theme-knob { transform: translateX(0px); }
    [data-theme='olive'] .theme-knob { transform: translateX(24px); }
    [data-theme='cyberpunk'] .icon-sun { opacity: 0; transform: rotate(-90deg) scale(0.5); }
    [data-theme='cyberpunk'] .icon-moon { opacity: 1; transform: rotate(0deg) scale(1); }
    [data-theme='olive'] .icon-sun { opacity: 1; transform: rotate(0deg) scale(1); }
    [data-theme='olive'] .icon-moon { opacity: 0; transform: rotate(90deg) scale(0.5); }
    ",
  )
}

fn render_lucies(base_path: String) -> Element(msg) {
  let indices = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

  h.div(
    [
      a.class(
        "theme-lucies fixed inset-0 z-[-1] overflow-hidden pointer-events-none",
      ),
    ],
    [
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
      ..list.map(indices, fn(idx) { create_bubblegum_lucy(idx, base_path) })
    ],
  )
}

fn render_sidebar(
  chapters: List(Chapter),
  current_path: String,
  base_path: String,
) -> Element(msg) {
  let toggle_theme_js =
    "
    document.body.classList.add('transition-colors', 'duration-300');
    document.getElementById('sidebar').classList.add('transition-colors', 'duration-300');
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'cyberpunk' ? 'olive' : 'cyberpunk';
    document.documentElement.setAttribute('data-theme', next);
    
    try { localStorage.setItem('gleebook-theme', next); } catch(e) {}
    window.name = next;
    
    try {
      const url = new URL(window.location.href);
      url.searchParams.set('theme', next);
      window.history.replaceState({}, '', url.toString());
    } catch(err) {}
    "

  h.aside(
    [
      a.id("sidebar"),
      a.class(
        "theme-sidebar w-64 border-r p-4 overflow-y-auto relative z-20 flex flex-col justify-between flex-shrink-0 min-w-[160px] max-w-[480px]",
      ),
    ],
    [
      h.div(
        [
          a.id("sidebar-resizer"),
          a.class(
            "absolute top-0 right-0 w-1.5 h-full cursor-col-resize hover:bg-[#ffaff3]/40 transition-colors z-30",
          ),
        ],
        [],
      ),

      h.div([], [
        h.div([a.class("flex items-center justify-between mb-6")], [
          h.div(
            [
              a.class(
                "brand-lucy flex items-center space-x-3 cursor-default group",
              ),
            ],
            [
              h.div(
                [a.class("brand-lucy-icon relative w-8 h-8 flex-shrink-0")],
                [
                  h.img([
                    a.src(base_path <> "./assets/lucy.svg"),
                    a.class(
                      "lucy-open absolute inset-0 w-full h-full object-contain transition-opacity duration-200",
                    ),
                  ]),
                  h.img([
                    a.src(base_path <> "./assets/lucyhappy.svg"),
                    a.class(
                      "lucy-happy absolute inset-0 w-full h-full object-contain transition-opacity duration-200",
                    ),
                  ]),
                ],
              ),
              h.span(
                [
                  a.class(
                    "theme-brand text-xl font-bold tracking-widest glitch-hover transition-colors truncate",
                  ),
                ],
                [h.text("GLEEBOOK")],
              ),
            ],
          ),

          h.button(
            [
              a.attribute("onclick", "toggleSidebar()"),
              a.class(
                "p-1 rounded opacity-60 hover:opacity-100 transition-opacity text-sm cursor-pointer",
              ),
              a.attribute("title", "Collapse Sidebar"),
            ],
            [h.text("◧")],
          ),
        ]),

        h.nav([a.class("space-y-1")], [
          h.ul(
            [],
            list.map(chapters, fn(c) {
              render_sidebar_link(c, current_path, base_path)
            }),
          ),
        ]),
      ]),

      h.div([a.class("pt-4 border-t border-slate-700/30 flex justify-center")], [
        h.button(
          [
            a.attribute("onclick", toggle_theme_js),
            a.class(
              "relative w-14 h-8 rounded-full bg-slate-800/60 border border-slate-600/40 p-1 cursor-pointer transition-all duration-300 focus:outline-none hover:border-slate-400",
            ),
          ],
          [
            h.div(
              [
                a.class(
                  "theme-knob w-6 h-6 rounded-full bg-[##400228] text-slate-900 flex items-center justify-center transition-transform duration-300 shadow-md relative overflow-hidden",
                ),
              ],
              [
                h.span(
                  [
                    a.class(
                      "icon-moon absolute transition-all duration-300 text-xs font-bold",
                    ),
                  ],
                  [h.text("🌙")],
                ),
                h.span(
                  [
                    a.class(
                      "icon-sun absolute transition-all duration-300 text-xs font-bold",
                    ),
                  ],
                  [h.text("☀️")],
                ),
              ],
            ),
          ],
        ),
      ]),
    ],
  )
}

fn render_sidebar_link(
  chapter: Chapter,
  current_path: String,
  base_path: String,
) -> Element(msg) {
  let is_active = chapter.path == current_path

  let base_classes =
    "block px-3 py-2 rounded-md text-sm font-medium transition-all border border-transparent truncate "
  let state_classes = case is_active {
    True -> "theme-nav-link-active"
    False -> "theme-nav-link"
  }

  let link =
    h.a(
      [
        a.href(base_path <> chapter.path),
        a.class(base_classes <> state_classes),
      ],
      [
        h.text(chapter.title),
      ],
    )

  // Recursively render children if they exist
  let children_ui = case chapter.children {
    [] -> element.none()
    children ->
      h.ul(
        [a.class("pl-4 ml-2 mt-1 space-y-1 border-l border-slate-700/30")],
        list.map(children, fn(c) {
          render_sidebar_link(c, current_path, base_path)
        }),
      )
  }

  h.li([], [link, children_ui])
}

fn render_main(content: Element(msg)) -> Element(msg) {
  h.main(
    [
      a.class(
        "flex-1 overflow-y-auto p-4 sm:p-8 lg:p-12 relative z-10 min-w-0 max-w-full",
      ),
    ],
    [
      h.button(
        [
          a.attribute("onclick", "toggleSidebar()"),
          a.class(
            "fixed top-4 left-4 z-30 p-2 rounded-md border border-current opacity-70 hover:opacity-100 backdrop-blur-md transition-all cursor-pointer shadow-md text-xs",
          ),
          a.attribute("title", "Toggle Sidebar"),
        ],
        [h.text("☰")],
      ),

      h.div(
        [
          a.class(
            "max-w-3xl mx-auto prose dark:prose-invert prose-headings:text-current prose-a:text-current w-full overflow-hidden break-words",
          ),
        ],
        [content],
      ),
    ],
  )
}

fn create_bubblegum_lucy(index: Int, base_path: String) -> Element(msg) {
  let top_num = { index * 67 + 19 } % 84 + 8

  let left_num = case index % 2 {
    0 -> { index * 37 + 11 } % 26 + 4
    _ -> { index * 43 + 23 } % 24 + 70
  }

  let size_px = int_to_string({ index * 7 } % 14 + 18) <> "px"
  let opacity_val = int_to_string({ index * 9 } % 20 + 20) <> "%"

  let drift_delay = "-" <> int_to_string({ index * 5 } % 17) <> "s"
  let blink_delay = "-" <> int_to_string({ index * 13 } % 19 / 2) <> "s"
  let anim_class = "lucy-" <> int_to_string({ index % 3 } + 1)

  h.div(
    [
      a.class("absolute pointer-events-none " <> anim_class),
      a.style("top", int_to_string(top_num) <> "%"),
      a.style("left", int_to_string(left_num) <> "%"),
      a.style("width", size_px),
      a.style("height", size_px),
      a.style("opacity", opacity_val),
      a.style("animation-delay", drift_delay),
    ],
    [
      h.img([
        a.src(base_path <> "assets/lucy.svg"),
        // <-- Prepended base_path
        a.class(
          "absolute inset-0 w-full h-full object-contain filter drop-shadow-[0_0_6px_rgba(255,20,147,0.4)]",
        ),
      ]),
      h.img([
        a.src(base_path <> "assets/lucyhappy.svg"),
        // <-- Prepended base_path
        a.class(
          "lucy-blink-overlay absolute inset-0 w-full h-full object-contain filter drop-shadow-[0_0_6px_rgba(255,20,147,0.4)]",
        ),
        a.style("animation-delay", blink_delay),
      ]),
    ],
  )
}

fn get_base_path(current_path: String) -> String {
  let depth = current_path |> string.split("/") |> list.length
  case depth {
    0 | 1 -> "./"
    n -> string.repeat("../", n - 1)
  }
}
