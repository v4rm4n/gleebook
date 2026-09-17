// src/gleebook_web/layout.gleam
import gleam/int.{to_string as int_to_string}
import gleam/list
import gleam/option.{type Option, None, Some}
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
  book_title: String,
  chapters: List(Chapter),
  current_path: String,
  content: Element(msg),
  default_theme: Theme,
  prev: Option(Chapter),
  next: Option(Chapter),
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
              if (savedWidth && !isCollapsed) { sidebar.style.width = savedWidth + 'px'; }
              if (isCollapsed) { sidebar.classList.add('collapsed'); }
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

        h.link([a.rel("stylesheet"), a.href(base_path <> "custom.css")]),

        h.script([], "
          if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            let currentVersion = null;
            setInterval(() => {
              // FIX: Appended ?t=Date.now() to brutally bypass browser caching
              fetch('" <> base_path <> "version.txt?t=' + Date.now(), { cache: 'no-store' })
                .then(r => r.status === 200 ? r.text() : null)
                .then(v => {
                  if (v && currentVersion === null) {
                    currentVersion = v;
                  } else if (v && currentVersion !== v) {
                    window.location.reload();
                  }
                }).catch(() => {});
            }, 1000);
          }
          "),
      ]),

      h.body(
        [
          a.class(
            "theme-body font-mono h-screen flex overflow-hidden relative z-0",
          ),
        ],
        [
          render_lucies(base_path),
          render_sidebar(book_title, chapters, current_path, base_path),
          // <-- Pass it down
          render_main(content, prev, next, base_path),
        ],
      ),
    ],
  )
}

fn render_theme_styles() -> Element(msg) {
  h.style(
    [],
    "
    :root, [data-theme='cyberpunk'] {
      --gb-bg: #0d0914;
      --gb-text: #fffbe8;
      --gb-sidebar: rgba(13, 9, 20, 0.7);
      --gb-border: rgba(255, 175, 243, 0.15);
      --gb-accent: #ffaff3;
      --gb-nav-text: #94a3b8;
      --gb-nav-hover: rgba(255, 175, 243, 0.1);
      --gb-nav-active: rgba(255, 175, 243, 0.15);
      --gb-code-bg: rgba(18, 13, 28, 0.8);
      --gb-code-bar: rgba(9, 6, 15, 0.8);
      --gb-code-bar-text: #ffaff3;
      --gb-callout: rgba(255, 175, 243, 0.1);
      
      /* Syntax Highlighting */
      --gb-syn-keyword: #ffaff3;
      --gb-syn-func: #818cf8;
      --gb-syn-string: #4ade80;
      --gb-syn-num: #fbbf24;
      --gb-syn-comment: #94a3b8;
      --gb-syn-punct: #fffbe8;
    }

    [data-theme='olive'] {
      --gb-bg: #f2f4ef;
      --gb-text: #1a221b;
      --gb-sidebar: #3b473d;
      --gb-border: #2d382e;
      --gb-accent: #a3b899;
      --gb-nav-text: #c8d1c5;
      --gb-nav-hover: #4a584d;
      --gb-nav-active: #2d382e;
      --gb-code-bg: #e2e8df;
      --gb-code-bar: #cbd4c6;
      --gb-code-bar-text: #1a221b;
      --gb-callout: #dbe2d7;
      
      /* Syntax Highlighting */
      --gb-syn-keyword: #6b21a8;
      --gb-syn-func: #1d4ed8;
      --gb-syn-string: #15803d;
      --gb-syn-num: #b45309;
      --gb-syn-comment: #64748b;
      --gb-syn-punct: #1a221b;
    }

    /* Core Application Variables */
    .theme-body { background-color: var(--gb-bg); color: var(--gb-text); }
    .theme-sidebar { background-color: var(--gb-sidebar); border-color: var(--gb-border); backdrop-filter: blur(24px); }
    .theme-brand { color: var(--gb-accent); }
    
    /* Background Elements Display */
    [data-theme='cyberpunk'] .theme-lucies { display: block; }
    [data-theme='olive'] .theme-lucies { display: none !important; }
    [data-theme='cyberpunk'] .lucy-open { filter: drop-shadow(0 0 8px #ff1493); }
    [data-theme='cyberpunk'] .lucy-happy { filter: drop-shadow(0 0 12px #ff1493); }
    
    /* Navigation Variables */
    .theme-nav-link { color: var(--gb-nav-text); }
    .theme-nav-link:hover { background-color: var(--gb-nav-hover); color: var(--gb-accent); border-color: var(--gb-border); }
    .theme-nav-link-active { background-color: var(--gb-nav-active); color: var(--gb-accent); border-left-color: var(--gb-accent); border-left-width: 4px; }
    
    /* Component Variables */
    .code-block-container { background-color: var(--gb-code-bg); border-color: var(--gb-border); color: var(--gb-text); }
    .code-block-bar { background-color: var(--gb-code-bar); border-color: var(--gb-border); color: var(--gb-code-bar-text); font-weight: 700; }
    .code-block-bar button { border-color: var(--gb-border) !important; color: var(--gb-code-bar-text) !important; }
    .code-block-bar .bg-slate-400\\/40 { background-color: var(--gb-border) !important; opacity: 0.8; }
    .callout-box { background-color: var(--gb-callout); border-color: var(--gb-accent); color: var(--gb-text); }

    /* General Typography Overrides */
    .prose h1, .prose h2, .prose h3, .prose h4 { color: var(--gb-text) !important; }
    .prose p, .prose li, .prose strong, .prose em { color: var(--gb-text) !important; }
    .prose hr { border-color: var(--gb-border) !important; opacity: 1; border-top-width: 2px; }
    .prose pre { background-color: var(--gb-code-bg); border: 1px solid var(--gb-border); color: var(--gb-text); }
    .prose a { color: var(--gb-accent) !important; }

    /* Force inline code to use theme variables and hide Tailwind's default backticks */
    .prose :not(pre) > code { 
      color: var(--gb-text) !important; 
      background-color: var(--gb-callout) !important; 
      padding: 0.15rem 0.3rem; 
      border-radius: 0.25rem; 
    }
    .prose code::before, .prose code::after { content: none !important; }

    /* Syntax Highlighting Base Resets */
    .hljs { background: transparent !important; color: var(--gb-text) !important; }
    pre code { font-weight: 600; }
    pre code .hl-keyword, .hljs-keyword { color: var(--gb-syn-keyword) !important; font-weight: bold; }
    pre code .hl-function, .hljs-title, .hljs-title\\.class_, .hljs-title\\.function_ { color: var(--gb-syn-func) !important; }
    pre code .hl-string, .hljs-string { color: var(--gb-syn-string) !important; }
    pre code .hl-number, .hljs-number { color: var(--gb-syn-num) !important; }
    pre code .hl-comment, .hljs-comment { color: var(--gb-syn-comment) !important; font-style: italic; }
    pre code .hl-operator, .hljs-punctuation, .hljs-operator, .hljs-type, .hljs-params, .hljs-variable { color: var(--gb-syn-punct) !important; }

    /* Sun / Moon Toggle Switcher Knob */
    [data-theme='cyberpunk'] .theme-knob { transform: translateX(0px); }
    [data-theme='olive'] .theme-knob { transform: translateX(24px); }
    [data-theme='cyberpunk'] .icon-sun { opacity: 0; transform: rotate(-90deg) scale(0.5); }
    [data-theme='cyberpunk'] .icon-moon { opacity: 1; transform: rotate(0deg) scale(1); }
    [data-theme='olive'] .icon-sun { opacity: 1; transform: rotate(0deg) scale(1); }
    [data-theme='olive'] .icon-moon { opacity: 0; transform: rotate(90deg) scale(0.5); }

    /* Interactive Elements & Animations */
    #sidebar { transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), width 0.05s ease-out; will-change: transform, width; }
    #sidebar.collapsed { transform: translateX(-100%); position: absolute; }
    #sidebar-resizer:hover, #sidebar-resizer:active { background-color: var(--gb-accent); opacity: 0.5; }

    .brand-lucy-icon { transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
    .brand-lucy:hover .brand-lucy-icon { transform: rotate(12deg) scale(1.15); }
    .brand-lucy .lucy-happy { opacity: 0; transition: opacity 0.2s ease-in-out; }
    .brand-lucy:hover .lucy-happy { opacity: 1; }
    .brand-lucy:hover .lucy-open { opacity: 0; }

    /* Glitch Animation */
    @keyframes textGlitch {
      0% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, 0px); clip-path: inset(0 -10px 0 -10px); }
      20% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, -1px); clip-path: inset(20% -10px 20% -10px); }
      40% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, 1px); clip-path: inset(40% -10px 40% -10px); }
      100% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, 0px); clip-path: inset(0 -10px 0 -10px); }
    }
    .glitch-hover:hover { animation: textGlitch 0.15s steps(2, start) forwards; }

    /* Drifting & Blinking Star Animations */
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
  book_title: String,
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
                // Uppercase the user's title to match the original vibe!
                [h.text(string.uppercase(book_title))],
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
                  "theme-knob w-6 h-6 rounded-full bg-[#400228] text-slate-900 flex items-center justify-center transition-transform duration-300 shadow-md relative overflow-hidden",
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

  // Check if we are currently inside this folder or any of its sub-folders
  let in_active_trail = is_active_trail(chapter, current_path)

  let base_classes =
    "block px-3 py-2 rounded-md text-sm font-medium transition-all border border-transparent truncate pr-8 "
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
      [h.text(chapter.title)],
    )

  case chapter.children {
    [] -> h.li([], [link])
    children -> {
      let details_attrs = case in_active_trail {
        True -> [a.class("group relative"), a.attribute("open", "true")]
        False -> [a.class("group relative")]
      }

      h.li([], [
        h.details(details_attrs, [
          h.summary(
            [
              a.class(
                "list-none [&::-webkit-details-marker]:hidden cursor-pointer relative",
              ),
            ],
            [
              link,
              h.div(
                [
                  a.class(
                    "absolute right-3 top-1/2 -translate-y-1/2 w-6 h-6 flex items-center justify-center opacity-40 group-hover:opacity-100 transition-opacity",
                  ),
                ],
                [
                  h.span(
                    [
                      a.class(
                        "inline-block text-sm transition-transform duration-200 group-open:rotate-90",
                      ),
                    ],
                    [h.text("▶")],
                  ),
                ],
              ),
            ],
          ),
          // FIX: Added the h.ul block back in so children are actually rendered!
          h.ul(
            [
              a.class(
                "pl-4 ml-2 mt-1 space-y-1 border-l border-slate-700/30 overflow-hidden",
              ),
            ],
            list.map(children, fn(c) {
              render_sidebar_link(c, current_path, base_path)
            }),
          ),
        ]),
      ])
    }
  }
}

fn render_main(
  content: Element(msg),
  prev: Option(Chapter),
  next: Option(Chapter),
  base_path: String,
) -> Element(msg) {
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

      // Previous / Next Footer Navigation
      h.div(
        [
          a.class(
            "max-w-3xl mx-auto mt-16 pt-8 border-t border-slate-700/30 flex justify-between items-center",
          ),
        ],
        [
          case prev {
            Some(p) ->
              h.a(
                [
                  a.href(base_path <> p.path),
                  a.class("group flex flex-col items-start"),
                ],
                [
                  h.span([a.class("text-xs text-slate-500 mb-1")], [
                    h.text("← PREVIOUS"),
                  ]),
                  h.span(
                    [
                      a.class(
                        "text-lg font-bold group-hover:text-[#ffaff3] transition-colors",
                      ),
                    ],
                    [h.text(p.title)],
                  ),
                ],
              )
            None -> h.div([], [])
          },
          case next {
            Some(n) ->
              h.a(
                [
                  a.href(base_path <> n.path),
                  a.class("group flex flex-col items-end text-right"),
                ],
                [
                  h.span([a.class("text-xs text-slate-500 mb-1")], [
                    h.text("NEXT →"),
                  ]),
                  h.span(
                    [
                      a.class(
                        "text-lg font-bold group-hover:text-[#ffaff3] transition-colors",
                      ),
                    ],
                    [h.text(n.title)],
                  ),
                ],
              )
            None -> h.div([], [])
          },
        ],
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
        a.class(
          "absolute inset-0 w-full h-full object-contain filter drop-shadow-[0_0_6px_rgba(255,20,147,0.4)]",
        ),
      ]),
      h.img([
        a.src(base_path <> "assets/lucyhappy.svg"),
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

fn is_active_trail(chapter: Chapter, current_path: String) -> Bool {
  case chapter.path == current_path {
    True -> True
    False ->
      list.any(chapter.children, fn(child) {
        is_active_trail(child, current_path)
      })
  }
}
