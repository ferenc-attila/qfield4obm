// Utils.js - Shared utilities for QField4OBM
.pragma library

/**
 * Convert a GeoJSON geometry object to WKT string.
 * Pure JS implementation — no QGIS constructors needed.
 * @param {Object} geom - GeoJSON geometry object
 * @returns {string} WKT geometry string
 */
function geojsonGeomToWkt(geom) {
    if (!geom || !geom.type || !geom.coordinates) return "";
    var type = geom.type.toUpperCase();
    var coords = geom.coordinates;

    var coordPair = function(c) { return c[0] + " " + c[1]; };
    var ring = function(r) { return "(" + r.map(coordPair).join(", ") + ")"; };

    if (type === "POINT")           return "POINT(" + coordPair(coords) + ")";
    if (type === "MULTIPOINT")      return "MULTIPOINT(" + coords.map(function(c) { return "(" + coordPair(c) + ")"; }).join(", ") + ")";
    if (type === "LINESTRING")      return "LINESTRING(" + coords.map(coordPair).join(", ") + ")";
    if (type === "MULTILINESTRING") return "MULTILINESTRING(" + coords.map(ring).join(", ") + ")";
    if (type === "POLYGON")         return "POLYGON(" + coords.map(ring).join(", ") + ")";
    if (type === "MULTIPOLYGON")    return "MULTIPOLYGON(" + coords.map(function(poly) { return "(" + poly.map(ring).join(", ") + ")"; }).join(", ") + ")";
    return "";
}

/**
 * Name of the sidecar JSON file that stores the OBM layer registry
 * next to the project file. Deleted automatically when the project
 * folder is removed, so no stale entries survive.
 */
var LAYER_REGISTRY_FILENAME = "obm_layer_registry.json";

/**
 * Derive the sidecar registry file path from the project file path.
 * Returns "" if the project path is unknown.
 */
function _registryFilePath(qgisProject) {
    var projFile = "";
    try { projFile = qgisProject.fileName || ""; } catch(e) {}
    if (!projFile) return "";
    var lastSlash = projFile.lastIndexOf("/");
    if (lastSlash < 0) return "";
    return projFile.substring(0, lastSlash + 1) + LAYER_REGISTRY_FILENAME;
}

/**
 * Read the OBM layer registry from the sidecar JSON file.
 * Returns a parsed array (empty array if nothing stored yet).
 */
function readLayerRegistry(qgisProject, FileUtils) {
    if (!FileUtils || !qgisProject) return [];
    try {
        var path = _registryFilePath(qgisProject);
        if (!path) return [];
        var raw = FileUtils.readFileContent(path);
        if (!raw || raw.length === 0) return [];
        return JSON.parse(raw);
    } catch(e) {
        return [];
    }
}

/**
 * Write the OBM layer registry to the sidecar JSON file.
 */
function writeLayerRegistry(qgisProject, FileUtils, layers) {
    if (!FileUtils || !qgisProject) return;
    var path = _registryFilePath(qgisProject);
    if (!path) return;
    FileUtils.writeFileContent(path, JSON.stringify(layers));
}

/**
 * Persist OBM layer metadata inside the QGIS project file so the plugin
 * can re-add missing layers when the project is reloaded.
 *
 * Uses ExpressionContextUtils.setProjectVariable() which writes into
 * the .qgz/.qgs file — not the global QField.conf.
 */
function registerObmLayer(gpkgPath, layerName, geomType, styleConfig, qgisProject, FileUtils, iface) {
    try {
        if (!FileUtils || !qgisProject) {
            if (iface) iface.logMessage("QField4OBM: Cannot register layer — no project or FileUtils.", "QField4OBM", 1);
            return;
        }
        var layers = readLayerRegistry(qgisProject, FileUtils);

        // Update existing entry or add new one
        var found = false;
        for (var i = 0; i < layers.length; i++) {
            if (layers[i].layerName === layerName) {
                layers[i].gpkgPath = gpkgPath;
                layers[i].geomType = geomType;
                layers[i].style = styleConfig || {};
                found = true;
                break;
            }
        }
        if (!found) {
            layers.push({
                gpkgPath: gpkgPath,
                layerName: layerName,
                geomType: geomType,
                style: styleConfig || {}
            });
        }

        writeLayerRegistry(qgisProject, FileUtils, layers);
        if (iface) iface.logMessage("QField4OBM: Layer '" + layerName + "' registered in sidecar file for restore-on-load");
    } catch(eReg) {
        if (iface) iface.logMessage("QField4OBM: Failed to register layer in project: " + eReg.toString());
    }
}

/**
 * Convert a hex color string (#rrggbb) to QGIS XML color format "r,g,b,a".
 */
function hexToQgisColor(hex, alpha) {
    if (!hex || hex.length < 7) return "230,25,75,255";
    var r = parseInt(hex.substring(1, 3), 16);
    var g = parseInt(hex.substring(3, 5), 16);
    var b = parseInt(hex.substring(5, 7), 16);
    var a = (alpha !== undefined) ? alpha : 255;
    return r + "," + g + "," + b + "," + a;
}

/**
 * Build a QGIS .qml style XML string for a single-symbol renderer.
 * This XML is recognized by QGIS/QField when placed as a sidecar file
 * next to the data source (same base name, .qml extension).
 *
 * @param {Object} styleConfig - { color, sizeOrThickness, styleType }
 * @param {string} geomType - "Point" | "Line" | "Polygon" | "Attributes"
 * @returns {string} QGIS style XML
 */
function buildQgisStyleXml(styleConfig, geomType) {
    var color = styleConfig.color || "#e6194b";
    var size = styleConfig.sizeOrThickness || 3;
    var rgbaColor = hexToQgisColor(color);

    var symbolLayerXml = "";
    var symbolType = "";

    if (geomType === "Point") {
        symbolType = "marker";
        var pm = { "Circle": "circle", "Square": "square", "Triangle": "triangle" };
        var markerName = pm[styleConfig.styleType] || "circle";
        symbolLayerXml =
            '        <layer class="SimpleMarker" pass="0" locked="0" enabled="1">\n' +
            '          <Option type="Map">\n' +
            '            <Option type="QString" value="' + rgbaColor + '" name="color"/>\n' +
            '            <Option type="QString" value="' + markerName + '" name="name"/>\n' +
            '            <Option type="QString" value="' + size + '" name="size"/>\n' +
            '            <Option type="QString" value="MM" name="size_unit"/>\n' +
            '            <Option type="QString" value="' + hexToQgisColor(color, 255) + '" name="outline_color"/>\n' +
            '            <Option type="QString" value="0.4" name="outline_width"/>\n' +
            '          </Option>\n' +
            '        </layer>\n';
    } else if (geomType === "Line") {
        symbolType = "line";
        var lm = { "Solid": "solid", "Dashed": "dash", "Dotted": "dot" };
        var lineStyle = lm[styleConfig.styleType] || "solid";
        symbolLayerXml =
            '        <layer class="SimpleLine" pass="0" locked="0" enabled="1">\n' +
            '          <Option type="Map">\n' +
            '            <Option type="QString" value="' + rgbaColor + '" name="line_color"/>\n' +
            '            <Option type="QString" value="' + size + '" name="line_width"/>\n' +
            '            <Option type="QString" value="MM" name="line_width_unit"/>\n' +
            '            <Option type="QString" value="' + lineStyle + '" name="line_style"/>\n' +
            '          </Option>\n' +
            '        </layer>\n';
    } else {
        symbolType = "fill";
        var fm = { "Solid Fill": "solid", "No Fill": "no", "Diagonal Hatch": "b_diagonal" };
        var fillStyle = fm[styleConfig.styleType] || "solid";
        var fillAlpha = (fillStyle === "no") ? 0 : 128;
        symbolLayerXml =
            '        <layer class="SimpleFill" pass="0" locked="0" enabled="1">\n' +
            '          <Option type="Map">\n' +
            '            <Option type="QString" value="' + hexToQgisColor(color, fillAlpha) + '" name="color"/>\n' +
            '            <Option type="QString" value="' + fillStyle + '" name="style"/>\n' +
            '            <Option type="QString" value="' + rgbaColor + '" name="outline_color"/>\n' +
            '            <Option type="QString" value="0.5" name="outline_width"/>\n' +
            '            <Option type="QString" value="MM" name="outline_width_unit"/>\n' +
            '          </Option>\n' +
            '        </layer>\n';
    }

    var xml =
        '<!DOCTYPE qgis PUBLIC \'http://mrcc.com/qgis.dtd\' \'SYSTEM\'>\n' +
        '<qgis version="3.28" styleCategories="Symbology">\n' +
        '  <renderer-v2 type="singleSymbol" symbollevels="0">\n' +
        '    <symbols>\n' +
        '      <symbol type="' + symbolType + '" name="0" alpha="1" clip_to_extent="1">\n' +
        symbolLayerXml +
        '      </symbol>\n' +
        '    </symbols>\n' +
        '  </renderer-v2>\n' +
        '</qgis>\n';

    return xml;
}

/**
 * Write a QGIS .qml sidecar style file next to a data file.
 * When QGIS/QField loads a layer via loadDefaultStyle(), it looks for a
 * .qml file with the same base name as the data source and applies it.
 *
 * Requires the FileUtils C++ singleton to be available in the QML context.
 *
 * @param {string} dataFilePath - Path to the GPKG (or other data file)
 * @param {Object} styleConfig - { color, sizeOrThickness, styleType }
 * @param {string} geomType - "Point" | "Line" | "Polygon" | "Attributes"
 * @param {Object} FileUtils - QField's FileUtils singleton
 * @param {Object} [iface] - optional logger
 * @returns {boolean} true if the style file was written successfully
 */
function writeStyleFile(dataFilePath, styleConfig, geomType, FileUtils, iface) {
    if (!dataFilePath || !styleConfig) return false;
    var xml = buildQgisStyleXml(styleConfig, geomType);

    // Derive .qml path from data file path (replace extension with .qml)
    var dotIdx = dataFilePath.lastIndexOf(".");
    var qmlPath = (dotIdx > 0 ? dataFilePath.substring(0, dotIdx) : dataFilePath) + ".qml";

    try {
        var written = FileUtils.writeFileContent(qmlPath, xml);
        if (iface) iface.logMessage("QField4OBM: Style file written to " + qmlPath + " (ok=" + written + ")");
        return written;
    } catch (e) {
        if (iface) iface.logMessage("QField4OBM: Failed to write style file: " + e.toString());
        return false;
    }
}

/**
 * Re-add OBM layers that were registered in the sidecar file but are
 * missing from the current project. Called on project load (onFileNameChanged).
 */
function restoreObmLayers(qgisProject, FileUtils, settings, iface, applyQgsStyleCb, LayerUtils, ProjectUtils) {
    try {
        // Migrate: move layer registry from QSettings into sidecar file
        _migrateLayerRegistryFromQSettings(qgisProject, FileUtils, settings, iface);

        if (!FileUtils || !qgisProject) return;
        var layers = readLayerRegistry(qgisProject, FileUtils);
        if (!layers || layers.length === 0) return;

        for (var i = 0; i < layers.length; i++) {
            var entry = layers[i];

            // Check if the layer is already in the project
            var alreadyLoaded = false;
            try {
                var byName = qgisProject.mapLayersByName(entry.layerName);
                if (byName && byName.length > 0) alreadyLoaded = true;
            } catch(eCheck) {}

            if (alreadyLoaded) continue;

            // Re-load the GPKG and add to the project
            try {
                var restoredLayer = LayerUtils.loadVectorLayer(entry.gpkgPath, entry.layerName, "ogr");
                if (restoredLayer) {
                    var added = ProjectUtils.addMapLayer(qgisProject, restoredLayer);
                    if (added) {
                        if (typeof applyQgsStyleCb === "function") {
                            applyQgsStyleCb(restoredLayer, entry.style, entry.geomType);
                        }
                        try { qgisProject.setDirty(true); } catch(eDrt) {}
                        if (iface) iface.logMessage("QField4OBM: Restored layer '" + entry.layerName + "' from " + entry.gpkgPath);
                    } else {
                        if (iface) iface.logMessage("QField4OBM: Failed to re-add restored layer '" + entry.layerName + "'");
                    }
                } else {
                    if (iface) iface.logMessage("QField4OBM: Could not load GPKG for restore: " + entry.gpkgPath);
                }
            } catch(eRestore) {
                if (iface) iface.logMessage("QField4OBM: Layer restore failed for '" + entry.layerName + "': " + eRestore.toString());
            }
        }
    } catch(eRestoreAll) {
        if (iface) iface.logMessage("QField4OBM: restoreObmLayers error: " + eRestoreAll.toString());
    }
}

/**
 * One-time migration: move layer registry from QSettings into the project
 * variable. After migration, the QSettings keys are cleared.
 */
function _migrateLayerRegistryFromQSettings(qgisProject, FileUtils, settings, iface) {
    if (!settings || !FileUtils || !qgisProject) return;
    try {
        // Clear the old global (non-project-scoped) key
        try {
            var oldGlobal = settings.value("QField4OBM/layers", "");
            if (oldGlobal && oldGlobal !== "[]") {
                settings.setValue("QField4OBM/layers", "[]");
                if (iface) iface.logMessage("QField4OBM: Cleared stale global layer registry from QSettings.", "QField4OBM", 0);
            }
        } catch(e1) {}

        // Migrate project-scoped QSettings key
        var projFile = "";
        try { projFile = qgisProject.fileName || ""; } catch(e2) {}
        if (!projFile) return;

        var qsKey = "QField4OBM/layers/" + projFile;
        var raw = "";
        try { raw = settings.value(qsKey, ""); } catch(e3) {}
        if (!raw || raw === "[]") return;

        var qsLayers = JSON.parse(raw);
        if (!qsLayers || qsLayers.length === 0) return;

        // Merge with any layers already in the sidecar file
        var existing = readLayerRegistry(qgisProject, FileUtils);
        var existingNames = {};
        for (var i = 0; i < existing.length; i++) {
            existingNames[existing[i].layerName] = true;
        }
        for (var j = 0; j < qsLayers.length; j++) {
            if (!existingNames[qsLayers[j].layerName]) {
                existing.push(qsLayers[j]);
            }
        }
        writeLayerRegistry(qgisProject, FileUtils, existing);

        // Clear the QSettings key
        settings.setValue(qsKey, "[]");
        if (iface) iface.logMessage("QField4OBM: Migrated " + qsLayers.length + " layer(s) from QSettings to sidecar file.", "QField4OBM", 0);
    } catch(eMigrate) {
        if (iface) iface.logMessage("QField4OBM: Layer registry migration error: " + eMigrate.toString());
    }
}
