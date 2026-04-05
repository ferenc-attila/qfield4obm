.pragma library

var _authManager = null;
var _iface = null;

/**
 * Initialize the API Client with the AuthManager instance
 * @param {Object} authManager - The initialized AuthManager module
 */
function init(authManager, ifaceObj) {
    _authManager = authManager;
    if (typeof ifaceObj !== 'undefined') {
        _iface = ifaceObj;
    }
}

/**
 * Check if a failed response indicates an expired token that should trigger a refresh.
 * Handles both 401 Unauthorized and OBM's 403 Forbidden with reason "TOKEN_EXPIRED".
 * @param {number} httpStatus - HTTP status code
 * @param {string} responseText - Raw response body
 * @returns {boolean} True if a token refresh should be attempted
 */
function _shouldAttemptRefresh(httpStatus, responseText) {
    // Standard 401 Unauthorized
    if (httpStatus === 401) return true;

    // OBM-specific: 403 Forbidden with reason "TOKEN_EXPIRED"
    if (httpStatus === 403 && responseText) {
        try {
            var body = JSON.parse(responseText);
            if (body.reason === "TOKEN_EXPIRED") return true;
        } catch (e) {
            // Not JSON, ignore
        }
    }

    return false;
}
/**
 * Helper function to send authenticated XHR requests.
 * @param {string} method - HTTP Method (GET, POST, etc.)
 * @param {string} endpointUrl - Full URL to request
 * @param {object|null} payload - JSON body or null
 * @param {function} callback - callback(success: boolean, response: object|string)
 */
function _sendAuthenticatedRequest(method, endpointUrl, payload, callback) {
    if (!_authManager || !_authManager.isLoggedIn()) {
        callback(false, "User is not logged in or AuthManager not initialized.");
        return;
    }

    // Attempt to get QField/Qt UI language, default to 'hu'
    var lang = "hu";
    if (typeof Qt !== "undefined" && Qt.uiLanguage) {
        lang = String(Qt.uiLanguage).split("_")[0] || "hu";
    }

    function attemptRequest(isRetry) {
        var token = _authManager.getToken();
        var xhr = new XMLHttpRequest();

        xhr.open(method, endpointUrl, true);
        xhr.setRequestHeader("Authorization", token);
        xhr.setRequestHeader("Accept", "application/json");
        xhr.setRequestHeader("Accept-Language", lang);

        if (payload !== null) {
            xhr.setRequestHeader("Content-Type", "application/json");
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    var parsedResponse = null;
                    var parseError = null;
                    try {
                        parsedResponse = JSON.parse(xhr.responseText);
                    } catch (e) {
                        parseError = e;
                    }

                    if (parseError) {
                        var snippet = xhr.responseText ? xhr.responseText.substring(0, 150) : "empty response";
                        callback(false, "Invalid JSON in response: " + parseError.toString() + "\nRaw snippet: " + snippet);
                    } else {
                        callback(true, parsedResponse);
                    }
                } else if (!isRetry && _shouldAttemptRefresh(xhr.status, xhr.responseText)) {
                    // Token expired: either 401 Unauthorized or 403 with reason TOKEN_EXPIRED
                    if (typeof _iface !== "undefined" && _iface) _iface.logMessage("QField4OBM: Token expired (HTTP " + xhr.status + ") on " + endpointUrl + ", attempting refresh...", "QField4OBM", 1);
                    _authManager.refreshToken(function(success, response) {
                        if (success) {
                            if (typeof _iface !== "undefined" && _iface) _iface.logMessage("QField4OBM: Token refresh successful, retrying request...", "QField4OBM", 0);
                            attemptRequest(true); // Retry the request once
                        } else {
                            callback(false, "Session expired and token refresh failed: " + (response.message || response));
                        }
                    });
                } else {
                    callback(false, "HTTP Error " + xhr.status + ": " + xhr.responseText);
                }
            }
        };

        try {
            if (payload !== null) {
                xhr.send(JSON.stringify(payload));
            } else {
                xhr.send();
            }
        } catch (e) {
            callback(false, "Network error: " + e.toString());
        }
    }

    attemptRequest(false);
}

/**
 * Get available forms for the currently authenticated project.
 * @param {function} callback - callback(success, response)
 */
function getForms(callback) {
    var baseUrl = _authManager.getBaseUrl();
    var projectTable = _authManager.getSelectedProject();
    if (!baseUrl || !projectTable) {
        callback(false, "Base URL or Project not selected");
        return;
    }

    var endpoint = baseUrl + "/projects/" + projectTable + "/api/v3/forms";
    if (typeof _iface !== "undefined" && _iface) _iface.logMessage("QField4OBM: getForms URL -> " + endpoint, "QField4OBM", 0);
    _sendAuthenticatedRequest("GET", endpoint, null, callback);
}

/**
 * Get available projects for the currently authenticated user.
 * This endpoint provides the projects where the user has privileges.
 * @param {function} callback - callback(success, response)
 */
function getUserProjects(callback) {
    var baseUrl = _authManager.getBaseUrl();
    var projectTable = _authManager.getSelectedProject();
    if (!baseUrl || !projectTable) {
        callback(false, "Base URL or Project not selected");
        return;
    }

    var endpoint = baseUrl + "/projects/" + projectTable + "/api/v3/projects";
    if (typeof _iface !== "undefined" && _iface) _iface.logMessage("QField4OBM: getUserProjects URL -> " + endpoint, "QField4OBM", 0);
    _sendAuthenticatedRequest("GET", endpoint, null, callback);
}

/**
 * Fetch available data tables for the current project.
 * @param {function} callback - callback(success: boolean, response: object|array|string)
 */
function getDataTables(callback) {
    var baseUrl = _authManager.getBaseUrl();
    var projectTable = _authManager.getSelectedProject();
    if (!baseUrl || !projectTable) {
        callback(false, "Base URL or Project not selected");
        return;
    }
    var endpoint = baseUrl + "/projects/" + projectTable + "/api/v3/data-tables";
    if (typeof _iface !== "undefined" && _iface) _iface.logMessage("QField4OBM: getDataTables URL -> " + endpoint, "QField4OBM", 0);
    _sendAuthenticatedRequest("GET", endpoint, null, callback);
}

/**
 * Fetch schema details (fields) for a specific data table.
 * @param {string} schema - Database schema name (e.g., "public")
 * @param {string} dataTable - Table name to retrieve details for
 * @param {function} callback - callback(success: boolean, response: object|string)
 */
function getTableDetails(schema, dataTable, callback) {
    var baseUrl = _authManager.getBaseUrl();
    var projectTable = _authManager.getSelectedProject();
    if (!baseUrl || !projectTable) {
        callback(false, "Base URL or Project not selected");
        return;
    }
    if (!schema || !dataTable) {
        callback(false, "Schema and dataTable parameters are required");
        return;
    }
    var endpoint = baseUrl + "/projects/" + projectTable + "/api/v3/data-tables/" + schema + "/" + dataTable;
    if (typeof _iface !== "undefined" && _iface) _iface.logMessage("QField4OBM: getTableDetails URL -> " + endpoint, "QField4OBM", 0);
    _sendAuthenticatedRequest("GET", endpoint, null, callback);
}

/**
 * Execute a generic GraphQL Query to fetch spatialObmDataList.
 * @param {string} schema - Database schema name
 * @param {string} tableName - Data table name
 * @param {string} primaryGeometry - The primary geometry column (usually 'obm_geometry')
 * @param {object|null} filters - Optional ObmDataFilterInput formatting limit
 * @param {number} limit - Maximum number of features to fetch
 * @param {number} offset - Number of features to skip
 * @param {function} callback - callback(success, response)
 */
function getSpatialData(schema, tableName, primaryGeometry, filters, limit, offset, callback) {
    var baseUrl = _authManager.getBaseUrl();
    var projectTable = _authManager.getSelectedProject();
    if (!baseUrl || !projectTable) {
        callback(false, "Base URL or Project not selected");
        return;
    }

    // Explicitly target the /v3/get-data endpoint with POST method.
    var endpoint = baseUrl + "/projects/" + projectTable + "/api/v3/get-data";

    var hasFilters = (filters !== null && filters !== undefined && Object.keys(filters).length > 0);
    var queryParams = "$primaryGeometry: String!, $limit: Int, $offset: Int";
    var queryArgs = "primaryGeometry: $primaryGeometry, limit: $limit, offset: $offset";

    if (hasFilters) {
        queryParams += ", $filters: ObmDataFilterInput";
        queryArgs += ", filters: $filters";
    }

    var queryString = "query getSpatialObmData(" + queryParams + ") { \
        spatialObmDataList(" + queryArgs + ") { \
            total_count \
            feature_collection { \
                type \
                features { \
                    type \
                    geometry { type coordinates srid } \
                    properties \
                } \
            } \
        } \
    }";

    var variables = {
        primaryGeometry: primaryGeometry,
        limit: limit,
        offset: offset
    };

    // Inject merged spatial + custom UI filters into GraphQL variables
    if (filters) {
        variables.filters = filters;
    }

    // According to OBM API docs for getting data, query is embedded in body
    var payload = {
        schema: schema || "public",
        table_name: tableName || projectTable,
        query: queryString,
        variables: variables
    };

    // DEBUG: Log the final payload to help identify ghost filters like is_not_null
    if (typeof iface !== "undefined") {
        iface.logMessage("QField4OBM DEBUG Payload: " + JSON.stringify(payload));
    }

    // Sending via POST
    _sendAuthenticatedRequest("POST", endpoint, payload, callback);
}
/**
 * Execute a generic GraphQL Query to fetch obmDataList (non-spatial).
 * @param {string} schema - Database schema name
 * @param {string} tableName - Data table name
 * @param {object|null} filters - Optional ObmDataFilterInput formatting limit
 * @param {number} limit - Maximum number of features to fetch
 * @param {number} offset - Number of features to skip
 * @param {Array} fieldNames - Array of field names to include in the selection set
 * @param {function} callback - callback(success, response)
 */
function getObmData(schema, tableName, filters, limit, offset, fieldNames, callback) {
    var baseUrl = _authManager.getBaseUrl();
    var projectTable = _authManager.getSelectedProject();
    if (!baseUrl || !projectTable) {
        callback(false, "Base URL or Project not selected");
        return;
    }

    var endpoint = baseUrl + "/projects/" + projectTable + "/api/v3/get-data";

    var hasFilters = (filters !== null && filters !== undefined && Object.keys(filters).length > 0);
    var queryParams = "$limit: Int, $offset: Int";
    var queryArgs = "limit: $limit, offset: $offset";

    if (hasFilters) {
        queryParams += ", $filters: ObmDataFilterInput";
        queryArgs += ", filters: $filters";
    }

    // Default to a sensible set if none provided, though SyncEngine should pass them.
    var fieldsSelection = (fieldNames && fieldNames.length > 0) ? fieldNames.join(" ") : "obm_id";

    var queryString = "query getObmData(" + queryParams + ") { \
        obmDataList(" + queryArgs + ") { \
            total_count \
            items { " + fieldsSelection + " } \
        } \
    }";

    var variables = {
        limit: limit,
        offset: offset
    };

    if (filters) {
        variables.filters = filters;
    }

    var payload = {
        schema: schema || "public",
        table_name: tableName || projectTable,
        query: queryString,
        variables: variables
    };

    if (typeof iface !== "undefined") {
        iface.logMessage("QField4OBM DEBUG Attribute Payload: " + JSON.stringify(payload));
    }

    _sendAuthenticatedRequest("POST", endpoint, payload, callback);
}
