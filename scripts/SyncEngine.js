.pragma library

var _apiClient = null;
var iface = null;
var _bboxTransformProxy = null;
var _qgisProject = null;
var _gpkgProxy = null;

/**
 * Initialize the SyncEngine with the ApiClient and QGIS project context.
 * @param {Object} apiClient - The initialized ApiClient module
 * @param {Object} ifaceObj - QField interface wrapper exposing mapCanvas
 * @param {function} bboxTransformProxy - Proxy to perform CRS transformations in main QML scope
 * @param {Object} qgisProjectObj - The QGIS project instance (qgisProject from QML context)
 * @param {function} gpkgProxy - Proxy to perform all GPKG I/O and layer loading in main QML scope
 */
function init(apiClient, ifaceObj, bboxTransformProxy, qgisProjectObj, gpkgProxy) {
    _apiClient = apiClient;
    iface = ifaceObj;
    _bboxTransformProxy = bboxTransformProxy;
    _qgisProject = qgisProjectObj || null;
    _gpkgProxy = gpkgProxy || null;
}

/**
 * Trigger a full sync for spatial or attribute data.
 * @param {number} maxBboxArea - maximum allowed area in square km (0 = unlimited)
 * @param {object} userFilterObject - customized GraphQL filters
 * @param {string} schema - Data table schema
 * @param {string} targetTable - Data table name
 * @param {number} targetSrid - Target DB Layer SRID for bounding box conversion
 * @param {string} geomType - Geometry type ("Point", "Line", "Polygon", or "Attributes")
 * @param {Array} fieldNames - Array of field names for the selection set (Attributes only)
 * @param {Object} styleConfig - Style settings from UI ({ color, sizeOrThickness, styleType })
 * @param {function} progressCallback - callback(percent: int, message: string)
 * @param {function} finishCallback - callback(success: boolean, message: string)
 */
function syncAll(maxBboxArea, userFilterObject, schema, targetTable, targetSrid, geomType, fieldNames, styleConfig, progressCallback, finishCallback) {
    if (!_apiClient) {
        finishCallback(false, "API Client not initialized");
        return;
    }

    var label = (geomType === "Attributes") ? "attribute data" : "spatial data";
    progressCallback(10, "Fetching " + label + "...");

    try {
        _syncData(maxBboxArea, userFilterObject, schema, targetTable, targetSrid, geomType, fieldNames, styleConfig, progressCallback, function(syncSuccess, syncMessage) {
            if (syncSuccess) {
                progressCallback(100, "Sync complete!");
                finishCallback(true, syncMessage);
            } else {
                if (syncMessage && syncMessage.indexOf("WARNING:") === 0) {
                    finishCallback(false, syncMessage);
                } else {
                    finishCallback(false, "Failed to sync " + label + ": " + syncMessage);
                }
            }
        });
    } catch (e) {
        if (iface) iface.logMessage("QField4OBM unhandled error in _syncData: " + e, "QField4OBM", 1);
        finishCallback(false, "Internal Error: " + e.toString());
    }
}

/**
 * Resolve the GPKG file path for a given table and geometry type.
 * @param {string} targetTable
 * @param {string} geomType
 * @returns {string|null}
 */
function _resolveGpkgPath(targetTable, geomType) {
    if (!_qgisProject) return null;
    try {
        var homePath = typeof _qgisProject.homePath === "function"
            ? _qgisProject.homePath()
            : _qgisProject.homePath;
        if (!homePath) return null;
        return homePath + "/" + targetTable + "_" + geomType + ".gpkg";
    } catch (e) {
        if (iface) iface.logMessage("QField4OBM: Could not resolve GPKG path: " + e.toString(), "QField4OBM", 1);
        return null;
    }
}

/**
 * Query the GPKG proxy for the maximum obm_id already stored locally.
 * Delegates to _gpkgProxy so the query runs in the full QML type scope.
 * @param {string} gpkgPath - Absolute path to the GPKG file
 * @param {string} layerName - Layer name inside the GPKG
 * @returns {number} Maximum obm_id found, or 0 if none / proxy unavailable
 */
function _getMaxOmbIdViaProxy(gpkgPath, layerName) {
    if (!_gpkgProxy) return 0;
    try {
        var result = _gpkgProxy({
            action: "getMaxOmbId",
            gpkgPath: gpkgPath,
            layerName: layerName
        });
        return (result && result.maxOmbId > 0) ? result.maxOmbId : 0;
    } catch (e) {
        if (iface) iface.logMessage("QField4OBM: getMaxOmbId proxy call failed: " + e.toString(), "QField4OBM", 1);
        return 0;
    }
}

function _syncData(maxBboxArea, userFilterObject, schema, targetTable, targetSrid, geomType, fieldNames, styleConfig, progressCallback, finishCallback) {
    var isAttributesOnly = (geomType === "Attributes");
    var geojsonStr = null;

    if (!isAttributesOnly) {
        if (!iface || typeof iface.mapCanvas !== "function" || !iface.mapCanvas()) {
            finishCallback(false, "Cannot calculate extent: QGIS map canvas not available.");
            return;
        }

        // 1. Extent Math & GeoJSON (only for spatial layers)
        var canvas = iface.mapCanvas();
        var extent = null;

        if (canvas.mapSettings && canvas.mapSettings.extent) {
            extent = canvas.mapSettings.extent;
        } else if (canvas.extent && typeof canvas.extent === "function") {
            extent = canvas.extent();
        } else if (canvas.extent) {
            extent = canvas.extent;
        } else if (canvas.visibleExtent && typeof canvas.visibleExtent === "function") {
            extent = canvas.visibleExtent();
        } else if (canvas.visibleExtent) {
            extent = canvas.visibleExtent;
        }

        if (!extent) {
            finishCallback(false, "Could not extract active extent from map canvas.");
            return;
        }

        var w = typeof extent.width === "function" ? extent.width() : extent.width;
        var h = typeof extent.height === "function" ? extent.height() : extent.height;

        var extXmin = typeof extent.xMinimum === "function" ? extent.xMinimum() : (extent.xMin !== undefined ? extent.xMin : extent.xMinimum);
        var extXmax = typeof extent.xMaximum === "function" ? extent.xMaximum() : (extent.xMax !== undefined ? extent.xMax : extent.xMaximum);
        var extYmin = typeof extent.yMinimum === "function" ? extent.yMinimum() : (extent.yMin !== undefined ? extent.yMin : extent.yMinimum);
        var extYmax = typeof extent.yMaximum === "function" ? extent.yMaximum() : (extent.yMax !== undefined ? extent.yMax : extent.yMaximum);

        var dx = w * 0.10;
        var dy = h * 0.10;

        var xmin = extXmin - dx;
        var xmax = extXmax + dx;
        var ymin = extYmin - dy;
        var ymax = extYmax + dy;

        var fallbackSrid = "3857";
        try {
            var ccrs = null;
            if (canvas.mapSettings && typeof canvas.mapSettings.destinationCrs === "function") {
                ccrs = canvas.mapSettings().destinationCrs();
            } else if (canvas.mapSettings && canvas.mapSettings.destinationCrs) {
                ccrs = canvas.mapSettings.destinationCrs;
            } else if (canvas.destinationCrs) {
                ccrs = canvas.destinationCrs;
            }
            if (ccrs && typeof ccrs.authid === "function") {
                fallbackSrid = ccrs.authid().replace("EPSG:", "");
            } else if (ccrs && ccrs.authid) {
                fallbackSrid = ccrs.authid.replace("EPSG:", "");
            }
        } catch(e) { if (iface) iface.logMessage("QField4OBM: Canvas CRS fetch error: " + e.toString(), "QField4OBM", 1); }

        geojsonStr = JSON.stringify({
            type: "Polygon",
            crs: { type: "name", properties: { name: "EPSG:" + fallbackSrid } },
            coordinates: [[
                [xmin, ymin],
                [xmax, ymin],
                [xmax, ymax],
                [xmin, ymax],
                [xmin, ymin]
            ]]
        });

        // 2. Accurate Area Validation
        var areaSqKm = 0;
        try {
            if (typeof QgsDistanceArea !== 'undefined') {
                var da = new QgsDistanceArea();
                var destCrs = null;
                if (canvas.mapSettings && canvas.mapSettings.destinationCrs) {
                    destCrs = canvas.mapSettings.destinationCrs;
                } else if (canvas.mapSettings && typeof canvas.mapSettings.destinationCrs === "function") {
                    destCrs = canvas.mapSettings().destinationCrs();
                } else if (canvas.destinationCrs) {
                    destCrs = canvas.destinationCrs;
                }

                if (destCrs) {
                    da.setSourceCrs(destCrs, typeof qgisProject !== 'undefined' ? qgisProject.transformContext() : null);
                    // Dynamically extract the ellipsoid from the project's destination CRS
                    // instead of hardcoding a specific ellipsoid identifier.
                    // Falls back to WGS84 ellipsoid (EPSG:7030) if extraction fails.
                    var ellipsoid = null;
                    if (typeof destCrs.ellipsoidAcronym === "function") {
                        ellipsoid = destCrs.ellipsoidAcronym();
                    } else if (destCrs.ellipsoidAcronym) {
                        ellipsoid = destCrs.ellipsoidAcronym;
                    }
                    if (ellipsoid && ellipsoid.length > 0) {
                        da.setEllipsoid(ellipsoid);
                    } else {
                        da.setEllipsoid("EPSG:7030"); // WGS84 ellipsoid fallback
                    }
                }

                if (typeof QgsRectangle !== 'undefined' && typeof QgsGeometry !== 'undefined') {
                    var rect = new QgsRectangle(xmin, ymin, xmax, ymax);
                    var geom = QgsGeometry.fromRect(rect);
                    var areaSqMeters = da.measureArea(geom);
                    areaSqKm = areaSqMeters / 1000000.0;
                }
            }
        } catch (e) {
            if (iface) iface.logMessage("SyncEngine: Could not precisely calculate area using QgsDistanceArea: " + e.toString(), "QField4OBM", 1);
        }
        // If QgsDistanceArea / QgsRectangle / QgsGeometry were unavailable or threw,
        // areaSqKm is still 0. Estimate from coordinates so the bbox limit is still enforced.
        if (areaSqKm <= 0) {
            var fbSridNum = parseInt(fallbackSrid);
            if (fbSridNum === 4326) {
                // Geographic CRS: approximate km² using central-latitude cosine correction
                var centerLat = (ymin + ymax) / 2;
                var cosLat = Math.cos(centerLat * Math.PI / 180);
                areaSqKm = Math.abs((xmax - xmin) * 111.32 * cosLat) * Math.abs((ymax - ymin) * 111.32);
            } else {
                // Projected CRS: assume units are metres
                areaSqKm = Math.abs((xmax - xmin) * (ymax - ymin)) / 1000000.0;
            }
            if (iface) iface.logMessage("SyncEngine: Area estimated from coordinates (" + areaSqKm.toFixed(2) + " km², SRID " + fallbackSrid + ")", "QField4OBM", 0);
        }

        var bboxClippedWarning = null;
        if (maxBboxArea > 0 && areaSqKm > maxBboxArea) {
            // Clip to a centered rectangle with the same aspect ratio, scaled to maxBboxArea.
            var centerX = (xmin + xmax) / 2;
            var centerY = (ymin + ymax) / 2;
            var scaleFactor = Math.sqrt(maxBboxArea / areaSqKm);
            var halfW = (xmax - xmin) / 2 * scaleFactor;
            var halfH = (ymax - ymin) / 2 * scaleFactor;
            xmin = centerX - halfW;
            xmax = centerX + halfW;
            ymin = centerY - halfH;
            ymax = centerY + halfH;
            bboxClippedWarning = "Note: Canvas is too large (" + areaSqKm.toFixed(2) + " km²). Download was clipped to the center " + maxBboxArea + " km² of the map canvas.";
            progressCallback(10, "Warning: Canvas too large. Clipping download area to center " + maxBboxArea + " km²...");
            // Rebuild geojsonStr with the clipped coordinates
            geojsonStr = JSON.stringify({
                type: "Polygon",
                crs: { type: "name", properties: { name: "EPSG:" + fallbackSrid } },
                coordinates: [[
                    [xmin, ymin],
                    [xmax, ymin],
                    [xmax, ymax],
                    [xmin, ymax],
                    [xmin, ymin]
                ]]
            });
        }

        // 3. CRS Transformation for GraphQL BBOX
        var targetSridNum = parseInt(targetSrid);
        if (!isNaN(targetSridNum) && targetSridNum > 0) {
            var srcAuth = "EPSG:" + fallbackSrid;
            var targetSridAuth = "EPSG:" + targetSridNum;

            if (srcAuth !== targetSridAuth) {
                try {
                    if (_bboxTransformProxy) {
                        var trgProxyObj = _bboxTransformProxy(iface, xmin, ymin, xmax, ymax, srcAuth, targetSridNum);
                        if (trgProxyObj) {
                            geojsonStr = JSON.stringify({
                                type: "Polygon",
                                crs: { type: "name", properties: { name: "EPSG:" + targetSridNum } },
                                coordinates: [[
                                    [trgProxyObj.xmin, trgProxyObj.ymin],
                                    [trgProxyObj.xmax, trgProxyObj.ymin],
                                    [trgProxyObj.xmax, trgProxyObj.ymax],
                                    [trgProxyObj.xmin, trgProxyObj.ymax],
                                    [trgProxyObj.xmin, trgProxyObj.ymin]
                                ]]
                            });
                        }
                    }
                } catch (e) {
                    if (iface) iface.logMessage("QField4OBM: BBOX transformation failed: " + e.toString(), "QField4OBM", 1);
                }
            }
        }
    }

    // 4. Effective filter setup (obm_id-based delta-sync removed —
    //    deduplication is handled client-side in the APPEND path)
    var effectiveFilter = userFilterObject ? JSON.parse(JSON.stringify(userFilterObject)) : {};
    if (!effectiveFilter.AND) effectiveFilter.AND = [];

    // 5. GraphQL Filter Merging
    var mergedFilter = { AND: [] };
    if (geojsonStr) {
        mergedFilter.AND.push({
            "obm_geometry": { "st_intersects": geojsonStr }
        });
    }

    if (!isAttributesOnly && geomType) {
        if (geomType === "Point") {
            mergedFilter.AND.push({ "obm_geometry": { "geometry_type_in": ["POINT", "MULTIPOINT"] } });
        } else if (geomType === "Line") {
            mergedFilter.AND.push({ "obm_geometry": { "geometry_type_in": ["LINESTRING", "MULTILINESTRING"] } });
        } else if (geomType === "Polygon") {
            mergedFilter.AND.push({ "obm_geometry": { "geometry_type_in": ["POLYGON", "MULTIPOLYGON"] } });
        }
    }

    if (effectiveFilter && Object.keys(effectiveFilter).length > 0) {
        var safeFilterObj = effectiveFilter;
        if (safeFilterObj.AND && Array.isArray(safeFilterObj.AND)) {
            safeFilterObj.AND = safeFilterObj.AND.filter(function(cond) {
                return !cond.hasOwnProperty('obm_geometry');
            });
            if (safeFilterObj.AND.length > 0) {
                mergedFilter.AND = mergedFilter.AND.concat(safeFilterObj.AND);
            }
        } else {
            if (!safeFilterObj.hasOwnProperty('obm_geometry')) {
                if (Object.keys(safeFilterObj).length > 0) {
                    mergedFilter.AND.push(safeFilterObj);
                }
            }
        }
    }

    if (mergedFilter.AND.length === 0) {
        mergedFilter = null;
    }

    // 6. API Call with pagination
    var limit = 500;
    var offset = 0;
    var accumulatedFeatures = [];
    var totalCount = -1;
    var startTime = Date.now();
    var totalBytesDownloaded = 0;

    function fetchNextBatch() {
        var apiCallback = function(success, response) {
            if (response && typeof response === "string") {
                totalBytesDownloaded += response.length;
            } else if (response) {
                totalBytesDownloaded += JSON.stringify(response).length;
            }

            if (!success) {
                finishCallback(false, "API Error: " + response);
                return;
            }

            try {
                if (response.errors) {
                    finishCallback(false, "GraphQL Error: " + JSON.stringify(response.errors));
                    return;
                }

                if (!response.data) {
                    finishCallback(false, "Invalid API response format (missing 'data'): " + JSON.stringify(response));
                    return;
                }

                var batchData = isAttributesOnly ? response.data.obmDataList : response.data.spatialObmDataList;
                if (!batchData) {
                    finishCallback(false, "Missing data in response.data");
                    return;
                }

                if (totalCount === -1) {
                    totalCount = batchData.total_count;
                }

                var features = [];
                if (isAttributesOnly) {
                    // Normalize attribute items to GeoJSON-like Feature objects
                    var items = batchData.items;
                    if (items && items.length > 0) {
                        features = items.map(function(item) {
                            return {
                                type: "Feature",
                                geometry: null,
                                properties: item
                            };
                        });
                    }
                } else {
                    var rawFeatures = batchData.feature_collection.features;
                    if (rawFeatures && rawFeatures.length > 0) {
                        for (var i = 0; i < rawFeatures.length; i++) {
                            var f = rawFeatures[i];
                            if (f && f.geometry && f.geometry.type) {
                                var gType = f.geometry.type;
                                if (geomType === "Point" && (gType === "Point" || gType === "MultiPoint")) {
                                    features.push(f);
                                } else if (geomType === "Line" && (gType === "LineString" || gType === "MultiLineString")) {
                                    features.push(f);
                                } else if (geomType === "Polygon" && (gType === "Polygon" || gType === "MultiPolygon")) {
                                    features.push(f);
                                }
                            }
                        }
                    }
                }

                if (features && features.length > 0) {
                    accumulatedFeatures = accumulatedFeatures.concat(features);
                }

                offset += limit;

                if (totalCount > 0) {
                    var percent = 30 + Math.floor((Math.min(offset, totalCount) / totalCount) * 60);
                    progressCallback(percent, "Downloaded " + accumulatedFeatures.length + " / " + totalCount + (isAttributesOnly ? " records" : " features"));
                } else {
                    progressCallback(90, "No data found.");
                }

                if (offset < totalCount) {
                    fetchNextBatch();
                } else {
                    _saveToLocalFile(accumulatedFeatures, targetTable, geomType, styleConfig, startTime, totalBytesDownloaded,
                        bboxClippedWarning
                            ? function(success, msg) { finishCallback(success, bboxClippedWarning + "\n\n" + msg); }
                            : finishCallback
                    );
                }
            } catch (e) {
                finishCallback(false, "Error parsing data: " + e.toString());
            }
        };

        if (isAttributesOnly) {
            _apiClient.getObmData(schema, targetTable, mergedFilter, limit, offset, fieldNames, apiCallback);
        } else {
            _apiClient.getSpatialData(schema, targetTable, "obm_geometry", mergedFilter, limit, offset, apiCallback);
        }
    }

    fetchNextBatch();
}

/**
 * Handle bulk saving of features to a local GeoPackage (GPKG).
 * Delegates all QGIS API calls (file writing, layer loading, styling) to _gpkgProxy
 * since QGIS C++ constructors are ONLY accessible from the main QML component scope,
 * not from inside a .pragma library JavaScript file.
 *
 * @param {Array} featuresArray - GeoJSON features downloaded from the API (new records only)
 * @param {string} targetTable - Data table name (used as the GPKG layer name and part of filename)
 * @param {string} geomType - "Point" | "Line" | "Polygon" | "Attributes"
 * @param {Object} styleConfig - Style settings from UI ({ color, sizeOrThickness, styleType })
 * @param {number} startTime - JS timestamp when sync started
 * @param {number} totalBytesDownloaded - Combined byte size of all downloaded API payloads
 * @param {function} finishCallback - callback(success: boolean, message: string)
 */
function _saveToLocalFile(featuresArray, targetTable, geomType, styleConfig, startTime, totalBytesDownloaded, finishCallback) {
    var endTime = Date.now();
    var durationSec = ((endTime - startTime) / 1000).toFixed(1);
    var scaleFactor = totalBytesDownloaded > 1024 * 1024 ? (1024 * 1024) : 1024;
    var sizeUnit = totalBytesDownloaded > 1024 * 1024 ? "MB" : "KB";
    var sizeLabel = (totalBytesDownloaded / scaleFactor).toFixed(2);

    if (!featuresArray || featuresArray.length === 0) {
        finishCallback(true,
            "No new features to save.\n\n" +
            "• Data size: " + sizeLabel + " " + sizeUnit + "\n" +
            "• Download time: " + durationSec + " seconds"
        );
        return;
    }

    // _resolveGpkgPath returns the canonical .gpkg path;
    // the proxy writes a physical GPKG file on first sync.
    var localFilePath = _resolveGpkgPath(targetTable, geomType);
    if (!localFilePath) {
        if (iface) iface.logMessage("QField4OBM: Cannot determine local file path — qgisProject home path unavailable.", "QField4OBM", 1);
        finishCallback(false,
            "Cannot save features: project home path not available.\n\n" +
            "• Features downloaded: " + featuresArray.length + "\n" +
            "• Download time: " + durationSec + " seconds"
        );
        return;
    }

    if (!_gpkgProxy) {
        if (iface) iface.logMessage("QField4OBM: No GPKG proxy registered — cannot write layer.", "QField4OBM", 1);
        finishCallback(false,
            "Cannot save features: GPKG proxy not initialized.\n\n" +
            "• Features downloaded: " + featuresArray.length + "\n" +
            "• Download time: " + durationSec + " seconds"
        );
        return;
    }

    // Build a GeoJSON FeatureCollection string to pass to the proxy.
    // The proxy handles writing to disk and adding the layer to the project.
    var featureCollection = {
        type: "FeatureCollection",
        features: featuresArray
    };

    if (iface) iface.logMessage("QField4OBM: Calling proxy to save " + featuresArray.length + " features → " + localFilePath, "QField4OBM", 0);

    try {
        var result = _gpkgProxy({
            action: "saveFeatures",
            gpkgPath: localFilePath,
            layerName: targetTable + "_" + geomType,
            geomType: geomType,
            featureCollectionJson: JSON.stringify(featureCollection),
            styleConfig: styleConfig
        });

        var savedOk = result && result.success;
        var proxyMsg = (result && result.message) ? result.message : "";

        // proxyMsg contains the actual written path (e.g. .geojson or .gpkg)
        var displayPath = proxyMsg || localFilePath;
        var msg = savedOk
            ? "Downloaded " + featuresArray.length + " features & added to map.\n\n" +
              "• " + displayPath + "\n" +
              "• Data size: " + sizeLabel + " " + sizeUnit + "\n" +
              "• Download time: " + durationSec + " seconds"
            : "Download complete (save error: " + proxyMsg + ").\n\n" +
              "• Features downloaded: " + featuresArray.length + "\n" +
              "• Data size: " + sizeLabel + " " + sizeUnit + "\n" +
              "• Download time: " + durationSec + " seconds";

        finishCallback(savedOk, msg);
    } catch (e) {
        if (iface) iface.logMessage("QField4OBM: Exception calling GPKG proxy: " + e.toString(), "QField4OBM", 1);
        finishCallback(false, "GPKG proxy exception: " + e.toString());
    }
}
