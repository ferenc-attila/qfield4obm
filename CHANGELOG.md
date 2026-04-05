# Changelog

All notable changes to QField4OBM will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-04-05

### Added
- Initial plugin structure with QML/JS architecture
- Bearer token authentication via OBM REST API (`AuthManager.js`)
- XHR-based API client with pagination and token refresh (`ApiClient.js`)
- Pull/push sync engine with delta-sync via `obm_id` (`SyncEngine.js`)
- Dynamic GraphQL filter builder component (`GraphQLFilterBuilder.qml`)
- Style and bounding-box settings panel (`StyleAndBboxPanel.qml`)
- Layer registry persistence via `obm_layer_registry.json`
- Jest JS test suite and QML UI tests with `qmltestrunner`
- ESLint + qmllint linting pipeline