# lol-reactive

Server-side reactive web framework for Common Lisp. Renders HTML on the server, updates the page over HTMX, WebSockets, or SSE.

Built on [Let Over Lambda](https://letoverlambda.com/) patterns: signals are closures, components are closures, token sets are closures.

## Features

- **Signals** -- `make-signal`, `make-computed`, `make-effect`, and `batch` with automatic dependency tracking
- **Components** -- `defcomponent` with state, dispatch, and a registry
- **HTML** -- `htm` macro (cl-who) with `html-page` templates and XSS escaping
- **CSS** -- design token system, scoped CSS modules, Tailwind helpers
- **HTMX** -- built-in runtime, OOB swaps, morph (idiomorph), autocomplete
- **Real-time** -- WebSocket and SSE servers with broadcast and channel support
- **Server** -- Clack/Lack stack with routing (`defroute`, `defapi`), sessions, CSRF, rate limiting
- **Devtools** -- "surgery mode" for live state inspection, snapshots, and undo/redo
- **Wizards** -- continuation-based multi-step forms
- **Fullstack** -- isomorphic components with server render + client hydration

## Usage

Add as a flake input:

```nix
{
  inputs.lol-reactive.url = "github:kleisli-io/lol-reactive";

  outputs = { lol-reactive, ... }:
    let
      inherit (lol-reactive.inputs.cl-deps.lib.x86_64-linux) buildLisp;
      lol = lol-reactive.lib.x86_64-linux.library;
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
(defpackage :my-app (:use :cl :lol-reactive))
(in-package :my-app)

(defroute "/" ()
  (html-response
    (html-page (:title "Hello")
      (htm (:h1 "It works")))))

(defun main ()
  (start-server :port 8080))
```

## Running tests

Tests run at build time via FiveAM. `nix build` fails if any test fails.

## License

[MIT](LICENSE)
