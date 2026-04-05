import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.LocalStorage 2.12
import org.qfield 1.0
import Theme 1.0

import "scripts/AuthManager.js" as AuthManager
import "scripts/ApiClient.js" as ApiClient
import "scripts/SyncEngine.js" as SyncEngine

import "components" as Components
import "scripts/Utils.js" as Utils

Item {
    id: root
    width: 0
    height: 0

    // The plugin properties
    property string pluginName: "QField4OBM"

    QtObject {
        id: pluginSettings
        property string obmAccessToken: ""
        property string obmRefreshToken: ""
        property string obmBaseUrl: ""
        property string projectTable: ""
        property string projectName: ""
        // Reactive property for QML bindings
        property bool isLoggedIn: false
    }

    // Holds references to dynamically-created VectorLayer QML objects.
    // Required to prevent the JS garbage collector from destroying them
    // after Qt.createQmlObject() returns.
    property var scratchLayers: []

    QfToolButtonDrawer {
        id: pluginDrawer
        visible: true
        bgcolor: Theme.darkGray
        round: true
        iconSource: Qt.resolvedUrl("obm_icon.png")
        iconColor: "transparent"

        QfToolButton {
            id: loginButton
            // Set the background to transparent so it matches the drawer panel
            bgcolor: pluginSettings.isLoggedIn ? (typeof Theme !== "undefined" && typeof Theme.toolButtonBackgroundColor !== "undefined" ? Theme.mainColor : "#80cc28") : (typeof Theme !== "undefined" && typeof Theme.darkRed !== "undefined" ? Theme.darkRed : "#c0392b")

            icon.source: Qt.resolvedUrl("login.svg")
            // Apply the logged in / logged out colors directly to the SVG icon!
            icon.color:  typeof Theme !== "undefined" && typeof Theme.buttonTextColor !== "undefined" ? Theme.buttonTextColor : "#ffffff"
            icon.width: 40
            icon.height: 40

            width: 44
            height: 44
            padding: 0
            round: true

            onClicked: {
                if (pluginSettings.isLoggedIn) {
                    // When logged in, open My Projects directly
                    // (Dashboard is accessible via the layers button)
                    ApiClient.getUserProjects(function(success, response) {
                        projectsPopup.open();
                        if (success) {
                            var projectsArray = Array.isArray(response) ? response : (response.data || []);
                            var mappedProjects = [];
                            for (var i = 0; i < projectsArray.length; i++) {
                                var item = projectsArray[i];
                                if (!item.name && item.languages) {
                                    var langs = Object.keys(item.languages);
                                    if (langs.length > 0) {
                                        var uiLang = (typeof Qt !== "undefined" && Qt.uiLanguage) ? String(Qt.uiLanguage).split("_")[0] : null;
                                        var selectedLang = null;
                                        if (uiLang && item.languages[uiLang]) {
                                            selectedLang = uiLang;
                                        } else if (item.languages["hu"]) {
                                            selectedLang = "hu";
                                        } else {
                                            selectedLang = langs[0];
                                        }
                                        if (selectedLang && item.languages[selectedLang].name) {
                                            item.name = item.languages[selectedLang].name;
                                        }
                                    }
                                }
                                if (!item.name) {
                                    item.name = item.project_table || "Unknown";
                                }
                                mappedProjects.push(item);
                            }
                            projectsPopup.userProjectsList = mappedProjects;
                            projectsPopup.errorMessage = "";
                        } else {
                            projectsPopup.errorMessage = "Error loading projects: " + response;
                            projectsPopup.userProjectsList = [];
                        }
                    });
                } else {
                    loginPopup.open();
                }
            }
        }

        QfToolButton {
            id: dashboardButton
            bgcolor: enabled ? (typeof Theme !== "undefined" && typeof Theme.toolButtonBackgroundColor !== "undefined"
                                    ? Theme.toolButtonBackgroundColor
                                    : "#ffffff")
                                : (typeof Theme !== "undefined" && typeof Theme.toolButtonBackgroundSemiOpaqueColor !== "undefined"
                                    ? Theme.toolButtonBackgroundSemiOpaqueColor
                                    : "#4d212121")
            icon.source: Qt.resolvedUrl("layers.svg")
            icon.color: enabled ? (typeof Theme !== "undefined" && typeof Theme.toolButtonColor !== "undefined"
                                    ? Theme.toolButtonColor
                                    : "#ffffff")
                                : (typeof Theme !== "undefined" && typeof Theme.mainTextDisabledColor !== "undefined"
                                    ? Theme.mainTextDisabledColor
                                    : "#73000000")
            icon.width: 40
            icon.height: 40

            width: 44
            height: 44
            padding: 0
            round: true

            // The UX preference: always visible, but disabled and faded when not logged in
            enabled: pluginSettings.isLoggedIn
            opacity: pluginSettings.isLoggedIn ? 1.0 : 0.5

            onClicked: {
                // Since the loginPopup and dashboardPopup are managed by openMainDialog based on login status,
                // and this button is only enabled when logged in:
                dashboardPopup.open();
            }
        }
    }

    // Hidden QField CoordinateTransformer instance bridging map CRS to API GeoJSON CRS
    CoordinateTransformer {
        id: globalApiTransformer
        // Use active QGIS Project context if available to intercept datum shifts precisely
        transformContext: typeof qgisProject !== 'undefined' ? qgisProject.transformContext : CoordinateReferenceSystemUtils.emptyTransformContext()
    }

    function _executeBboxProxy(ifc, xmin, ymin, xmax, ymax, srcSridAuth, trgSridNum) {
        if (ifc) ifc.logMessage("QField4OBM Debug Proxy executing! Tracing properties...");

        try {
            // Property discovery routine for QML C++ exposed objects
            var getProps = function(obj) {
                var props = [];
                for (var key in obj) {
                    props.push(key);
                }
                return props.join(", ");
            };

            if (ifc) {
                ifc.logMessage("QField4OBM Debug globalApiTransformer properties: " + getProps(globalApiTransformer));
                if (typeof CoordinateReferenceSystemUtils !== 'undefined') {
                    ifc.logMessage("QField4OBM Debug CoordinateReferenceSystemUtils properties: " + getProps(CoordinateReferenceSystemUtils));
                }
                if (typeof GeometryUtils !== 'undefined') {
                    ifc.logMessage("QField4OBM Debug GeometryUtils properties: " + getProps(GeometryUtils));
                }
            }

            // Fallback for EPSG:3857 to EPSG:4326 ONLY natively without C++ QGIS libraries!
            if ((srcSridAuth === "EPSG:3857" || srcSridAuth === "3857") && (trgSridNum === 4326 || trgSridNum === "4326")) {
                if (ifc) ifc.logMessage("QField4OBM Debug Applying mathematical Web Mercator to WGS84 fallback!");

                var earthRadius = 6378137.0;

                var mercatorToLonLat = function(x, y) {
                    var lon = (x / earthRadius) * (180 / Math.PI);
                    var lat = (y / earthRadius) * (180 / Math.PI);
                    lat = 180 / Math.PI * (2 * Math.atan(Math.exp(lat * Math.PI / 180)) - Math.PI / 2);
                    return { lon: lon, lat: lat };
                };

                var minCoord = mercatorToLonLat(xmin, ymin);
                var maxCoord = mercatorToLonLat(xmax, ymax);

                if (minCoord.lon && minCoord.lat && maxCoord.lon && maxCoord.lat) {
                    return {
                        xmin: minCoord.lon,
                        ymin: minCoord.lat,
                        xmax: maxCoord.lon,
                        ymax: maxCoord.lat
                    };
                }
            }
        } catch (e) {
            if (ifc) ifc.logMessage("QField4OBM Debug Proxy exception: " + e.toString());
        }
        return null;
    }

    /**
     * GPKG Proxy — executes all QGIS C++ API calls on behalf of SyncEngine.js.
     * This function MUST live in main.qml (a QML component scope) because QGIS
     * C++ classes like QgsVectorLayer, QgsVectorFileWriter, QgsFields, etc. are
     * only constructable from QML component scope, NOT from .pragma library JS.
     *
     * Supported actions:
     *   getMaxOmbId  — returns { maxOmbId: <int> } from an existing GPKG layer
     *   saveFeatures — writes / appends a GeoJSON FeatureCollection to a GPKG,
     *                  loads the result into the project, applies styling;
     *                  returns { success: <bool>, message: <string> }
     *
     * @param {Object} params - action descriptor (see SyncEngine._gpkgProxy calls)
     * @returns {Object|null}
     */
    function _executeGpkgProxy(params) {
        if (!params || !params.action) return null;

        try {
            // ---------------------------------------------------------------
            // ACTION: getMaxOmbId
            // Returns the maximum obm_id stored in an existing GPKG layer so
            // that delta-sync can request only newer records from the API.
            // ---------------------------------------------------------------
            if (params.action === "getMaxOmbId") {
                // Primary: scan the already-loaded project layer.
                // Fallback: read from QSettings (persisted after each sync).
                var projectLayers = null;
                try {
                    if (typeof qgisProject !== "undefined") {
                        if (typeof qgisProject.mapLayersByName === "function") {
                            projectLayers = qgisProject.mapLayersByName(params.layerName);
                        } else if (typeof qgisProject.mapLayers === "function") {
                            var allL = qgisProject.mapLayers();
                            var lkeys = Object.keys(allL);
                            projectLayers = [];
                            for (var ki = 0; ki < lkeys.length; ki++) {
                                var l = allL[lkeys[ki]];
                                var lname = (typeof l.name === "function") ? l.name() : l.name;
                                if (lname === params.layerName) projectLayers.push(l);
                            }
                        }
                    }
                } catch(ep) {
                    if (iface) iface.logMessage("QField4OBM Proxy: mapLayers scan error: " + ep);
                }

                var targetLayer = (projectLayers && projectLayers.length > 0)
                    ? projectLayers[0] : null;

                var maxId = 0;

                if (targetLayer) {
                    try {
                        var it = targetLayer.getFeatures();
                        var feat = null;
                        while ((feat = it.next()) && feat && !feat.isNull()) {
                            var val = feat.attribute("obm_id");
                            if (val !== null && val !== undefined) {
                                var num = parseInt(val, 10);
                                if (!isNaN(num) && num > maxId) maxId = num;
                            }
                        }
                    } catch (e3) {
                        if (iface) iface.logMessage("QField4OBM Proxy: Feature iteration failed: " + e3);
                    }
                }

                // Try from project custom properties next
                if (maxId === 0) {
                    try {
                        if (typeof qgisProject !== "undefined") {
                            var stored = qgisProject.customProperty("QField4OBM/maxOmbId_" + params.layerName, 0);
                            var storedNum = parseInt(stored, 10);
                            if (!isNaN(storedNum) && storedNum > 0) maxId = storedNum;
                        }
                    } catch(es) {}
                }

                // Fallback: Direct file scan if layer is not in project but GPKG exists
                if (maxId === 0 && params.gpkgPath) {
                    try {
                        if (typeof LayerUtils !== "undefined") {
                            var offlineLayer = null;
                            try { offlineLayer = LayerUtils.loadVectorLayer(params.gpkgPath, params.layerName, "ogr"); } catch(eol) {}

                            if (offlineLayer) {
                                if (iface) iface.logMessage("QField4OBM Proxy: Scanning offline GPKG layer for max(obm_id)");
                                try {
                                    var itOffline = offlineLayer.getFeatures();
                                    var featOffline = null;
                                    while ((featOffline = itOffline.next()) && featOffline && !featOffline.isNull()) {
                                        var valOff = featOffline.attribute("obm_id");
                                        if (valOff !== null && valOff !== undefined) {
                                            var numOff = parseInt(valOff, 10);
                                            if (!isNaN(numOff) && numOff > maxId) maxId = numOff;
                                        }
                                    }
                                } catch(eo3) {
                                    if (iface) iface.logMessage("QField4OBM Proxy: Offline layer iteration failed: " + eo3);
                                }
                            }
                        }
                    } catch(eo2) {}
                }

                if (iface) iface.logMessage("QField4OBM Proxy: max obm_id for '" + params.layerName + "' = " + maxId);
                return { maxOmbId: maxId };
            }

            // ---------------------------------------------------------------
            // ACTION: saveFeatures
            // Writes downloaded features to local storage as a physical GeoPackage.
            //
            // Strategy:
            //   1. If a matching layer already exists in the project ->
            //      append via startEditing / addFeature / commitChanges
            //      (the layer is already backed by a physical GPKG file).
            //   2. If no layer exists yet (CREATE) ->
            //      build a temporary in-memory VectorLayer, populate it,
            //      export to GPKG via LayerUtils.saveVectorLayerAs(),
            //      then load the physical GPKG into the project via
            //      iface.addVectorLayer() and apply styling.
            // ---------------------------------------------------------------
            if (params.action === "saveFeatures") {
                var fc = JSON.parse(params.featureCollectionJson);
                var features = fc.features || [];
                var layerName = params.layerName;
                var gpkgPath = params.gpkgPath;
                var geomType = params.geomType;
                var style = params.styleConfig || {};

                if (features.length === 0) {
                    return { success: true, message: "No features to save" };
                }

                // --- Look for an existing layer in the current project ---
                var existingLayer = null;
                try {
                    if (typeof qgisProject !== "undefined") {
                        var byName = null;
                        if (typeof qgisProject.mapLayersByName === "function") {
                            byName = qgisProject.mapLayersByName(layerName);
                        }
                        if (byName && byName.length > 0) {
                            existingLayer = byName[0];
                        } else {
                            var allLayers2 = (typeof qgisProject.mapLayers === "function")
                                ? qgisProject.mapLayers()
                                : qgisProject.mapLayers;
                            if (allLayers2) {
                                var lkeys2 = Object.keys(allLayers2);
                                for (var li = 0; li < lkeys2.length; li++) {
                                    var lyr = allLayers2[lkeys2[li]];
                                    if (!lyr) continue;
                                    var lsrc = (typeof lyr.source === "function") ? lyr.source() : lyr.source;
                                    if (lsrc && lsrc.indexOf(layerName) !== -1) {
                                        existingLayer = lyr;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                } catch(el) {
                    if (iface) iface.logMessage("QField4OBM Proxy: Layer scan failed: " + el);
                }

                var savedOk = false;
                var saveMsg = "";

if (existingLayer) {
                    // --------------------------------------------------------
                    // APPEND to existing layer via native editing API.
                    // --------------------------------------------------------
                    if (iface) iface.logMessage("QField4OBM Proxy: Appending " + features.length + " features to '" + layerName + "'.");
                    try {
                        var startOk = existingLayer.startEditing();
                        if (!startOk) {
                            saveMsg = "startEditing() returned false — layer may not be editable";
                            if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                        } else {
                            // --- Collect existing obm_ids for deduplication ---
                            var existingOmbIds = {};
                            try {
                                var existIt = LayerUtils.createFeatureIterator(existingLayer);
                                while (existIt.hasNext()) {
                                    var existFeat = existIt.next();
                                    if (existFeat) {
                                        var existOid = null;
                                        try { existOid = existFeat.attribute("obm_id"); } catch(eAttr) {}
                                        if (existOid !== null && existOid !== undefined) {
                                            existingOmbIds[String(existOid)] = true;
                                        }
                                    }
                                }
                                existIt.close();
                            } catch (eDup) {
                                if (iface) iface.logMessage("QField4OBM Proxy: obm_id dedup scan failed: " + eDup);
                            }
                            var skippedDupes = 0;

                            var addedCount = 0;

                            // Inject "fid" property into every GeoJSON feature so
                            // the temp memory layer has the same field count (34)
                            // as the GPKG layer (which includes an auto-generated
                            // fid column).  Without this, addFeature rejects the
                            // feature due to field-count mismatch (33 vs 34).
                            // We place fid first so the field order matches the
                            // GPKG schema (fid is always column 0).
                            var featuresWithFid = [];
                            for (var fi = 0; fi < features.length; fi++) {
                                var fCopy = JSON.parse(JSON.stringify(features[fi]));
                                var oldProps = fCopy.properties || {};
                                if (!oldProps.hasOwnProperty("fid")) {
                                    var newProps = { "fid": null };
                                    var pkeys = Object.keys(oldProps);
                                    for (var pk = 0; pk < pkeys.length; pk++) {
                                        newProps[pkeys[pk]] = oldProps[pkeys[pk]];
                                    }
                                    fCopy.properties = newProps;
                                }
                                featuresWithFid.push(fCopy);
                            }

                            var geojsonFc = { type: "FeatureCollection", features: featuresWithFid };
                            var geojsonString = JSON.stringify(geojsonFc);

                            var wgs84Crs = null;
                            try { wgs84Crs = CoordinateReferenceSystemUtils.wgs84Crs(); }
                            catch (eCrs1) {
                                try { wgs84Crs = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"); } catch (eCrs2) {}
                            }

                            var tempLayer = LayerUtils.memoryLayerFromJsonString("temp_append", geojsonString, wgs84Crs);

                            if (tempLayer) {
                                var it = LayerUtils.createFeatureIterator(tempLayer);
                                while (it.hasNext()) {
                                    var feat = it.next();
                                    if (feat) {
                                        // Skip if obm_id already exists in the layer
                                        var newOid = null;
                                        try { newOid = feat.attribute("obm_id"); } catch(eOid) {}
                                        if (newOid !== null && newOid !== undefined && existingOmbIds[String(newOid)]) {
                                            skippedDupes++;
                                            continue;
                                        }

                                        // Add the source feature directly — field count
                                        // now matches because we injected fid above.
                                        var added = LayerUtils.addFeature(existingLayer, feat);
                                        if (added) addedCount++;
                                    }
                                }
                                it.close();
                            }

                            // 5. Adatbázis tranzakció mentése és ellenőrzése
                            var commitOk = existingLayer.commitChanges();

                            if (!commitOk) {
                                var errStr = typeof existingLayer.commitErrors === "function" ? existingLayer.commitErrors().join(" | ") : "Database constraint or schema mismatch";
                                saveMsg = "Append failed to save to disk: " + errStr;
                                if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                            } else {
                                // 6. Térképkiterjedés újraszámítása, hogy az új elemek láthatóak legyenek
                                try { existingLayer.updateExtents(); } catch(eExt) {}
                                try { existingLayer.triggerRepaint(); } catch(eRep) {}

                                savedOk = true;
                                saveMsg = "Appended " + addedCount + " / " + features.length + " features (skipped " + skippedDupes + " duplicates).";
                                if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);

                                // Mark project dirty so QField's own save-on-exit persists the layer
                                try { qgisProject.setDirty(true); } catch(eDirtyA) {}
                            }
                        }
                    } catch(ea) {
                        saveMsg = "Append exception: " + ea.toString();
                        if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                        try { existingLayer.rollBack(); } catch(r) {}
                    }

                    _applyQgsStyle(existingLayer, style, geomType);

                } else {
                    // --------------------------------------------------------
                    // CREATE: Use LayerUtils C++ API (layerutils.cpp) to:
                    //   1. Create a populated memory layer from GeoJSON via
                    //      LayerUtils.memoryLayerFromJsonString(name, json, crs)
                    //   2. Export it to a physical GPKG file via
                    //      LayerUtils.saveVectorLayerAs(layer, filePath)
                    //   3. Load the GPKG into the project via
                    //      LayerUtils.loadVectorLayer(uri, name, provider)
                    //      + qgisProject.addMapLayer()
                    //
                    // IMPORTANT: We call C++ methods directly — NO typeof
                    // checks. Qt/QML exposes Q_INVOKABLE methods with typeof
                    // "object" (not "function"), so typeof guards silently
                    // skip real C++ API calls. Instead, try/catch captures
                    // any TypeError if a method genuinely doesn't exist.
                    // --------------------------------------------------------

                    if (iface) iface.logMessage("QField4OBM Proxy: CREATE — using LayerUtils API pipeline");

                    // Build the GeoJSON FeatureCollection string that the
                    // API already downloaded. This is passed directly to the
                    // C++ LayerUtils.memoryLayerFromJsonString() method which
                    // parses it via QgsJsonUtils internally.
                    var geojsonFc = {
                        type: "FeatureCollection",
                        features: features
                    };
                    var geojsonString = JSON.stringify(geojsonFc);

                    // ------------------------------------------------
                    // STEP 1: Create a populated memory layer from the
                    // GeoJSON string. LayerUtils.memoryLayerFromJsonString
                    // (layerutils.cpp:573) parses the JSON, infers fields,
                    // creates a QgsMemoryProvider layer, and populates it
                    // with features — all in C++.
                    //
                    // We also need a CRS object for EPSG:4326 (the API
                    // returns coordinates in WGS84).
                    // ------------------------------------------------
                    var newLayer = null;
                    try {
                        // Get the WGS84 CRS object via the CoordinateReferenceSystemUtils singleton.
                        // Call directly — if the singleton is absent, the catch block catches it.
                        var wgs84Crs = null;
                        try {
                            wgs84Crs = CoordinateReferenceSystemUtils.wgs84Crs();
                        } catch (eCrsMain) {
                            if (iface) iface.logMessage("QField4OBM Proxy: wgs84Crs() unavailable, trying fromDescription: " + eCrsMain);
                            try {
                                wgs84Crs = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326");
                            } catch (eCrsFallback) {
                                if (iface) iface.logMessage("QField4OBM Proxy: fromDescription() also unavailable: " + eCrsFallback);
                            }
                        }

                        // Call memoryLayerFromJsonString directly — no typeof guard.
                        // If LayerUtils is not defined or the method is missing,
                        // the engine throws a TypeError caught below.
                        newLayer = LayerUtils.memoryLayerFromJsonString(layerName, geojsonString, wgs84Crs);
                        if (newLayer) {
                            if (iface) iface.logMessage("QField4OBM Proxy: Memory layer created via LayerUtils.memoryLayerFromJsonString with " + features.length + " features");
                        } else {
                            saveMsg = "LayerUtils.memoryLayerFromJsonString returned null — GeoJSON may be invalid or CRS missing";
                            if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                        }
                    } catch(eCreate) {
                        saveMsg = "memoryLayerFromJsonString failed: " + eCreate.toString();
                        if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                    }

                    if (newLayer) {
                        // ------------------------------------------------
                        // STEP 2: Export the memory layer to a physical GPKG.
                        // LayerUtils.saveVectorLayerAs (layerutils.cpp:615)
                        // wraps QgsVectorFileWriter. It takes:
                        //   (layer, filePath, driverName?, filterExpression?)
                        // Returns the final file name string (empty on error).
                        //
                        // Called directly — no typeof guard.
                        // ------------------------------------------------
                        var gpkgWritten = "";
                        try {
                            gpkgWritten = LayerUtils.saveVectorLayerAs(newLayer, gpkgPath);
                            if (gpkgWritten && gpkgWritten.length > 0) {
                                if (iface) iface.logMessage("QField4OBM Proxy: Exported to GPKG: " + gpkgWritten);
                            } else {
                                saveMsg = "saveVectorLayerAs returned empty — GPKG write failed (check disk permissions or path: " + gpkgPath + ")";
                                if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                            }
                        } catch(eExport) {
                            saveMsg = "GPKG export failed: " + eExport.toString();
                            if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                        }

// ------------------------------------------------
                        // STEP 3: Load the physical GPKG into the project.
                        // LayerUtils.loadVectorLayer (layerutils.cpp:559)
                        // creates a QgsVectorLayer with CppOwnership and
                        // returns it. We then add it to the project via
                        // ProjectUtils.addMapLayer() which handles the QML/C++ bridge.
                        // ------------------------------------------------
                        var loadedPhysicalLayer = null;
                        var physicalGpkgPath = (gpkgWritten && gpkgWritten.length > 0) ? gpkgWritten : gpkgPath;

                        // Only proceed to load if GPKG export succeeded
                        if (gpkgWritten && gpkgWritten.length > 0) {
                            // Write sidecar .qml style file BEFORE loading the
                            // layer so loadDefaultStyle picks it up automatically.
                            try {
                                var fileUtilsObj = null;
                                try { fileUtilsObj = FileUtils; } catch(eFu) {}
                                if (fileUtilsObj) {
                                    Utils.writeStyleFile(physicalGpkgPath, style, geomType, fileUtilsObj, iface);
                                }
                            } catch(eStyle) {
                                if (iface) iface.logMessage("QField4OBM Proxy: Style file pre-write failed: " + eStyle);
                            }

                            try {
                                loadedPhysicalLayer = LayerUtils.loadVectorLayer(physicalGpkgPath, layerName, "ogr");
                                if (loadedPhysicalLayer) {
                                    if (iface) iface.logMessage("QField4OBM Proxy: Physical GPKG layer loaded via LayerUtils.loadVectorLayer");
                                } else {
                                    saveMsg = "LayerUtils.loadVectorLayer returned null — GPKG file may be corrupt at " + physicalGpkgPath;
                                    if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                                }
                            } catch(eLoad) {
                                saveMsg = "Failed to load physical GPKG: " + eLoad.toString();
                                if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                            }

                            // Add the loaded layer to the QGIS project.
                            // Use ProjectUtils singleton which correctly wraps QgsProject::addMapLayer for QML
                            if (loadedPhysicalLayer) {
                                try {
                                    var added = ProjectUtils.addMapLayer(qgisProject, loadedPhysicalLayer);
                                    if (added) {
                                        savedOk = true;
                                        saveMsg = "GPKG layer created with " + features.length + " features at " + physicalGpkgPath;
                                        if (iface) iface.logMessage("QField4OBM Proxy: Physical GPKG layer added to project");

                                        // Mark project dirty so QField's own save-on-exit persists the layer
                                        try { qgisProject.setDirty(true); } catch(eDirty) {}

                                        // Persist layer info in sidecar file so the plugin can re-add
                                        // the layer on next project load.
                                        var _fileUtils = null; try { _fileUtils = FileUtils; } catch(e) {}
                                        Utils.registerObmLayer(physicalGpkgPath, layerName, geomType, style, typeof qgisProject !== "undefined" ? qgisProject : null, _fileUtils, typeof iface !== "undefined" ? iface : null);
                                    } else {
                                         saveMsg = "ProjectUtils.addMapLayer returned false — failed to add layer to tree.";
                                         if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                                    }
                                } catch(eAdd) {
                                    saveMsg = "ProjectUtils.addMapLayer failed: " + eAdd.toString();
                                    if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                                }
                            }
                        } else {
                            // GPKG export step returned empty — do not attempt load
                            if (!saveMsg) saveMsg = "Skipped GPKG load — export produced no output file";
                            if (iface) iface.logMessage("QField4OBM Proxy: " + saveMsg);
                        }

                        // STEP 4: If the layer was loaded but the sidecar
                        // style was not picked up automatically, apply it now.
                        if (loadedPhysicalLayer) {
                            _applyQgsStyle(loadedPhysicalLayer, style, geomType);
                        }

                        newLayer = null;

                    } else {
                        if (!saveMsg) saveMsg = "Failed to create memory layer via LayerUtils";
                    }
                }


                if (iface) iface.logMessage("QField4OBM Proxy: saveFeatures done. success=" + savedOk + (saveMsg ? " msg=" + saveMsg : ""));
                return { success: savedOk, message: saveMsg };
            }

        } catch (e) {
            if (iface) iface.logMessage("QField4OBM Proxy: Unhandled exception in action '" + params.action + "': " + e.toString());
            return { success: false, message: e.toString() };
        }

        return null;
    }

    // Utils removed and outsourced to scripts/Utils.js

    /**
     * Apply styling to a layer by writing a .qml sidecar style file and
     * reloading the layer's default style. This avoids using QGIS C++
     * symbol classes (QgsMarkerSymbol, etc.) which are not available in
     * the QField QML/JS context.
     *
     * @param {Object} layer - a loaded QgsVectorLayer
     * @param {Object} styleConfig - { color, sizeOrThickness, styleType }
     * @param {string} geomType - "Point" | "Line" | "Polygon" | "Attributes"
     */
    function _applyQgsStyle(layer, styleConfig, geomType) {
        if (!layer || !styleConfig) return;

        // Get the layer's data source path
        var sourcePath = "";
        try {
            sourcePath = (typeof layer.source === "function") ? layer.source() : layer.source;
        } catch (e) {}

        if (!sourcePath) {
            if (iface) iface.logMessage("QField4OBM: Cannot apply style — layer source path unknown");
            return;
        }

        // Strip query parameters (e.g. "|layername=..." from GPKG URIs)
        var pipeIdx = sourcePath.indexOf("|");
        if (pipeIdx > 0) sourcePath = sourcePath.substring(0, pipeIdx);

        var ifaceObj = typeof iface !== "undefined" ? iface : null;
        var fileUtilsObj = null;
        try { fileUtilsObj = FileUtils; } catch(e) {}
        if (!fileUtilsObj) {
            if (ifaceObj) ifaceObj.logMessage("QField4OBM: Cannot apply style — FileUtils not available");
            return;
        }

        var written = Utils.writeStyleFile(sourcePath, styleConfig, geomType, fileUtilsObj, ifaceObj);
        if (!written) return;

        try {
            layer.loadDefaultStyle();
            layer.triggerRepaint();
            if (ifaceObj) ifaceObj.logMessage("QField4OBM: Style applied via sidecar .qml — " + (styleConfig.color || "") + " / " + (styleConfig.styleType || "default") + " / size " + (styleConfig.sizeOrThickness || 3));
        } catch (es) {
            if (ifaceObj) ifaceObj.logMessage("QField4OBM: loadDefaultStyle unavailable, style file written but not loaded: " + es.toString());
        }
    }

    Component.onCompleted: {
        var ifaceObj = typeof iface !== "undefined" ? iface : null;
        var qProjObj = typeof qgisProject !== "undefined" ? qgisProject : null;
        // Use QField's root context 'settings' (QSettings wrapper) for persistence.
        // Note: 'projectInfo' is NOT accessible from plugins (it's a local QML id
        // inside qgismobileapp.qml). The 'settings' object IS a root context property.
        var qfSettingsObj = typeof settings !== "undefined" ? settings : null;
        var expCtxUtilsObj = null;
        try { expCtxUtilsObj = ExpressionContextUtils; } catch(e) {}

        AuthManager.init(pluginSettings, ifaceObj, qProjObj, qfSettingsObj, expCtxUtilsObj);
        ApiClient.init(AuthManager, ifaceObj);
        SyncEngine.init(ApiClient, ifaceObj, _executeBboxProxy, qProjObj, _executeGpkgProxy);

        // Initialize reactive properties from persistent settings
        pluginSettings.isLoggedIn = AuthManager.isLoggedIn();

        // Register our button drawer in QField UI
        if (typeof iface !== "undefined" && typeof iface.addItemToPluginsToolbar === "function") {
            try {
                iface.addItemToPluginsToolbar(pluginDrawer);
            } catch (e) {
                iface.logMessage("Failed to add QField4OBM to QField UI via iface:", e);
            }
        }
    }

    // Listen for project load events. The plugin loads as an app-wide plugin
    // BEFORE any project is opened, so qgisProject.fileName is empty during
    // Component.onCompleted. When a project is subsequently loaded, QField
    // emits fileNameChanged, and we restore the saved session at that point.
    Connections {
        target: typeof qgisProject !== "undefined" ? qgisProject : null
        function onFileNameChanged() {
            if (typeof iface !== "undefined") {
                iface.logMessage("QField4OBM: project changed to: " + qgisProject.fileName);
            }
            AuthManager.restoreSession();
            pluginSettings.isLoggedIn = AuthManager.isLoggedIn();

            // Re-add OBM sync layers that may be missing from the .qgs file
            var _fileUtilsRestore = null; try { _fileUtilsRestore = FileUtils; } catch(e) {}
            Utils.restoreObmLayers(typeof qgisProject !== "undefined" ? qgisProject : null, _fileUtilsRestore, typeof settings !== "undefined" ? settings : null, typeof iface !== "undefined" ? iface : null, _applyQgsStyle, typeof LayerUtils !== "undefined" ? LayerUtils : null, typeof ProjectUtils !== "undefined" ? ProjectUtils : null);
        }
    }

    property var mainWindow: iface ? iface.mainWindow() : null

    function openMainDialog() {
        if (AuthManager.isLoggedIn()) {
            dashboardPopup.open();
        } else {
            loginPopup.open();
        }
    }

    Components.LoginPopup {
        id: loginPopup
    }

    Components.DashboardPopup {
        id: dashboardPopup
    }

    Components.FilterBuilderPopup {
        id: filterBuilderPopup
    }

    Components.StyleAndBboxPopup {
        id: styleAndBboxPopup
    }

    Components.ProjectSelectionPopup {
        id: projectsPopup
    }

    // Fallback UI if iface isn't present (e.g., testing in standalone QML runner)
    Button {
        id: testButton
        text: "Test Login UI"
        anchors.centerIn: parent
        implicitHeight: 48
        visible: typeof iface === "undefined"
        onClicked: openMainDialog()
    }

    Components.SyncResultPopup {
        id: syncResultPopup
    }
}
