# lol-web

Server-side reactive web framework for Common Lisp. Renders HTML on the server, updates the page over HTMX, WebSockets, or SSE.

Built on [Let Over Lambda](https://letoverlambda.com/) patterns: signals are closures, components are closures, token sets are closures.

## Features

- **Signals** — `make-signal`, `make-computed`, `make-effect`, and `batch` with automatic dependency tracking
- **Components** — `defcomponent` with state, dispatch, and a registry
- **HTML** — `htm` macro (cl-who) with `html-page` templates and `html-attrs` attribute escaping; separate `:lol-web/sanitize` sub-system for untrusted HTML
- **CSS** — design token system, scoped CSS modules, Tailwind helpers
- **HTMX** — built-in runtime, OOB swaps, morph (idiomorph), autocomplete; WebSocket-driven HTMX with full-jitter reconnect
- **Real-time** — WebSocket and SSE servers with broadcast and channel support
- **Server** — Clack/Lack stack with `defroute`, `defhandler` (typed `:path`/`:query`/`:header`/`:body`/`:json-body` extractors), sessions, CSRF, rate limiting, multipart/form-data
- **OpenAPI** — emit OpenAPI 3.1 specs from `defhandler` metadata; subset JSON Schema 2020-12 validator (`:lol-web/jschema`)
- **Devtools** — surgery mode for live state inspection, snapshots, and undo/redo
- **Wizards** — continuation-based multi-step forms
- **Fullstack** — isomorphic components with server render and client hydration

## Sub-systems

lol-web ships as focused ASDF sub-systems under one umbrella (`:lol-web`):

`sanitize`, `core`, `css`, `parenscript`, `html`, `server`, `jschema`,
`extractors`, `openapi`, `client-runtime`, `rendering`, `resources`,
`htmx`, `realtime`, `realtime-htmx`, `forms`, `optimization`, `devtools`,
`wizards`, `fullstack`. Load only what you use (`:lol-web/<n>`), or load
the umbrella for the full surface.

## Usage

Add as a flake input:

```nix
{
  inputs.lol-web.url = "github:kleisli-io/lol-web";

  outputs = { lol-web, ... }:
    let
      inherit (lol-web.inputs.cl-deps.lib.x86_64-linux) buildLisp;
      lol = lol-web.lib.x86_64-linux.library;
    in {
      packages.default = buildLisp.program {
        name = "my-app";
        deps = [ lol ];
        srcs = [ ./src/app.lisp ];
        main = "my-app:main";
      };
    };
}
```

## Quick start

```lisp
(defpackage :my-app (:use :cl :lol-web))
(in-package :my-app)

(defroute "/" ()
  (html-response
    (html-page (:title "Hello")
      (htm (:h1 "It works")))))

(defhandler get-thing ((id :path :type integer))
  (html-response
    (htm (:p "thing " (princ-to-string id)))))

(defun main ()
  (start-server :port 8080))
```

## Running tests

Tests run at build time via FiveAM. `nix build` fails if any test fails.

## License

[MIT](LICENSE)
