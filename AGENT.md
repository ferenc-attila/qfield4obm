# QField4OBM - AI Guide

This document provides concise rules for AI assistants (like Gemini, Claude or Copilot) operating in this repository.

## Project Context
- **Type**: QField Plugin (Pure QML + JS). **No Python** bindings exist in QField.
- **Goal**: Bi-directional data sync between QField clients and OpenBioMaps (OBM) servers using REST/GraphQL APIs.
- **Data Transport**: Downloaded vector data is written into local GeoPackage (`.gpkg`) files.

## Environment & Scripts
- **JS Testing (Jest)**: `npm run test:js` (Located in `tests/js/`)
- **QML Testing (QTest)**: `npm run test:qml` (Located in `tests/qml/`)
- **Combined Tests**: `npm run test:all`
- **Linting (ESLint + qmllint)**: `npm run lint`

## Strict Coding Rules
1. **No Python**: Do not generate PyQGIS code. Use QML/JavaScript exclusively.
2. **Async Only**: Use asynchronous `XMLHttpRequest` for API calls. Synchronous JS is forbidden as it blocks the QField UI.
3. **QField Theming**: Use QField's internal `Theme` singleton (e.g. `Theme.primaryColor`) instead of hardcoded hex values to support dark/light modes.
4. **Error Handling**: Use `try...catch` loops carefully when invoking C++ functions from JS to trap `TypeError`s.
5. **English Only**: Write all comments, commit messages, and variable names in English.
6. **Tests are Mandatory**: When creating a new JS utility or QML component, create a corresponding test file in the `tests/` directory.
