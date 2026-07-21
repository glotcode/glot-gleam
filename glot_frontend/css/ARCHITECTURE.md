# CSS architecture

The cascade is an explicit dependency graph. `styles.css` is the public entry
point and declares the only layer order:

`reset -> tokens -> base -> components -> pages -> admin -> overrides`

## Ownership

- `tokens.css` owns theme values, color values, focus geometry, control sizing,
  and motion constants. Other stylesheets consume custom properties and must
  not introduce literal colors.
- `base.css` owns unclassed document elements and typography.
- `components.css` owns reusable application-shell and component classes.
- Page stylesheets own only their feature-prefixed classes.
- `admin.css` is delivered through `admin-entry.css`; public pages do not pay
  for admin-only rules.
- `accessibility.css` is the final override layer. It owns cross-feature focus,
  target-size, contrast, forced-color, reduced-motion, and invalid-state rules.

Feature styles may consume earlier layers. They must not depend on the source
order of another file in the same layer. If two features need the same rule,
promote it to a component or token instead of reaching across feature classes.

`npm run check:css` protects the layer order, entry-point separation, token-only
color ownership, and the required accessibility media queries.
