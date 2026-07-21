# glot_frontend

The browser frontend for Glot. It contains separate public and administration
Lustre applications, feature state machines, browser integrations, and the
Vite entry points used by `glot_backend`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries and conventions.

## Development

```sh
npm run dev          # Compile on changes and run Vite
npm test             # Run Gleam scenarios and JavaScript platform tests
npm run check:boundaries  # Enforce configured managed-feature boundaries
gleam test           # Run Gleam unit and integration scenarios
npm run test:javascript  # Run custom-element and platform FFI tests
npm run build        # Build assets into glot_backend/priv/static
```
