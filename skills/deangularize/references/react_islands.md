# Phase 3: React islands

Islands are server-rendered mount points that React hydrates. Use them only where a widget holds
real client state that an Unpoly layer plus fragment updates cannot model cheaply. React is a new
dependency unless the project has it: ask first.

## When an island, when Unpoly

| Island | Unpoly (layer, fragment, compiler) |
|---|---|
| Nested drag & drop with undo (template/flex builders) | Pickers, confirmations, simple dialogs |
| Bulk editing many selected records with "(mixed)" semantics | Forms, even with dependent fields (`up-validate`) |
| Upload of many files with progress, metadata extraction, preview | Single file fields (compiler + hidden cache field) |
| Date/time picker without an approved library | Sorting a flat list (SortableJS compiler) |
| | A tree editor can go either way; a compiler with SortableJS worked for a big tree |

Guiding question: does the widget need state that lives longer than one request and changes with
every interaction? Then an island. Otherwise Unpoly is less code and closer to Rails.

## Infrastructure

- **One mount compiler**: `[data-react-island="<name>"][data-react-props="<json>"]`, looks the
  component up in a registry, `createRoot(el).render(...)`, returns a destructor that unmounts.
  Queue the unmount (`queueMicrotask`) so an island inside another island's render does not warn.
- **Helper** that renders the mount div with JSON props from the server (escape properly).
- JSX only in `.jsx` files and **always `import React`**: esbuild may use the classic transform in
  one build mode and the automatic runtime in another; "React is not defined" then shows only in
  the dev server while specs (test build) pass. Check ESLint's file globs cover `.jsx` or decide
  consciously that they do not.
- Keep the island over fragment updates with `up-keep` and an id (e.g. after a failed save of the
  surrounding form, so undo history survives); re-render from submitted data when the server has
  the newer state.

## Embedding existing compilers in an island

Do not rebuild a Tom Select or picker in React. An `UnpolyWidget` component creates the widget's
element outside React (`document.createElement`, `up-data`), calls `up.hello`, and on cleanup
`up.destroy` while the element is still attached. React renders only an empty host. New data →
new `key`. Changes come back through custom events the compilers dispatch
(`tag-select:change` with `{ ids, tags }`, a hidden field's `change`; filter by
`event.target.type`, Tom Select also fires `change` on its text input). DOM and spec helpers stay
the same as in server-rendered forms.

## Talking to the server

- Islands keep using JSON endpoints (category c). A small `apiRequest` helper adds the CSRF
  header, throws an error object with the response body, and lets callers show flashes from the
  response meta after `up.navigate` (show them after navigating, or the render replaces them).
- Uploads with progress: XHR plus the existing poll endpoint; reject with `Error` subclasses
  (ESLint requires error objects); support cancel.
- **Global loading indicator**: legacy `$http` interceptors showed a spinner for every request.
  Count running `apiRequest`/uploads (not `keepalive` requests) and show an indicator in the
  layout while the count is positive; count an upload with its polls as one, or it flickers.
- Disable the island's save buttons while saving (a second click creates duplicates).
- Server-rendered sub-forms inside an island (builder item forms, previews): the server renders
  the form with the existing building blocks; the island reads it back with typed serialization
  (`data-type="json|number|record"`) when the data is stored untyped (JSON columns would get "1"
  instead of `true`). Parse nested forms through a detached `<template>` (the HTML parser drops a
  `<form>` inside a form).

## Integration with the page

- **Unload alert**: wrap the island in a server-rendered `form.form[name]` with
  `up-submit="false"`; the island dispatches a bubbling `change` on edits and
  `unload-alert:reset` after saving. All buttons `type="button"`, links without `href`.
- **Locks per record**: acquire through the API, store codes in sessionStorage with the same
  prefix as the form lock compiler (lists hide own locks), refresh on the interval, release on
  removal, `pagehide` and unmount; keep the codes after release until the next page has rendered.
- **Panels**: a React panel component that reads and writes the same collapse storage as the
  panel compiler (compilers must not touch React-owned DOM).

## React-specific traps

- Inputs that other code writes into (a header widget inserting text and firing `input`): render
  them uncontrolled (`defaultValue` + `onInput`, `key` per selection); React's value tracker drops
  external changes on controlled inputs.
- Spec helpers dispatch native `mouseleave`; React's `onMouseLeave` is built on `mouseout` and
  does not see it. Attach native listeners via `ref` for hover behavior. After a dialog closes over
  an element, it gets no `mouseenter`: also open popovers on `mousemove`.
- jQuery's `.click()` does not natively click links; Angular listened through jQuery, React does
  not. Spec helpers should call `element.click()`.
- `crypto.randomUUID` and the Clipboard API exist only in secure contexts; test hosts over HTTP
  are not secure unless Chrome is told to treat them so. Use `crypto.getRandomValues`.
- SortableJS drags only direct children of the list it was created on; for deeply nested,
  frequently re-rendered structures write a small pointer-based drag handler and recompute the
  drop target on `mouseup` (the page may have auto-scrolled).
- Measure what legacy scripts measured (e.g. a spacer height under a fixed toolbar) with a
  `ResizeObserver`; otherwise content slides under fixed elements.

## Contract documentation

Per island, record in the plan or catalog: props (JSON shape), endpoints it calls, events it
emits and listens to, DOM contracts specs rely on, how the surrounding form saves.
