# Changelog

All notable changes to lol-web are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-10

Inaugural release. lol-web ships as focused ASDF sub-systems under one umbrella (`:lol-web`) — load only what you use, or load the umbrella for the full surface. All sub-systems are alpha; breaking changes may land between minor versions until v1.

### Added

- **Typed extractor protocol** (`:lol-web/extractors`) — `defhandler` macro with declarative extractors for `:path`, `:query`, `:header`, `:body`, and `:json-body`. Pluggable resolver via the `resolve-extractor` generic; user code registers new extractor kinds with `register-extractor`. String→integer/boolean/keyword/symbol coercions surface a typed `coercion-error` that maps to HTTP 400 at the boundary; missing required values map to HTTP 422.
- **Pre-server-start sentinel** — `*before-server-start-hook*` runs zero-arg validators before `clack:clackup`. The bundled extractor sentinel walks registered handler metadata and refuses to start the server if any handler references an unregistered extractor kind, naming the offending route and kind in the condition.
- **JSON Schema 2020-12 validator** (`:lol-web/jschema`) — subset validator sufficient for OpenAPI 3.1 base-schema validation. Public surface (`parse`, `validate`, `clear-registry`, `get-schema`, plus condition hierarchy) is API-compatible with cl-jschema. Allows `$ref` chains and `$defs` at any nesting depth (both permitted by draft 2020-12 and both required by the OpenAPI 3.1 base schema). Out of scope for this release: `contentEncoding`/`contentMediaType`/`contentSchema`, `$vocabulary`, format-as-assertion, full lexical-stack `$dynamicRef` resolution (same-document anchor lookup is implemented).
- **OpenAPI 3.1 spec emitter** (`:lol-web/openapi`) — `build-openapi-spec` and `emit-openapi-json` walk handler metadata and emit a 3.1-conformant document. Path templating (`:name` → `{name}`), per-extractor schema mapping, and per-content-type request bodies. Emitted output is validated against the upstream OpenAPI 3.1 base schema in the test suite.
- **Server-side reactivity** (`:lol-web/core`) — signals (`make-signal`, `make-computed`, `make-effect`, `batch`) with automatic dependency tracking; `defcomponent` with state, dispatch, and a registry; props, context, and children abstractions.
- **HTML rendering** (`:lol-web/html`, `:lol-web/rendering`) — `htm` macro built on cl-who, `html-page` templates, attribute escaping via `html-attrs`, keyed-list reconciliation.
- **HTML sanitization** (`:lol-web/sanitize`) — separate sub-system for cleaning untrusted HTML; pluggable allow-lists.
- **CSS** (`:lol-web/css`) — design-token system, scoped CSS modules, Tailwind helpers, locked module registry.
- **HTMX integration** (`:lol-web/htmx`, `:lol-web/realtime-htmx`) — built-in runtime, out-of-band swaps, idiomorph integration, autocomplete; WebSocket-driven HTMX with full-jitter reconnect.
- **Real-time** (`:lol-web/realtime`) — WebSocket and SSE servers with broadcast and channel support.
- **Server** (`:lol-web/server`) — Clack/Lack stack with `defroute`, sessions, CSRF (`csrf-token-input`), rate limiting, multipart/form-data parsing, concurrent-safe route registration.
- **Forms** (`:lol-web/forms`) — declarative form definitions; emits `enctype="multipart/form-data"` when any field is `:file`.
- **Devtools** (`:lol-web/devtools`) — surgery mode for live state inspection, snapshots, and undo/redo, wired through a per-render hook.
- **Wizards** (`:lol-web/wizards`) — continuation-based multi-step forms bound to the user's session via owner-token.
- **Fullstack** (`:lol-web/fullstack`) — isomorphic components with server render and client hydration; built-in component-API routes.
- **Optimization** (`:lol-web/optimization`) — `reactive-let`, `with-reactive-bindings`, and a CSS-prefix registry distinct from the exact-class registry.
- **Parenscript helpers** (`:lol-web/parenscript`) — protocol-derived WebSocket scheme, on-mount accessor.
- **Resources** (`:lol-web/resources`) — static-asset registration.
- **Client runtime** (`:lol-web/client-runtime`) — bundled JS for the client side of fullstack components.
- **Per-sub-system test systems** — each `:lol-web/<n>` sub-system has its own `:lol-web/<n>/test` ASDF system; `:lol-web/test` aggregates all suites and runs them via `(lol-web/test:run-all-tests)`.
- **ASDF drift check** — `lol-web.asd` is generated from `nix/module-table.nix`; a build-time check fails if the on-disk `.asd` drifts from what the module table would generate.
- **Umbrella facade-completeness check** — a regression test walks every `:lol-web/<n>` sub-system's external symbols and asserts each is also external in `:lol-web` (pointing at the same symbol object). Adding a sub-system without re-exporting it fails the test.
- **GitHub Actions** — `build.yml` runs `nix flake check` covering every sub-system, the asdf-drift check, and the umbrella; `external-consumer.yml` builds `.#default` from a fresh checkout to prove the public artifact composes against the flake's declared inputs alone.
- **Flake outputs** — `checks.<system>.{library, asdf-drift, module-<n>}` exposing 22 checks per supported system.

### Removed

- `defapi` macro and `json-body` defun from `:lol-web/server`. Migrate call sites to `defhandler` with the `:json-body` extractor: `(defhandler create-thing ((data :json-body)) ...)`. No back-compat shim.
- `csrf-input` from `:lol-web/server`. Use `csrf-token-input` instead; it renders the same hidden CSRF input but escapes attributes via `html-attrs`.

### Notes

- The `:lol-reactive` package remains as a thin shim that re-exports `:lol-web` for users mid-migration. Prefer `:lol-web` directly in new code; the shim is not guaranteed past v1.
- No migration guide ships with this release. Renames and removals are tracked in this changelog and in commit history.
