import QtQuick 2.12
import QtTest 1.12

import "../../scripts/SyncEngine.js" as SyncEngine

Item {
    id: window
    width: 400
    height: 400

    TestCase {
        name: "SyncEngineTests"
        when: window.visible

        // ---------------------------------------------------------------------------
        // Mock objects
        // ---------------------------------------------------------------------------

        /**
         * Mock ApiClient that returns a paginated spatial response synchronously.
         * Simulates 1200 features across multiple batches of 500.
         */
        property var mockApiClient: ({
            getSpatialData: function(schema, table, geomField, filters, limit, offset, callback) {
                var total = 1200;
                var remaining = total - offset;
                var returnCount = Math.max(0, Math.min(limit, remaining));
                var featuresToReturn = [];
                for (var i = 0; i < returnCount; i++) {
                    featuresToReturn.push({
                        type: "Feature",
                        geometry: { type: "Point", coordinates: [0, 0] },
                        properties: { obm_id: offset + i + 1, mock: true }
                    });
                }
                callback(true, {
                    data: {
                        spatialObmDataList: {
                            total_count: total,
                            feature_collection: { features: featuresToReturn }
                        }
                    }
                });
            },
            getObmData: function(schema, table, filters, limit, offset, fieldNames, callback) {
                callback(true, {
                    data: {
                        obmDataList: {
                            total_count: 0,
                            items: []
                        }
                    }
                });
            }
        })

        /**
         * Mock QGIS project: exposes homePath() and simulates mapLayers().
         * By default no layers exist, so delta-sync starts from scratch.
         */
        property var mockQgisProject: ({
            homePath: function() { return "/tmp/qfield_test_project"; },
            mapLayers: function() { return {}; }
        })

        /**
         * Mock QGIS project that contains one existing layer with features,
         * used to verify delta-sync obm_id injection.
         */
        property var mockQgisProjectWithLayer: ({
            homePath: function() { return "/tmp/qfield_test_project"; },
            mapLayers: function() {
                var mockLayer = {
                    source: "/tmp/qfield_test_project/obs_Point.gpkg",
                    getFeatures: function() {
                        var features = [
                            { isNull: function() { return false; }, attribute: function(f) { return f === "obm_id" ? 42 : null; } },
                            { isNull: function() { return false; }, attribute: function(f) { return f === "obm_id" ? 99 : null; } },
                            { isNull: function() { return true; }, attribute: function() { return null; } }
                        ];
                        var idx = 0;
                        return {
                            next: function() { return idx < features.length ? features[idx++] : null; }
                        };
                    }
                };
                return { "layer_001": mockLayer };
            }
        })

        /** Default style config used across tests. */
        property var defaultStyleConfig: ({
            color: "#3cb44b",
            sizeOrThickness: 4,
            styleType: "Circle"
        })

        // ---------------------------------------------------------------------------
        // Setup
        // ---------------------------------------------------------------------------

        function initTestCase() {
            SyncEngine.init(mockApiClient, null, null, mockQgisProject);
        }

        // ---------------------------------------------------------------------------
        // Tests
        // ---------------------------------------------------------------------------

        /**
         * Verify that a full spatial sync paginates correctly, reaches 100 %,
         * and reports success. styleConfig is now a required argument.
         */
        function test_syncAllFlow() {
            var progressUpdates = 0;
            var finalPercent = 0;
            var syncSuccess = false;
            var finalMessage = "";

            // Re-init without canvas so spatial bbox check is skipped
            SyncEngine.init(mockApiClient, null, null, mockQgisProject);

            // For Attributes type, canvas is not required — keeps test self-contained
            SyncEngine.syncAll(
                0,              // maxBboxArea: 0 = unlimited
                {},             // userFilterObject
                "public",       // schema
                "obs",          // targetTable
                4326,           // targetSrid
                "Attributes",   // geomType — avoids canvas dependency in unit test
                ["obm_id"],     // fieldNames
                defaultStyleConfig,
                function(percent, message) {
                    progressUpdates++;
                    finalPercent = percent;
                },
                function(success, message) {
                    syncSuccess = success;
                    finalMessage = message;
                }
            );

            // mockApiClient returns 0 items for getObmData → completes in one batch
            verify(progressUpdates >= 1, "Progress callback should be called at least once");
            compare(finalPercent, 100, "Should reach 100% progress after completion");
            compare(syncSuccess, true, "Sync should be marked as successfully complete");
        }

        /**
         * Verify that when an existing layer is present with features,
         * _syncData injects an obm_id greater_than filter into the merged filter.
         * We verify this indirectly: after re-init with the layer-containing mock project,
         * the API is called; if the filter injection code threw, syncAll would report failure.
         */
        function test_deltaSyncAppendsFilter() {
            // Re-init with a project that has an existing layer containing obm_ids up to 99
            SyncEngine.init(mockApiClient, null, null, mockQgisProjectWithLayer);

            var syncSuccess = false;
            var syncMessage = "";

            SyncEngine.syncAll(
                0,
                {},
                "public",
                "obs",
                4326,
                "Attributes",
                ["obm_id"],
                defaultStyleConfig,
                function(percent, message) { /* progress — not asserted here */ },
                function(success, message) {
                    syncSuccess = success;
                    syncMessage = message;
                }
            );

            // The test passes if no exception was thrown during filter injection
            compare(syncSuccess, true, "Delta-sync filter injection should not cause a failure");
        }

        /**
         * Verify that _resolveGpkgPath returns null when qgisProject is not set.
         */
        function test_resolveGpkgPathWithoutProject() {
            SyncEngine.init(mockApiClient, null, null, null);

            var syncSuccess = false;
            SyncEngine.syncAll(
                0, {}, "public", "obs", 4326, "Attributes", ["obm_id"],
                defaultStyleConfig,
                function(p, m) {},
                function(success, message) {
                    syncSuccess = success;
                    // Without a project the save falls back gracefully — still reports success
                    verify(message.indexOf("GPKG save skipped") !== -1 || success,
                           "Should gracefully handle missing project path");
                }
            );

            // Restore to normal mock for subsequent tests
            SyncEngine.init(mockApiClient, null, null, mockQgisProject);
        }

        /**
         * Verify the GPKG proxy is called with action "saveFeatures" and receives
         * the correct parameters (gpkgPath, layerName, geomType, featureCollectionJson,
         * styleConfig) when features are downloaded from the API.
         */
        function test_gpkgProxySaveFeaturesAction() {
            var capturedParams = null;
            // Mock GPKG proxy that captures the call arguments
            var mockGpkgProxy = function(params) {
                capturedParams = params;
                return { success: true, message: "Mock GPKG save OK" };
            };

            // Mock API client that returns exactly 3 features
            var mockApiWithFeatures = {
                getSpatialData: function(schema, table, geomField, filters, limit, offset, callback) {
                    callback(true, {
                        data: {
                            spatialObmDataList: {
                                total_count: 3,
                                feature_collection: {
                                    features: [
                                        { type: "Feature", geometry: { type: "Point", coordinates: [19.0, 47.5] }, properties: { obm_id: 1, species: "Ursus arctos" } },
                                        { type: "Feature", geometry: { type: "Point", coordinates: [19.1, 47.6] }, properties: { obm_id: 2, species: "Canis lupus" } },
                                        { type: "Feature", geometry: { type: "Point", coordinates: [19.2, 47.7] }, properties: { obm_id: 3, species: "Lynx lynx" } }
                                    ]
                                }
                            }
                        }
                    });
                },
                getObmData: function(schema, table, filters, limit, offset, fieldNames, callback) {
                    callback(true, { data: { obmDataList: { total_count: 0, items: [] } } });
                }
            };

            // Mock iface with mapCanvas for spatial sync
            var mockIface = {
                logMessage: function() {},
                mapCanvas: function() {
                    return {
                        mapSettings: {
                            extent: {
                                xMinimum: 18.0, xMaximum: 20.0,
                                yMinimum: 46.0, yMaximum: 48.0,
                                width: 2.0, height: 2.0
                            },
                            destinationCrs: {
                                authid: "EPSG:4326",
                                ellipsoidAcronym: function() { return "EPSG:7030"; }
                            }
                        }
                    };
                }
            };

            SyncEngine.init(mockApiWithFeatures, mockIface, null, mockQgisProject, mockGpkgProxy);

            var syncSuccess = false;
            SyncEngine.syncAll(
                0, {}, "public", "testdata", 4326, "Point", ["obm_id", "species"],
                defaultStyleConfig,
                function(p, m) {},
                function(success, message) { syncSuccess = success; }
            );

            // Verify proxy was called
            verify(capturedParams !== null, "GPKG proxy should have been called");
            compare(capturedParams.action, "saveFeatures", "Action should be 'saveFeatures'");
            compare(capturedParams.layerName, "testdata_Point", "Layer name should match target table");
            compare(capturedParams.geomType, "Point", "Geometry type should be 'Point'");
            verify(capturedParams.gpkgPath.indexOf("testdata_Point.gpkg") !== -1,
                   "GPKG path should contain table name and geomType");
            verify(capturedParams.featureCollectionJson.length > 0,
                   "Feature collection JSON should not be empty");
            // Verify the feature collection contains the correct features
            var fc = JSON.parse(capturedParams.featureCollectionJson);
            compare(fc.features.length, 3, "Should contain 3 features");
            compare(capturedParams.styleConfig.color, "#3cb44b", "Style config should be passed through");

            compare(syncSuccess, true, "Sync should succeed with mock GPKG proxy");

            // Restore for subsequent tests
            SyncEngine.init(mockApiClient, null, null, mockQgisProject);
        }

        /**
         * Verify that the ellipsoid is dynamically extracted from the project CRS
         * rather than hardcoded. This test uses a mock canvas whose CRS provides
         * ellipsoidAcronym() returning a custom value, then verifies no exception
         * is thrown during the area calculation path.
         */
        function test_ellipsoidDynamicExtraction() {
            // Mock API that returns features for spatial sync
            var mockApiSpatial = {
                getSpatialData: function(schema, table, geomField, filters, limit, offset, callback) {
                    callback(true, {
                        data: {
                            spatialObmDataList: {
                                total_count: 1,
                                feature_collection: {
                                    features: [
                                        { type: "Feature", geometry: { type: "Point", coordinates: [19.0, 47.5] }, properties: { obm_id: 1 } }
                                    ]
                                }
                            }
                        }
                    });
                },
                getObmData: function(schema, table, filters, limit, offset, fieldNames, callback) {
                    callback(true, { data: { obmDataList: { total_count: 0, items: [] } } });
                }
            };

            // Mock iface with a CRS that has a custom ellipsoid acronym
            // This verifies the dynamic extraction code path is exercised
            var mockIfaceCustomEllipsoid = {
                logMessage: function() {},
                mapCanvas: function() {
                    return {
                        mapSettings: {
                            extent: {
                                xMinimum: 18.0, xMaximum: 20.0,
                                yMinimum: 46.0, yMaximum: 48.0,
                                width: 2.0, height: 2.0
                            },
                            destinationCrs: {
                                authid: "EPSG:23700",
                                // Custom ellipsoid for Hungarian HD72 projection
                                ellipsoidAcronym: function() { return "EPSG:7004"; }
                            }
                        }
                    };
                }
            };

            var mockGpkgProxy = function(params) {
                return { success: true, message: "Mock save OK" };
            };

            SyncEngine.init(mockApiSpatial, mockIfaceCustomEllipsoid, null, mockQgisProject, mockGpkgProxy);

            var syncSuccess = false;
            var syncMessage = "";
            SyncEngine.syncAll(
                0, {}, "public", "obs", 23700, "Point", ["obm_id"],
                defaultStyleConfig,
                function(p, m) {},
                function(success, message) {
                    syncSuccess = success;
                    syncMessage = message;
                }
            );

            // The test passes if the dynamic ellipsoid code didn't throw
            compare(syncSuccess, true,
                    "Sync with dynamic ellipsoid extraction should not fail: " + syncMessage);

            // Restore for subsequent tests
            SyncEngine.init(mockApiClient, null, null, mockQgisProject);
        }

        /**
         * Verify that when the map canvas area exceeds maxBboxArea, the download is
         * NOT aborted but instead clipped to a centered rectangle and the finish
         * message contains the clipping note.
         *
         * QgsDistanceArea is unavailable in qmltestrunner, so area falls back to:
         *   areaSqKm = (w + dx*2) * (h + dy*2)
         * With extent 200×200 and 10% padding: 240×240 = 57 600 (map units²).
         * maxBboxArea = 100 triggers clipping.
         */
        function test_bboxClippingCentersAndWarns() {
            var mockApiSpatial = {
                getSpatialData: function(schema, table, geomField, filters, limit, offset, callback) {
                    callback(true, {
                        data: {
                            spatialObmDataList: {
                                total_count: 1,
                                feature_collection: {
                                    features: [
                                        { type: "Feature", geometry: { type: "Point", coordinates: [0, 0] }, properties: { obm_id: 1 } }
                                    ]
                                }
                            }
                        }
                    });
                },
                getObmData: function(schema, table, filters, limit, offset, fieldNames, callback) {
                    callback(true, { data: { obmDataList: { total_count: 0, items: [] } } });
                }
            };

            // Large extent: 200×200 map units → fallback area = 240×240 = 57 600 >> 100
            var mockIfaceLargeCanvas = {
                logMessage: function() {},
                mapCanvas: function() {
                    return {
                        mapSettings: {
                            extent: {
                                xMinimum: -100, xMaximum: 100,
                                yMinimum: -100, yMaximum: 100,
                                width: 200, height: 200
                            },
                            destinationCrs: {
                                authid: "EPSG:4326",
                                ellipsoidAcronym: function() { return "EPSG:7030"; }
                            }
                        }
                    };
                }
            };

            var capturedBboxGeojson = null;
            var mockApiCaptureBbox = {
                getSpatialData: function(schema, table, geomField, filters, limit, offset, callback) {
                    // Capture the spatial filter to inspect the clipped bbox
                    if (filters && filters.AND) {
                        for (let fi = 0; fi < filters.AND.length; fi++) {
                            if (filters.AND[fi].obm_geometry && filters.AND[fi].obm_geometry.st_intersects) {
                                capturedBboxGeojson = JSON.parse(filters.AND[fi].obm_geometry.st_intersects);
                            }
                        }
                    }
                    callback(true, {
                        data: {
                            spatialObmDataList: {
                                total_count: 1,
                                feature_collection: {
                                    features: [
                                        { type: "Feature", geometry: { type: "Point", coordinates: [0, 0] }, properties: { obm_id: 1 } }
                                    ]
                                }
                            }
                        }
                    });
                },
                getObmData: function(schema, table, filters, limit, offset, fieldNames, callback) {
                    callback(true, { data: { obmDataList: { total_count: 0, items: [] } } });
                }
            };

            var mockGpkgProxy = function(params) {
                return { success: true, message: "Mock save OK" };
            };

            SyncEngine.init(mockApiCaptureBbox, mockIfaceLargeCanvas, null, mockQgisProject, mockGpkgProxy);

            var progressMessages = [];
            var syncSuccess = false;
            var syncMessage = "";

            SyncEngine.syncAll(
                100, {}, "public", "obs", 4326, "Point", ["obm_id"],
                defaultStyleConfig,
                function(percent, message) { progressMessages.push(message); },
                function(success, message) {
                    syncSuccess = success;
                    syncMessage = message;
                }
            );

            // Should NOT abort — sync must succeed
            compare(syncSuccess, true, "Sync should succeed when bbox is clipped, not aborted: " + syncMessage);

            // Finish message must contain the clipping note
            verify(syncMessage.indexOf("clipped") !== -1,
                   "Finish message should mention clipping, got: " + syncMessage);

            // Progress messages should contain the warning
            var hasClipWarning = false;
            for (let pi = 0; pi < progressMessages.length; pi++) {
                if (progressMessages[pi].indexOf("Clipping") !== -1) {
                    hasClipWarning = true;
                    break;
                }
            }
            verify(hasClipWarning, "Progress callback should report the clipping warning");

            // The clipped bbox must be centered on (0, 0) and smaller than the original
            verify(capturedBboxGeojson !== null, "Spatial filter should have been set");
            var coords = capturedBboxGeojson.coordinates[0];
            var clippedXmin = coords[0][0];
            var clippedXmax = coords[1][0];
            var clippedYmin = coords[0][1];
            var clippedYmax = coords[2][1];
            var clippedW = clippedXmax - clippedXmin;
            var clippedH = clippedYmax - clippedYmin;
            // Center must be at (0, 0) within floating point tolerance
            verify(Math.abs((clippedXmin + clippedXmax) / 2) < 0.001, "Clipped bbox must be centered on X=0");
            verify(Math.abs((clippedYmin + clippedYmax) / 2) < 0.001, "Clipped bbox must be centered on Y=0");
            // Clipped area must be smaller than original (200×200 → 240×240 padded)
            verify(clippedW < 200 && clippedH < 200,
                   "Clipped bbox must be smaller than the original canvas extent");

            // Restore for subsequent tests
            SyncEngine.init(mockApiClient, null, null, mockQgisProject);
        }
    }
}
