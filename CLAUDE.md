## Project Overview

**QField4OBM** — QField app-wide plugin (QML/JavaScript only, no Python) for syncing with OpenBioMaps (OBM) biodiversity servers.

- **Stack:** Pure QML + JS (Qt V4) · QField 3.0+ · OBM API v3 (REST + GraphQL) · Bearer token auth
- **Deploy:** `./package_plugin.sh` → ZIP + copy to plugin dir & Nextcloud share. Use **Plugin Reloader** during dev.
- **Tests:** `npm run test:all` (runs `jest` JS tests and `qmltestrunner` UI tests). Standalone JS tests are in `tests/js/`. QML UI tests are in `tests/qml/`.
- **Linting:** `npm run lint` (runs ESLint for JS and qmllint for QML).
## Architecture

| Layer | File | Role |
|---|---|---|
| Entry point | `main.qml` | Toolbar button, login state, UI root, `scratchLayers[]` |
| Auth | `scripts/AuthManager.js` | Login, token persistence (QSettings), auto-refresh on 401/403 |
| Network | `scripts/ApiClient.js` | XHR wrapper, pagination, token expiry |
| Sync | `scripts/SyncEngine.js` | Pull/push orchestration, GeoPackage I/O, delta-sync via `obm_id` |
| UI | `components/GraphQLFilterBuilder.qml` | Dynamic GraphQL filter builder |
| UI | `components/StyleAndBboxPanel.qml` | Style + bbox settings, area-limit enforcement |

**Storage:** tokens → QSettings · spatial data → GeoPackage (`.gpkg`) · metadata → project variables · layer properties → obm_layer_registry.json

## Coding Rules

1. **Network:** async XHR only — no synchronous requests.
2. **File I/O:** QGIS/QField API bindings only — no plain JS `FileReader` hacks.
3. **UI:** always use QField's `Theme` singleton (colors, sizes); min touch target **48×48 px**.
4. **C++ objects** (`GeometryUtils`, `FeatureUtils`, etc.): verify availability in QML context before use.
5. **Language:** English everywhere — code, comments, docs.

## Key References

| File | Content |
|---|---|
| `resources/OBM-Project-API.md` | OBM REST API |
| `resources/GraphQLUserGuide.md` | GraphQL schema & examples |
| `context/Theme Properties in QField.md` | Theme properties we use to make the plugin look like QField |
| `context/qfield-v4.1.3/` | QField source code for reference |
