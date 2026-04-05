# QField4OBM Plugin

QField4OBM is a dedicated plugin for the [QField](https://qfield.org/) mobile mapping application that provides seamless synchronization capabilities with [OpenBioMaps](https://openbiomaps.org/) (OBM) biodiversity data servers.

The plugin enables field researchers to download project layers, query specific records via GraphQL filters, work entirely offline on a mobile device, and later synchronize delta-changes back to the OBM server using Bearer token authentication.

## Install in QField

Minimum QField version is 4.1.3. The plugin is still EXPERIMENTAL.

Open the Settings dialog in QField, push the 3 dot button next to "Manage plugins". Push the "Install plugin from URL" button and enter the following link:
`https://github.com/ferenc-attila/qfield4obm/releases/download/{latest-version}/QField4OBM-{latest-version}.zip`
Change {latest-version} to the latest version of the plugin, for example v0.1.0.

You can find the latest version in the [releases](https://github.com/ferenc-attila/qfield4obm/releases) page.

## Architecture & Technology Stack

Because QField operates on mobile platforms (Android/iOS) and Windows/Linux natively via Qt, it **does not support Python (PyQGIS)**. Consequently, this plugin is developed strictly using **QML (Qt Modeling Language)** and **JavaScript (Qt V4 JS engine)**.

* **UI Layer**: Pure QML utilizing QtQuick Controls 2 and QField's internal `Theme` singleton.
* **Logic Layer**: Standalone JS scripts for handling Network, Authentication, and the central Sync Engine.
* **Storage**: Local GeoPackage (`.gpkg`) file generation and caching via the QGIS C++ API bindings exposed to QML.
* **State Management**: QSettings for application-wide configurations (tokens) and `QgsProject` custom variables for project-specific syncing properties.
* **QFIeld project file handling**: The plugin cannot read the project file. We store the GIS layer properties in the `obm_layer_registry.json` file. This file is not part of the plugin, but it is stored in the project folder. Only works if the user uses the plugin. It won't work in QGIS.

## Local Development Environment

### Prerequisites
You need the following tools installed to run and test the standalone code:
- Node.js & NPM (for JS testing and linting)
- Qt 5 Declarative tools (`qmlscene`, `qmltestrunner`, `qmllint`)
- QML QtTest Module

On Debian/Ubuntu/Mint:
```bash
sudo apt-get install qtdeclarative5-dev qtdeclarative5-dev-tools qml-module-qttest
```

### Installation
Run npm install to pull down the testing tools:
```bash
npm install
```

## Testing & Linting

We maintain a strict testing pipeline for both UI components and core JavaScript logic to prevent regressions effectively on mobile constraints.

* **JavaScript Tests**: We use Jest for behavioral testing of headless JS modules.
  ```bash
  npm run test:js
  ```
* **QML UI Tests**: We use QtTest for simulating GUI interactions and verifying states.
  ```bash
  npm run test:qml
  ```
* **Run Everything**:
  ```bash
  npm run test:all
  ```
* **Linting**:
  Enforces ESLint rules for JS and `qmllint` syntax for QML.
  ```bash
  npm run lint
  ```

## Deployment

To deploy the plugin locally into QField:
1. Run `./package_plugin.sh` which bundles the plugin into a `.zip` archive.
2. Unzip the contents into your QField plugins directory.
3. Restart QField (or use the Plugin Reloader tool if active) to see the changes.

## License

GNU GPL 3.0
