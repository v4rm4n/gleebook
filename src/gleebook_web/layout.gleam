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
      h.head(
        [],
        list.append(
          [
            h.meta([a.charset("utf-8")]),
            h.meta([
              a.name("viewport"),
              a.content("width=device-width, initial-scale=1.0"),
            ]),
            h.title([], title),
            h.script([], theme_bootstrap_js),
            h.link([
              a.rel("stylesheet"),
              a.href(base_path <> "assets/gleebook.css"),
            ]),
            h.link([a.rel("stylesheet"), a.href(hljs_css_url)]),
            render_theme_styles(),
            h.link([a.rel("stylesheet"), a.href(base_path <> "custom.css")]),
          ],
          prefetch_links(prev, next, base_path),
        ),
      ),

      h.body(
        [a.class("theme-body font-mono flex overflow-hidden relative z-0")],
        [
          render_lucies(base_path),
          render_sidebar(book_title, chapters, current_path, base_path),
          h.div(
            [a.id("gb-scrim"), a.attribute("onclick", "toggleSidebar()")],
            [],
          ),
          render_main(content, prev, next, base_path),
          h.script([], ui_js),
          h.script([a.src(hljs_js_url), a.attribute("defer", "")], ""),
          h.script(
            [],
            "document.addEventListener('DOMContentLoaded', () => { if (window.hljs) hljs.highlightAll(); });",
          ),
          h.script([], live_reload_js(base_path)),
        ],
      ),
    ],
  )
}

const hljs_css_url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/tokyo-night-dark.min.css"

const hljs_js_url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"

const theme_bootstrap_js = "
let savedTheme = new URLSearchParams(window.location.search).get('theme');
if (!savedTheme) { try { savedTheme = localStorage.getItem('gleebook-theme'); } catch(e) {} }
if (!savedTheme) { savedTheme = window.name; }
if (savedTheme === 'cyberpunk' || savedTheme === 'olive') {
  document.documentElement.setAttribute('data-theme', savedTheme);
}

// Bumping mobile breakpoint to 1024px to cover large phones and tablets in portrait
const gbMobile = window.matchMedia('(max-width: 1024px)');
(function () {
  const root = document.documentElement;
  let width = null, collapsed = null;
  try {
    width = localStorage.getItem('gleebook-sidebar-width');
    collapsed = localStorage.getItem('gleebook-sidebar-collapsed');
  } catch(e) {}
  if (width) root.style.setProperty('--gb-sidebar-w', width + 'px');
  root.setAttribute('data-sidebar', gbMobile.matches || collapsed === 'true' ? 'hidden' : 'shown');
})();

function toggleSidebar() {
  const root = document.documentElement;
  const hide = root.getAttribute('data-sidebar') !== 'hidden';
  root.setAttribute('data-sidebar', hide ? 'hidden' : 'shown');
  if (!gbMobile.matches) {
    try { localStorage.setItem('gleebook-sidebar-collapsed', hide); } catch(e) {}
  }
}
"

const ui_js = "
const root = document.documentElement;
const sidebar = document.getElementById('sidebar');
const handle = document.getElementById('sidebar-resizer');

// PJAX Router for instant SPA-like navigation
document.addEventListener('click', async (e) => {
  const link = e.target.closest('a');
  if (!link || !link.href) return;
  
  try {
    const url = new URL(link.href);
    if (url.origin !== window.location.origin && url.protocol !== 'file:') return;
    
    const currentTheme = root.getAttribute('data-theme');
    if (currentTheme) {
      url.searchParams.set('theme', currentTheme);
      link.href = url.toString();
    }
    
    if (link.hasAttribute('download') || link.hasAttribute('target') || e.ctrlKey || e.metaKey || e.shiftKey || e.button !== 0) return;
    
    const lastSegment = url.pathname.substring(url.pathname.lastIndexOf('/') + 1);
    if (lastSegment.includes('.') && !lastSegment.endsWith('.html')) return;
    
    e.preventDefault();
    if (gbMobile.matches) root.setAttribute('data-sidebar', 'hidden');
    
    const res = await fetch(url.href);
    if (!res.ok) throw new Error('Fetch failed');
    const text = await res.text();
    const doc = new DOMParser().parseFromString(text, 'text/html');
    
    // Swap main content and active sidebar links seamlessly
    document.getElementById('gb-main').innerHTML = doc.getElementById('gb-main').innerHTML;
    const newNav = doc.getElementById('gb-nav-links');
    if (newNav) document.getElementById('gb-nav-links').innerHTML = newNav.innerHTML;
    document.title = doc.title;
    
    window.history.pushState({}, '', url.href);
    document.getElementById('gb-main').scrollTo(0, 0);
    if (window.hljs) window.hljs.highlightAll();
  } catch(err) {
    if (link.href) window.location.href = link.href;
  }
});

window.addEventListener('popstate', () => window.location.reload());

requestAnimationFrame(() => requestAnimationFrame(() => root.classList.add('gb-ready')));

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && root.getAttribute('data-sidebar') === 'shown' && gbMobile.matches) toggleSidebar();
});

gbMobile.addEventListener('change', (e) => {
  let collapsed = null;
  try { collapsed = localStorage.getItem('gleebook-sidebar-collapsed'); } catch(err) {}
  root.setAttribute('data-sidebar', e.matches || collapsed === 'true' ? 'hidden' : 'shown');
});

if (handle && sidebar) {
  let width = null;
  const move = (e) => {
    width = Math.max(160, Math.min(e.clientX, 480));
    root.style.setProperty('--gb-sidebar-w', width + 'px');
  };
  const stop = () => {
    handle.removeEventListener('pointermove', move);
    handle.removeEventListener('pointerup', stop);
    handle.removeEventListener('pointercancel', stop);
    root.classList.remove('gb-resizing');
    document.body.style.cursor = '';
    document.body.style.userSelect = '';
    if (width !== null) {
      try { localStorage.setItem('gleebook-sidebar-width', width); } catch(e) {}
    }
  };
  handle.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    handle.setPointerCapture(e.pointerId);
    root.classList.add('gb-resizing');
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    handle.addEventListener('pointermove', move);
    handle.addEventListener('pointerup', stop);
    handle.addEventListener('pointercancel', stop);
  });
}
"

fn live_reload_js(base_path: String) -> String {
  "
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
  let currentVersion = null;
  setInterval(() => {
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
"
}

fn prefetch_links(
  prev: Option(Chapter),
  next: Option(Chapter),
  base_path: String,
) -> List(Element(msg)) {
  [prev, next]
  |> list.filter_map(fn(chapter) {
    case chapter {
      Some(c) -> Ok(h.link([a.rel("prefetch"), a.href(base_path <> c.path)]))
      None -> Error(Nil)
    }
  })
}

fn render_theme_styles() -> Element(msg) {
  h.style(
    [],
    "
    /* Fix mobile tap highlights and stray cursors */
    * {
      -webkit-tap-highlight-color: rgba(0, 0, 0, 0) !important;
      -webkit-tap-highlight-color: transparent !important;
    }

    #sidebar, #sidebar *, button, .brand-lucy {
      -webkit-user-select: none !important;
      user-select: none !important;
      -webkit-touch-callout: none !important;
      outline: none !important;
    }

    .brand-lucy img {
      pointer-events: none;
      user-select: none !important;
      -moz-user-select: none !important;
      -webkit-user-drag: none !important;
      background: none !important;
      padding: 0 !important;
      border: 0 !important;
      border-radius: 0 !important;
    }
    
    .brand-lucy, .brand-lucy-icon {
      outline: none !important;
      box-shadow: none !important;
    }

    #gb-open-sidebar { transition: opacity var(--gb-sidebar-t) var(--gb-ease), visibility 0s; }
    html[data-sidebar='shown'] #gb-open-sidebar {
      opacity: 0;
      visibility: hidden;
      transition: opacity var(--gb-sidebar-t) var(--gb-ease), visibility 0s linear var(--gb-sidebar-t);
    }

    :root, [data-theme='cyberpunk'] {
      --gb-bg: #0d0914;
      --gb-text: #fffbe8;
      --gb-sidebar: rgba(13, 9, 20, 0.88);
      --gb-border: rgba(255, 175, 243, 0.15);
      --gb-accent: #ffaff3;
      --gb-nav-text: #94a3b8;
      --gb-nav-hover: rgba(255, 175, 243, 0.1);
      --gb-nav-active: rgba(255, 175, 243, 0.15);
      --gb-code-bg: rgba(18, 13, 28, 0.8);
      --gb-code-bar: rgba(9, 6, 15, 0.8);
      --gb-code-bar-text: #ffaff3;
      --gb-callout: rgba(255, 175, 243, 0.1);
      
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
      
      --gb-syn-keyword: #6b21a8;
      --gb-syn-func: #1d4ed8;
      --gb-syn-string: #15803d;
      --gb-syn-num: #b45309;
      --gb-syn-comment: #64748b;
      --gb-syn-punct: #1a221b;
    }

    .theme-body { background-color: var(--gb-bg); color: var(--gb-text); }
    .theme-sidebar { background-color: var(--gb-sidebar); border-color: var(--gb-border); color: var(--gb-nav-text); }
    .theme-brand { color: var(--gb-accent); }
    
    [data-theme='cyberpunk'] .theme-lucies { display: block; }
    [data-theme='olive'] .theme-lucies { display: none !important; }
    [data-theme='cyberpunk'] .lucy-open  { filter: drop-shadow(0 0 2px #ff1493); }
    [data-theme='cyberpunk'] .lucy-happy { filter: drop-shadow(0 0 3px #ff1493); }
    
    .theme-nav-link { color: var(--gb-nav-text); }
    .theme-nav-link:hover { background-color: var(--gb-nav-hover); color: var(--gb-accent); border-color: var(--gb-border); }
    .theme-nav-link-active { background-color: var(--gb-nav-active); color: var(--gb-accent); border-left-color: var(--gb-accent); border-left-width: 4px; }
    
    .code-block-container { background-color: var(--gb-code-bg); border-color: var(--gb-border); color: var(--gb-text); }
    .code-block-bar { background-color: var(--gb-code-bar); border-color: var(--gb-border); color: var(--gb-code-bar-text); font-weight: 700; }
    .code-block-bar button { border-color: var(--gb-border) !important; color: var(--gb-code-bar-text) !important; }
    .code-block-bar .bg-slate-400\\/40 { background-color: var(--gb-border) !important; opacity: 0.8; }
    .callout-box { background-color: var(--gb-callout); border-color: var(--gb-accent); color: var(--gb-text); }

    .prose h1, .prose h2, .prose h3, .prose h4 { color: var(--gb-text) !important; }
    .prose p, .prose li, .prose strong, .prose em { color: var(--gb-text) !important; }
    .prose hr { border-color: var(--gb-border) !important; opacity: 1; border-top-width: 2px; }
    .prose pre { background-color: var(--gb-code-bg); border: 1px solid var(--gb-border); color: var(--gb-text); }
    .prose a { color: var(--gb-accent) !important; }

    .prose table { width: 100%; border-collapse: collapse; margin-top: 1.5rem; margin-bottom: 1.5rem; }
    .prose th { background-color: rgba(255, 255, 255, 0.05); font-weight: 700; padding: 0.75rem 1rem; border-bottom: 2px solid var(--gb-border); text-align: left; }
    .prose td { padding: 0.75rem 1rem; border-bottom: 1px solid var(--gb-border); }
    .prose tr:hover { background-color: rgba(255, 255, 255, 0.02); }

    .prose :not(pre) > code { 
      color: var(--gb-text) !important; 
      background-color: var(--gb-callout) !important; 
      padding: 0.15rem 0.3rem; 
      border-radius: 0.25rem; 
    }
    .prose code::before, .prose code::after { content: none !important; }

    .hljs { background: transparent !important; color: var(--gb-text) !important; }
    pre code { font-weight: 600; }
    pre code .hl-keyword, .hljs-keyword { color: var(--gb-syn-keyword) !important; font-weight: bold; }
    pre code .hl-function, .hljs-title, .hljs-title\\.class_, .hljs-title\\.function_ { color: var(--gb-syn-func) !important; }
    pre code .hl-string, .hljs-string { color: var(--gb-syn-string) !important; }
    pre code .hl-number, .hljs-number { color: var(--gb-syn-num) !important; }
    pre code .hl-comment, .hljs-comment { color: var(--gb-syn-comment) !important; font-style: italic; }
    pre code .hl-operator, .hljs-punctuation, .hljs-operator, .hljs-type, .hljs-params, .hljs-variable { color: var(--gb-syn-punct) !important; }

    [data-theme='cyberpunk'] .theme-knob { transform: translateX(0px); }
    [data-theme='olive'] .theme-knob { transform: translateX(24px); }
    [data-theme='cyberpunk'] .icon-sun { opacity: 0; transform: rotate(-90deg) scale(0.5); }
    [data-theme='cyberpunk'] .icon-moon { opacity: 1; transform: rotate(0deg) scale(1); }
    [data-theme='olive'] .icon-sun { opacity: 1; transform: rotate(0deg) scale(1); }
    [data-theme='olive'] .icon-moon { opacity: 0; transform: rotate(90deg) scale(0.5); }

    :root { --gb-sidebar-w: 16rem; --gb-sidebar-t: 0.3s; --gb-ease: cubic-bezier(0.4, 0, 0.2, 1); }
    .theme-body { height: 100vh; height: 100dvh; }
    #sidebar { position: fixed; top: 0; bottom: 0; left: 0; width: var(--gb-sidebar-w); transform: translateX(0); }
    html[data-sidebar='hidden'] #sidebar { transform: translateX(calc(-1 * var(--gb-sidebar-w) - 2px)); }
    #gb-main { margin-left: var(--gb-sidebar-w); }
    html[data-sidebar='hidden'] #gb-main { margin-left: 0; }
    html.gb-ready #sidebar { transition: transform var(--gb-sidebar-t) var(--gb-ease); }
    html.gb-ready #gb-main { transition: margin-left var(--gb-sidebar-t) var(--gb-ease); }
    html.gb-resizing #sidebar, html.gb-resizing #gb-main { transition: none; }
    #sidebar-resizer:hover, #sidebar-resizer:active { background-color: var(--gb-accent); opacity: 0.5; }
    #gb-scrim { display: none; }

    /* HARDENED MOBILE OVERRIDES (1024px to cover tablets) */
    @media screen and (max-width: 1024px) {
      #gb-main { margin-left: 0 !important; padding-top: 4rem; }
      #sidebar { width: 85vw !important; max-width: 320px !important; box-shadow: 0 0 40px rgba(0, 0, 0, 0.5); padding-left: max(1rem, env(safe-area-inset-left, 1rem)); }
      [data-theme='cyberpunk'] .theme-sidebar { background-color: #0f0a17; }
      html[data-sidebar='hidden'] #sidebar { transform: translateX(-100%) !important; }
      #sidebar-resizer { display: none !important; }
      #gb-scrim { display: block; position: fixed; inset: 0; z-index: 15; background: rgba(0, 0, 0, 0.5); opacity: 0; pointer-events: none; }
      html.gb-ready #gb-scrim { transition: opacity var(--gb-sidebar-t) var(--gb-ease); }
      html[data-sidebar='shown'] #gb-scrim { opacity: 1; pointer-events: auto; }
      .theme-nav-link { padding-top: 0.625rem; padding-bottom: 0.625rem; }
      .theme-lucies { display: none !important; }
    }

    @media (prefers-reduced-motion: reduce) {
      #sidebar, #gb-main, #gb-scrim, #gb-open-sidebar { transition: none !important; }
    }

    .nav-chevron-wrap { color: var(--gb-nav-text); opacity: 0.7; }
    summary:hover .nav-chevron-wrap,
    details[open] > summary .nav-chevron-wrap { color: var(--gb-accent); opacity: 1; }
    details[open] > summary .nav-chevron { transform: rotate(90deg); }

    .brand-lucy-icon { transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
    .brand-lucy:hover .brand-lucy-icon { transform: rotate(12deg) scale(1.15); }
    .brand-lucy .lucy-happy { opacity: 0; transition: opacity 0.2s ease-in-out; }
    .brand-lucy:hover .lucy-happy { opacity: 1; }
    .brand-lucy:hover .lucy-open { opacity: 0; }

    @keyframes textGlitch {
      0% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, 0px); clip-path: inset(0 -10px 0 -10px); }
      20% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, -1px); clip-path: inset(20% -10px 20% -10px); }
      40% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, 1px); clip-path: inset(40% -10px 40% -10px); }
      100% { text-shadow: 0.5px 0 0 var(--gb-accent), -0.5px 0 0 #ff1493; transform: translate(0px, 0px); clip-path: inset(0 -10px 0 -10px); }
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
    .lucy-1, .lucy-2, .lucy-3 { will-change: transform; }

    @media (prefers-reduced-motion: reduce) {
      .lucy-1, .lucy-2, .lucy-3, .lucy-blink-overlay, .glitch-hover:hover { animation: none !important; }
    }

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
        "theme-sidebar border-r p-4 overflow-y-auto z-20 flex flex-col justify-between",
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
        // ID added to nav here so the PJAX router can locate and update it
        h.nav([a.id("gb-nav-links"), a.class("space-y-1")], [
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
  let is_label_only = chapter.path == ""
  let is_active = chapter.path == current_path && !is_label_only

  let in_active_trail = is_active_trail(chapter, current_path)

  let base_classes =
    "block px-3 py-2 rounded-md text-sm font-medium transition-all border border-transparent truncate "
  let state_classes = case is_active {
    True -> "theme-nav-link-active"
    False -> "theme-nav-link"
  }

  let text_content = case is_label_only {
    True ->
      h.div([a.class(base_classes <> "theme-nav-link opacity-80")], [
        h.text(chapter.title),
      ])
    False ->
      h.a(
        [
          a.href(base_path <> chapter.path),
          a.class(base_classes <> state_classes),
        ],
        [h.text(chapter.title)],
      )
  }

  case chapter.children {
    [] -> h.li([], [text_content])
    children -> {
      let details_attrs = case in_active_trail {
        True -> [a.class("nav-group"), a.attribute("open", "true")]
        False -> [a.class("nav-group")]
      }

      h.li([], [
        h.details(details_attrs, [
          h.summary(
            [
              a.class(
                "list-none [&::-webkit-details-marker]:hidden cursor-pointer flex items-stretch",
              ),
            ],
            [
              h.div([a.class("flex-1 min-w-0")], [text_content]),
              h.div(
                [
                  a.class(
                    "nav-chevron-wrap w-8 flex-shrink-0 flex items-center justify-center transition-all",
                  ),
                ],
                [
                  h.span(
                    [
                      a.class(
                        "nav-chevron inline-block text-sm transition-transform duration-200",
                      ),
                    ],
                    [h.text("▶")],
                  ),
                ],
              ),
            ],
          ),
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
      a.id("gb-main"),
      a.class(
        "flex-1 overflow-y-auto p-4 sm:p-8 lg:p-12 relative z-10 min-w-0 max-w-full",
      ),
    ],
    [
      h.button(
        [
          a.id("gb-open-sidebar"),
          a.attribute("onclick", "toggleSidebar()"),
          a.class(
            "fixed top-4 left-4 z-30 p-2 rounded-md border border-current bg-[var(--gb-bg)] opacity-70 hover:opacity-100 transition-opacity cursor-pointer shadow-md text-xs",
          ),
          a.attribute("title", "Toggle Sidebar"),
        ],
        [h.text("☰")],
      ),

      h.div(
        [
          a.class(
            "max-w-3xl mx-auto prose dark:prose-invert prose-headings:text-current prose-a:text-current w-full break-words",
          ),
        ],
        [content],
      ),

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
  let is_match = chapter.path == current_path && chapter.path != ""
  case is_match {
    True -> True
    False ->
      list.any(chapter.children, fn(child) {
        is_active_trail(child, current_path)
      })
  }
}
