import QtQuick 2.12
import QtTest 1.12

/**
 * Unit tests for the _executeGpkgProxy function in main.qml.
 *
 * Since _executeGpkgProxy is an inline function inside main.qml and
 * depends on QML/C++ singletons (LayerUtils, CoordinateReferenceSystemUtils,
 * qgisProject, iface, settings), we re-implement the refactored logic here
 * under test, injecting lightweight mock objects that simulate the C++ API
 * surface.  This verifies:
 *
 *   1. typeof guards are NOT used — methods are called directly.
 *   2. try/catch blocks capture TypeErrors when methods are absent.
 *   3. null/empty returns from each step produce explicit saveMsg strings.
 *   4. The full CREATE pipeline (memory → GPKG → load → addMapLayer → style).
 *   5. The APPEND branch is preserved.
 *   6. The getMaxOmbId action still works.
 */
Item {
    id: window
    width: 400
    height: 400

    TestCase {
        name: "GpkgProxyTests"
        when: window.visible

        // -----------------------------------------------------------------
        // Helpers — minimal re-implementation of _executeGpkgProxy logic
        // that mirrors the refactored main.qml version.  This lets us
        // verify the *shape* of the refactored code with injectable mocks.
        // -----------------------------------------------------------------

        /** Log accumulator so tests can inspect messages. */
        property var logMessages: []

        /** Mock iface that captures log messages. */
        property var mockIface: ({
            logMessage: function(msg) {
                logMessages.push(msg);
            }
        })

        /** Mock settings storage (in-memory). */
        property var settingsStore: ({})
        property var mockSettings: ({
            value: function(key, def) {
                return settingsStore.hasOwnProperty(key) ? settingsStore[key] : def;
            },
            setValue: function(key, val) {
                settingsStore[key] = val;
            }
        })

        /** Default style config stub. */
        property var defaultStyle: ({ color: "#ff0000", sizeOrThickness: 2, styleType: "Circle" })

        /**
         * Factory: create a mock LayerUtils with configurable behaviour.
         * Each method is present and functional unless overridden.
         */
        function makeLayerUtils(overrides) {
            var base = {
                memoryLayerFromJsonString: function(name, json, crs) {
                    return { _mock: true, _name: name, _featureCount: JSON.parse(json).features.length };
                },
                saveVectorLayerAs: function(layer, path) {
                    return path; // echo back the path on success
                },
                loadVectorLayer: function(path, name, provider) {
                    return { _mock: true, _path: path, _name: name, getFeatures: function() { return { next: function() { return null; } }; } };
                }
            };
            if (overrides) {
                for (var k in overrides) base[k] = overrides[k];
            }
            return base;
        }

        /**
         * Factory: create a mock qgisProject.
         */
        function makeMockProject(overrides) {
            var base = {
                homePath: function() { return "/tmp/gpkg_proxy_test"; },
                mapLayers: function() { return {}; },
                mapLayersByName: function(name) { return []; },
                addMapLayer: function(layer) { /* no-op */ },
                setDirty: function(dirty) { /* no-op */ },
                customProperty: function(key, def) {
                    return settingsStore.hasOwnProperty(key) ? settingsStore[key] : def;
                },
                setCustomProperty: function(key, val) {
                    settingsStore[key] = val;
                }
            };
            if (overrides) {
                for (var k in overrides) base[k] = overrides[k];
            }
            return base;
        }

        /**
         * Factory: mock CoordinateReferenceSystemUtils
         */
        function makeMockCrsUtils(overrides) {
            var base = {
                wgs84Crs: function() { return { _crs: "EPSG:4326" }; },
                fromDescription: function(desc) { return { _crs: desc }; }
            };
            if (overrides) {
                for (var k in overrides) base[k] = overrides[k];
            }
            return base;
        }

        /**
         * Portable re-implementation of the refactored _executeGpkgProxy.
         * Accepts injectable dependencies so we can test each code path.
         */
        function executeGpkgProxy(params, deps) {
            var ifaceObj  = deps.iface || null;
            var luObj     = deps.LayerUtils || null;
            var crsObj    = deps.CrsUtils || null;
            var projObj   = deps.qgisProject || null;
            var setObj    = deps.settings || null;

            if (!params || !params.action) return null;

            try {
                // ----- getMaxOmbId -----
                if (params.action === "getMaxOmbId") {
                    var projectLayers = null;
                    try {
                        if (projObj) {
                            try {
                                projectLayers = projObj.mapLayersByName(params.layerName);
                            } catch(e1) {
                                var allL = projObj.mapLayers();
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
                        if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: mapLayers scan error: " + ep);
                    }

                    var targetLayer = (projectLayers && projectLayers.length > 0) ? projectLayers[0] : null;
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
                        } catch(e3) {
                            if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: Feature iteration failed: " + e3);
                        }
                    }

                    if (maxId === 0 && projObj) {
                        try {
                            var stored = projObj.customProperty("QField4OBM/maxOmbId_" + params.layerName, 0);
                            var storedNum = parseInt(stored, 10);
                            if (!isNaN(storedNum) && storedNum > 0) maxId = storedNum;
                        } catch(es) {}
                    }

                    if (maxId === 0 && params.gpkgPath && luObj) {
                        try {
                            var offlineLayer = luObj.loadVectorLayer(params.gpkgPath, params.layerName, "ogr");
                            if (offlineLayer) {
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
                                } catch(eo3) {}
                            }
                        } catch(eo2) {}
                    }

                    return { maxOmbId: maxId };
                }

                // ----- saveFeatures -----
                if (params.action === "saveFeatures") {
                    var fc = JSON.parse(params.featureCollectionJson);
                    var features  = fc.features || [];
                    var layerName = params.layerName;
                    var gpkgPath  = params.gpkgPath;
                    var geomType  = params.geomType;
                    var style     = params.styleConfig || {};

                    if (features.length === 0) {
                        return { success: true, message: "No features to save" };
                    }

                    // Look for existing layer
                    var existingLayer = null;
                    try {
                        if (projObj) {
                            var byName = null;
                            try {
                                byName = projObj.mapLayersByName(layerName);
                            } catch(e) {}
                            if (byName && byName.length > 0) {
                                existingLayer = byName[0];
                            }
                        }
                    } catch(el) {}

                    var savedOk = false;
                    var saveMsg = "";

                    if (existingLayer) {
                        // APPEND branch — preserved
                        try {
                            var startOk = existingLayer.startEditing();
                            if (!startOk) {
                                saveMsg = "startEditing() returned false — layer may not be editable";
                            } else {
                                existingLayer.commitChanges();
                                savedOk = true;
                                saveMsg = "Appended " + features.length + " features.";

                                // Mark project dirty so QField's own save-on-exit persists the layer
                                try { projObj.setDirty(true); } catch(eDirtyA) {}
                            }
                        } catch(ea) {
                            saveMsg = "Append exception: " + ea.toString();
                            try { existingLayer.rollBack(); } catch(r) {}
                        }
                    } else {
                        // CREATE branch — refactored: no typeof guards
                        if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: CREATE — using LayerUtils API pipeline");

                        var geojsonFc2 = { type: "FeatureCollection", features: features };
                        var geojsonString = JSON.stringify(geojsonFc2);

                        // STEP 1: memory layer
                        var newLayer = null;
                        try {
                            var wgs84Crs = null;
                            try {
                                wgs84Crs = crsObj.wgs84Crs();
                            } catch(eCrsMain) {
                                if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: wgs84Crs() unavailable, trying fromDescription: " + eCrsMain);
                                try {
                                    wgs84Crs = crsObj.fromDescription("EPSG:4326");
                                } catch(eCrsFallback) {
                                    if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: fromDescription() also unavailable: " + eCrsFallback);
                                }
                            }

                            // Direct call — no typeof guard
                            newLayer = luObj.memoryLayerFromJsonString(layerName, geojsonString, wgs84Crs);
                            if (newLayer) {
                                if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: Memory layer created");
                            } else {
                                saveMsg = "LayerUtils.memoryLayerFromJsonString returned null — GeoJSON may be invalid or CRS missing";
                                if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                            }
                        } catch(eCreate) {
                            saveMsg = "memoryLayerFromJsonString failed: " + eCreate.toString();
                            if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                        }

                        if (newLayer) {
                            // STEP 2: export to GPKG — direct call
                            var gpkgWritten = "";
                            try {
                                gpkgWritten = luObj.saveVectorLayerAs(newLayer, gpkgPath);
                                if (gpkgWritten && gpkgWritten.length > 0) {
                                    if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: Exported to GPKG: " + gpkgWritten);
                                } else {
                                    saveMsg = "saveVectorLayerAs returned empty — GPKG write failed (check disk permissions or path: " + gpkgPath + ")";
                                    if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                                }
                            } catch(eExport) {
                                saveMsg = "GPKG export failed: " + eExport.toString();
                                if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                            }

                            // STEP 3: load physical layer — direct call
                            var loadedPhysicalLayer = null;
                            var physicalGpkgPath = (gpkgWritten && gpkgWritten.length > 0) ? gpkgWritten : gpkgPath;

                            if (gpkgWritten && gpkgWritten.length > 0) {
                                try {
                                    loadedPhysicalLayer = luObj.loadVectorLayer(physicalGpkgPath, layerName, "ogr");
                                    if (loadedPhysicalLayer) {
                                        if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: Physical GPKG layer loaded");
                                    } else {
                                        saveMsg = "LayerUtils.loadVectorLayer returned null — GPKG file may be corrupt at " + physicalGpkgPath;
                                        if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                                    }
                                } catch(eLoad) {
                                    saveMsg = "Failed to load physical GPKG: " + eLoad.toString();
                                    if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                                }

                                // addMapLayer — direct call
                                if (loadedPhysicalLayer) {
                                    try {
                                        projObj.addMapLayer(loadedPhysicalLayer);
                                        savedOk = true;
                                        saveMsg = "GPKG layer created with " + features.length + " features at " + physicalGpkgPath;
                                        if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: Physical GPKG layer added to project");

                                        // Mark dirty + register in project variable for restore-on-load
                                        try { projObj.setDirty(true); } catch(eDirty) {}
                                        if (deps.registerObmLayer) {
                                            deps.registerObmLayer(physicalGpkgPath, layerName, geomType, style);
                                        }
                                    } catch(eAdd) {
                                        saveMsg = "addMapLayer failed: " + eAdd.toString();
                                        if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                                    }
                                }
                            } else {
                                if (!saveMsg) saveMsg = "Skipped GPKG load — export produced no output file";
                                if (ifaceObj) ifaceObj.logMessage("QField4OBM Proxy: " + saveMsg);
                            }

                            newLayer = null;
                        } else {
                            if (!saveMsg) saveMsg = "Failed to create memory layer via LayerUtils";
                        }
                    }

                    if (savedOk && setObj) {
                        try {
                            var maxOid = 0;
                            for (var osi = 0; osi < features.length; osi++) {
                                var oid = features[osi].properties && features[osi].properties.obm_id;
                                if (oid && parseInt(oid, 10) > maxOid) maxOid = parseInt(oid, 10);
                            }
                            if (maxOid > 0) {
                                setObj.setValue("QField4OBM/maxOmbId_" + layerName, String(maxOid));
                            }
                        } catch(eset) {}
                    }

                    return { success: savedOk, message: saveMsg };
                }

            } catch (e) {
                return { success: false, message: e.toString() };
            }

            return null;
        }

        // =====================================================================
        // Setup
        // =====================================================================

        function init() {
            logMessages = [];
            settingsStore = {};
        }

        // =====================================================================
        // Tests — Happy path
        // =====================================================================

        /**
         * Full CREATE pipeline succeeds when all LayerUtils methods work.
         */
        function test_createPipeline_happyPath() {
            var addMapLayerCalled = false;
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    addMapLayer: function(layer) { addMapLayerCalled = true; }
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [
                    { type: "Feature", geometry: { type: "Point", coordinates: [19, 47] }, properties: { obm_id: 10 } },
                    { type: "Feature", geometry: { type: "Point", coordinates: [20, 48] }, properties: { obm_id: 20 } }
                ]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "testLayer",
                gpkgPath: "/tmp/test.gpkg",
                geomType: "Point",
                styleConfig: defaultStyle
            }, deps);

            compare(result.success, true, "Full pipeline should succeed");
            verify(result.message.indexOf("2 features") !== -1, "Message should mention feature count");
            compare(addMapLayerCalled, true, "addMapLayer should have been called");
            // Verify max obm_id was persisted
            compare(settingsStore["QField4OBM/maxOmbId_testLayer"], "20", "Max obm_id should be 20");
        }

        // =====================================================================
        // Tests — memoryLayerFromJsonString failures (no typeof guard)
        // =====================================================================

        /**
         * When LayerUtils.memoryLayerFromJsonString throws (simulating a
         * missing method or wrong signature), the catch block produces an
         * explicit error message — NOT a silent skip.
         */
        function test_memoryLayerThrows_producesError() {
            logMessages = [];
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils({
                    memoryLayerFromJsonString: function() { throw new TypeError("memoryLayerFromJsonString is not a function"); }
                }),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "failLayer",
                gpkgPath: "/tmp/fail.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should report failure when memoryLayerFromJsonString throws");
            verify(result.message.indexOf("memoryLayerFromJsonString failed") !== -1,
                   "Error message should contain the method name");
            // Ensure the error was logged
            var foundLog = false;
            for (var i = 0; i < logMessages.length; i++) {
                if (logMessages[i].indexOf("memoryLayerFromJsonString failed") !== -1) foundLog = true;
            }
            verify(foundLog, "Error should be logged via iface.logMessage");
        }

        /**
         * When memoryLayerFromJsonString returns null, saveMsg is set
         * explicitly — no silent empty result.
         */
        function test_memoryLayerReturnsNull_setsExplicitMessage() {
            logMessages = [];
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils({
                    memoryLayerFromJsonString: function() { return null; }
                }),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "nullLayer",
                gpkgPath: "/tmp/null.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should report failure when memory layer is null");
            verify(result.message.length > 0, "Error message must not be empty (no silent failures)");
            verify(result.message.indexOf("null") !== -1 || result.message.indexOf("Failed") !== -1,
                   "Message should describe the null return");
        }

        // =====================================================================
        // Tests — saveVectorLayerAs failures
        // =====================================================================

        /**
         * When saveVectorLayerAs throws, the catch block captures the error
         * and the pipeline halts with an explicit message.
         */
        function test_saveVectorLayerAsThrows_producesError() {
            logMessages = [];
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils({
                    saveVectorLayerAs: function() { throw new Error("Disk full"); }
                }),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "diskFull",
                gpkgPath: "/tmp/diskfull.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should fail when GPKG export throws");
            verify(result.message.indexOf("GPKG export failed") !== -1,
                   "Error message should mention GPKG export failure");
        }

        /**
         * When saveVectorLayerAs returns empty string, the pipeline does NOT
         * attempt to load the layer, and sets an explicit saveMsg.
         */
        function test_saveVectorLayerAsReturnsEmpty_haltsLoad() {
            logMessages = [];
            var loadCalled = false;
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils({
                    saveVectorLayerAs: function() { return ""; },
                    loadVectorLayer: function() { loadCalled = true; return {}; }
                }),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "emptyExport",
                gpkgPath: "/tmp/empty.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should fail when GPKG export returns empty");
            compare(loadCalled, false, "loadVectorLayer must NOT be called when export returned empty");
            verify(result.message.length > 0, "Error message must not be empty");
        }

        // =====================================================================
        // Tests — loadVectorLayer failures
        // =====================================================================

        /**
         * When loadVectorLayer throws, the error is captured and reported.
         */
        function test_loadVectorLayerThrows_producesError() {
            logMessages = [];
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils({
                    loadVectorLayer: function() { throw new Error("ogr provider missing"); }
                }),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "loadFail",
                gpkgPath: "/tmp/loadfail.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should fail when loadVectorLayer throws");
            verify(result.message.indexOf("Failed to load physical GPKG") !== -1,
                   "Error message should mention load failure");
        }

        /**
         * When loadVectorLayer returns null, addMapLayer is never called.
         */
        function test_loadVectorLayerReturnsNull_skipsAddMapLayer() {
            logMessages = [];
            var addCalled = false;
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils({
                    loadVectorLayer: function() { return null; }
                }),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    addMapLayer: function() { addCalled = true; }
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "nullLoad",
                gpkgPath: "/tmp/nullload.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should fail when loaded layer is null");
            compare(addCalled, false, "addMapLayer must NOT be called when loaded layer is null");
            verify(result.message.indexOf("null") !== -1, "Message should describe the null return");
        }

        // =====================================================================
        // Tests — addMapLayer failure
        // =====================================================================

        /**
         * When addMapLayer throws, the error is captured and savedOk stays false.
         */
        function test_addMapLayerThrows_producesError() {
            logMessages = [];
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    addMapLayer: function() { throw new Error("project read-only"); }
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "addFail",
                gpkgPath: "/tmp/addfail.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should fail when addMapLayer throws");
            verify(result.message.indexOf("addMapLayer failed") !== -1,
                   "Error message should mention addMapLayer failure");
        }

        // =====================================================================
        // Tests — Layer persistence (QSettings registry + restore-on-load)
        // =====================================================================

        /**
         * After a successful CREATE, setDirty(true) is called and
         * registerObmLayer is invoked to persist the layer info in project variables.
         */
        function test_createPipeline_registersLayerInSettings() {
            logMessages = [];
            var setDirtyCalled = false;
            var registeredLayer = null;

            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    addMapLayer: function(layer) { /* success */ },
                    setDirty: function(dirty) { setDirtyCalled = dirty; }
                }),
                settings: mockSettings,
                registerObmLayer: function(path, name, geom, style) {
                    registeredLayer = { gpkgPath: path, layerName: name, geomType: geom, style: style };
                }
            };

            var fc = JSON.stringify({
                features: [
                    { type: "Feature", geometry: { type: "Point", coordinates: [19, 47] }, properties: { obm_id: 1 } }
                ]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "persistLayer",
                gpkgPath: "/tmp/persist.gpkg",
                geomType: "Point",
                styleConfig: defaultStyle
            }, deps);

            compare(result.success, true, "CREATE pipeline should succeed");
            compare(setDirtyCalled, true, "setDirty(true) must be called after addMapLayer");
            verify(registeredLayer !== null, "registerObmLayer must be called to persist layer info");
            compare(registeredLayer.layerName, "persistLayer", "Registered layer name must match");
            compare(registeredLayer.gpkgPath, "/tmp/persist.gpkg", "Registered GPKG path must match");
            compare(registeredLayer.geomType, "Point", "Registered geomType must match");
        }

        /**
         * After a successful APPEND, setDirty(true) is called.
         */
        function test_appendBranch_setsDirty() {
            logMessages = [];
            var setDirtyCalled = false;

            var existingLayer = {
                source: "/tmp/appenddirty.gpkg",
                startEditing: function() { return true; },
                commitChanges: function() {},
                rollBack: function() {}
            };

            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    mapLayersByName: function(name) {
                        return name === "appendDirtyTable" ? [existingLayer] : [];
                    },
                    setDirty: function(dirty) { setDirtyCalled = dirty; }
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "appendDirtyTable",
                gpkgPath: "/tmp/appenddirty.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, true, "APPEND should succeed");
            compare(setDirtyCalled, true, "setDirty(true) must be called after append");
        }

        /**
         * _registerObmLayer logic: stores layer info in a sidecar JSON file
         * and updates existing entries by layerName.
         */
        function test_registerObmLayer_storesAndUpdates() {
            // Mock FileUtils with in-memory file storage
            var fileStore = {};
            var mockFileUtils = {
                readFileContent: function(path) { return fileStore[path] || ""; },
                writeFileContent: function(path, content) { fileStore[path] = content; return true; }
            };
            var mockProj = makeMockProject({ fileName: "/tmp/project/test.qgz" });

            // Simulate registerObmLayer logic (mirrors Utils.js sidecar file approach)
            var registryPath = "/tmp/project/obm_layer_registry.json";
            function registerObmLayer(gpkgPath, layerName, geomType, styleConfig) {
                var raw = mockFileUtils.readFileContent(registryPath);
                var layers = (raw && raw.length > 0) ? JSON.parse(raw) : [];
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
                    layers.push({ gpkgPath: gpkgPath, layerName: layerName, geomType: geomType, style: styleConfig || {} });
                }
                mockFileUtils.writeFileContent(registryPath, JSON.stringify(layers));
            }

            // Register first layer
            registerObmLayer("/tmp/birds.gpkg", "birds_Point", "Point", { color: "#ff0000" });
            var stored = JSON.parse(mockFileUtils.readFileContent(registryPath) || "[]");
            compare(stored.length, 1, "Should have 1 registered layer");
            compare(stored[0].layerName, "birds_Point", "Layer name should match");

            // Register second layer
            registerObmLayer("/tmp/tracks.gpkg", "tracks_Line", "Line", { color: "#00ff00" });
            stored = JSON.parse(mockFileUtils.readFileContent(registryPath) || "[]");
            compare(stored.length, 2, "Should have 2 registered layers");

            // Update first layer (same name, new path)
            registerObmLayer("/tmp/birds_v2.gpkg", "birds_Point", "Point", { color: "#0000ff" });
            stored = JSON.parse(mockFileUtils.readFileContent(registryPath) || "[]");
            compare(stored.length, 2, "Should still have 2 layers (update, not add)");
            compare(stored[0].gpkgPath, "/tmp/birds_v2.gpkg", "Path should be updated");
            compare(stored[0].style.color, "#0000ff", "Style should be updated");
        }

        /**
         * _restoreObmLayers logic: re-adds missing layers from sidecar file registry.
         * Layers already in the project are skipped.
         */
        function test_restoreObmLayers_reAddsMissingLayers() {
            logMessages = [];

            // Pre-populate the sidecar registry file with 2 layers
            var registry = [
                { gpkgPath: "/tmp/birds.gpkg", layerName: "birds_Point", geomType: "Point", style: { color: "#ff0000" } },
                { gpkgPath: "/tmp/tracks.gpkg", layerName: "tracks_Line", geomType: "Line", style: { color: "#00ff00" } }
            ];
            var registryPath = "/tmp/project/obm_layer_registry.json";
            var fileStore = {};
            fileStore[registryPath] = JSON.stringify(registry);
            var mockFileUtils = {
                readFileContent: function(path) { return fileStore[path] || ""; },
                writeFileContent: function(path, content) { fileStore[path] = content; return true; }
            };

            var addedLayers = [];

            // Mock project where "birds_Point" already exists, "tracks_Line" does not
            var mockProj = makeMockProject({
                fileName: "/tmp/project/test.qgz",
                mapLayersByName: function(name) {
                    return name === "birds_Point" ? [{ _existing: true }] : [];
                },
                addMapLayer: function(layer) { addedLayers.push(layer); },
                setDirty: function() {}
            });

            var mockLU = makeLayerUtils({
                loadVectorLayer: function(path, name, provider) {
                    return { _restored: true, _path: path, _name: name };
                }
            });

            // Simulate _restoreObmLayers logic inline (mirrors Utils.js)
            var raw = mockFileUtils.readFileContent(registryPath);
            var layers = (raw && raw.length > 0) ? JSON.parse(raw) : [];
            for (var i = 0; i < layers.length; i++) {
                var entry = layers[i];
                var alreadyLoaded = false;
                try {
                    var byName = mockProj.mapLayersByName(entry.layerName);
                    if (byName && byName.length > 0) alreadyLoaded = true;
                } catch(e) {}

                if (alreadyLoaded) continue;

                var restoredLayer = mockLU.loadVectorLayer(entry.gpkgPath, entry.layerName, "ogr");
                if (restoredLayer) {
                    mockProj.addMapLayer(restoredLayer);
                }
            }

            compare(addedLayers.length, 1, "Only the missing layer should be re-added");
            compare(addedLayers[0]._name, "tracks_Line", "The restored layer should be tracks_Line");
            compare(addedLayers[0]._path, "/tmp/tracks.gpkg", "Restored from correct GPKG path");
        }

        // =====================================================================
        // Tests — CRS fallback
        // =====================================================================

        /**
         * When wgs84Crs() throws, the code falls back to fromDescription().
         * The pipeline should still succeed.
         */
        function test_crs_fallbackToFromDescription() {
            logMessages = [];
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils({
                    wgs84Crs: function() { throw new Error("wgs84Crs not available"); }
                }),
                qgisProject: makeMockProject({
                    addMapLayer: function() {}
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 5 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "crsFallback",
                gpkgPath: "/tmp/crsfallback.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, true, "Pipeline should succeed even if wgs84Crs() throws, using fromDescription fallback");
            // Check that the fallback log was emitted
            var foundFallbackLog = false;
            for (var i = 0; i < logMessages.length; i++) {
                if (logMessages[i].indexOf("wgs84Crs() unavailable") !== -1) foundFallbackLog = true;
            }
            verify(foundFallbackLog, "Should log the wgs84Crs fallback attempt");
        }

        // =====================================================================
        // Tests — Empty features
        // =====================================================================

        /**
         * When features array is empty, the function returns early with success.
         */
        function test_emptyFeatures_returnsEarlySuccess() {
            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var fc = JSON.stringify({ features: [] });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "empty",
                gpkgPath: "/tmp/empty.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, true, "Empty features should return success");
            compare(result.message, "No features to save", "Message should indicate no features");
        }

        // =====================================================================
        // Tests — getMaxOmbId
        // =====================================================================

        /**
         * getMaxOmbId returns the max obm_id from project layer features.
         */
        function test_getMaxOmbId_fromProjectLayer() {
            var mockLayer = {
                source: "/tmp/obs_Point.gpkg",
                getFeatures: function() {
                    var feats = [
                        { isNull: function() { return false; }, attribute: function(f) { return f === "obm_id" ? 42 : null; } },
                        { isNull: function() { return false; }, attribute: function(f) { return f === "obm_id" ? 99 : null; } }
                    ];
                    var idx = 0;
                    return { next: function() { return idx < feats.length ? feats[idx++] : null; } };
                }
            };

            var deps = {
                iface: mockIface,
                qgisProject: makeMockProject({
                    mapLayersByName: function(name) { return name === "obs" ? [mockLayer] : []; }
                }),
                settings: mockSettings
            };

            var result = executeGpkgProxy({ action: "getMaxOmbId", layerName: "obs" }, deps);

            compare(result.maxOmbId, 99, "Should return max obm_id from layer features");
        }

        /**
         * getMaxOmbId falls back to settings when no layer is found.
         */
        function test_getMaxOmbId_fallbackToSettings() {
            settingsStore["QField4OBM/maxOmbId_missingLayer"] = "150";

            var deps = {
                iface: mockIface,
                qgisProject: makeMockProject(),
                settings: mockSettings
            };

            var result = executeGpkgProxy({ action: "getMaxOmbId", layerName: "missingLayer" }, deps);

            compare(result.maxOmbId, 150, "Should fall back to settings-stored max obm_id");
        }

        // =====================================================================
        // Tests — APPEND branch
        // =====================================================================

        /**
         * When the layer already exists in the project, the APPEND branch
         * fires and reports success.
         */
        function test_appendBranch_existingLayer() {
            logMessages = [];
            var editStarted = false;
            var committed = false;

            var existingLayer = {
                source: "/tmp/existing.gpkg",
                startEditing: function() { editStarted = true; return true; },
                commitChanges: function() { committed = true; },
                rollBack: function() {}
            };

            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    mapLayersByName: function(name) {
                        return name === "existingTable" ? [existingLayer] : [];
                    }
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "existingTable",
                gpkgPath: "/tmp/existing.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, true, "APPEND branch should succeed");
            compare(editStarted, true, "startEditing should have been called");
            compare(committed, true, "commitChanges should have been called");
        }

        /**
         * When startEditing returns false, the APPEND branch reports failure
         * with an explicit message.
         */
        function test_appendBranch_startEditingFails() {
            logMessages = [];
            var existingLayer = {
                source: "/tmp/readonly.gpkg",
                startEditing: function() { return false; },
                commitChanges: function() {},
                rollBack: function() {}
            };

            var deps = {
                iface: mockIface,
                LayerUtils: makeLayerUtils(),
                CrsUtils: makeMockCrsUtils(),
                qgisProject: makeMockProject({
                    mapLayersByName: function(name) {
                        return name === "readonlyTable" ? [existingLayer] : [];
                    }
                }),
                settings: mockSettings
            };

            var fc = JSON.stringify({
                features: [{ type: "Feature", geometry: { type: "Point", coordinates: [0,0] }, properties: { obm_id: 1 } }]
            });

            var result = executeGpkgProxy({
                action: "saveFeatures",
                featureCollectionJson: fc,
                layerName: "readonlyTable",
                gpkgPath: "/tmp/readonly.gpkg",
                geomType: "Point"
            }, deps);

            compare(result.success, false, "Should fail when startEditing returns false");
            verify(result.message.indexOf("startEditing") !== -1,
                   "Error message should mention startEditing");
        }

        // =====================================================================
        // Tests — null/undefined params
        // =====================================================================

        /**
         * Passing null params returns null (not an exception).
         */
        function test_nullParams_returnsNull() {
            var result = executeGpkgProxy(null, { iface: mockIface });
            compare(result, null, "Null params should return null");
        }

        /**
         * Passing params without action returns null.
         */
        function test_missingAction_returnsNull() {
            var result = executeGpkgProxy({ foo: "bar" }, { iface: mockIface });
            compare(result, null, "Missing action should return null");
        }
    }
}
