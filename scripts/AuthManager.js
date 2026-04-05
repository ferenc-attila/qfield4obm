.pragma library

var _settings = null;
var _baseUrl = "";
var _iface = null;
var _qgisProject = null;
var _qfieldSettings = null;
var _ExpressionContextUtils = null;

/**
 * Build the QSettings key path for a project variable.
 * Matches the path used by ProjectInfo::saveVariable() in C++:
 *   /qgis/projectInfo/{filePath}/variables/{name}
 */
function _settingsKey(key) {
    if (!_qgisProject) return null;
    var filePath = "";
    try { filePath = _qgisProject.fileName; } catch(e) {}
    if (!filePath) return null;
    return "/qgis/projectInfo/" + filePath + "/variables/" + key;
}

/**
 * Helper to safely get project variables.
 * On project load, ProjectInfo::restoreSettings() already reads QSettings
 * and injects them into qgisProject.customVariables via
 * ExpressionContextUtils::setProjectVariable(). So we read from there.
 */
function _getProjectVar(key) {
    try {
        // Primary: read from the project's expression context (already restored)
        if (_ExpressionContextUtils && _qgisProject) {
            var vars = _ExpressionContextUtils.projectVariables(_qgisProject);
            if (vars && vars[key] !== undefined && vars[key] !== "") {
                return vars[key];
            }
        }
        // Fallback: read directly from QSettings
        if (_qfieldSettings) {
            var settingsKeyPath = _settingsKey(key);
            if (settingsKeyPath) {
                var val = _qfieldSettings.value(settingsKeyPath, "");
                if (val && val !== "") return val;
            }
        }
    } catch(e) {
        if(_iface) _iface.logMessage("Could not get project variable " + key + ": " + e);
    }
    return null;
}

/**
 * Helper to safely set project variables.
 * Writes to QSettings using the same key path as ProjectInfo::saveVariable(),
 * and also applies it to the live expression context.
 */
function _setProjectVar(key, value) {
    var strValue = value ? value.toString() : "";
    try {
        // Permanently save to QSettings (same path as ProjectInfo::saveVariable)
        if (_qfieldSettings) {
            var settingsKeyPath = _settingsKey(key);
            if (settingsKeyPath) {
                _qfieldSettings.setValue(settingsKeyPath, strValue);
            }
        }

        // Also apply to the live expression context for the current session
        if (_ExpressionContextUtils && _qgisProject) {
            _ExpressionContextUtils.setProjectVariable(_qgisProject, key, strValue);
        }
    } catch(e) {
        if(_iface) _iface.logMessage("Could not set project variable " + key + ": " + e);
    }
}

/**
 * Initialize the AuthManager with persistence objects.
 * @param {QtObject} settingsObj - In-memory QtObject for reactive UI bindings
 * @param {Object} ifaceObj - QField iface object for logging
 * @param {Object} qgisProjectObj - The root context qgisProject (QgsProject)
 * @param {Object} qfieldSettingsObj - The root context settings (QSettings wrapper)
 * @param {Object} exprCtxUtilsObj - The ExpressionContextUtils singleton
 */
function init(settingsObj, ifaceObj, qgisProjectObj, qfieldSettingsObj, exprCtxUtilsObj) {
    _settings = settingsObj;
    _iface = ifaceObj;
    _qgisProject = qgisProjectObj || null;
    _qfieldSettings = qfieldSettingsObj || null;
    _ExpressionContextUtils = exprCtxUtilsObj || null;

    if (_iface) {
        _iface.logMessage("AuthManager.init: qgisProject=" + (_qgisProject ? "yes" : "no")
            + ", settings=" + (_qfieldSettings ? "yes" : "no")
            + ", ExprCtxUtils=" + (_ExpressionContextUtils ? "yes" : "no")
            + ", filePath=" + (_qgisProject ? _qgisProject.fileName : "N/A"));
    }

    // Try restoring session immediately (works if project is already loaded)
    restoreSession();
}

/**
 * Restore the saved session from project variables.
 * Called from init() and again when a project loads (fileNameChanged signal).
 * Always clears current state first, then restores from the new project.
 * If no project is loaded yet (fileName is empty), only clears state.
 */
function restoreSession() {
    // Always clear current in-memory state first.
    // This ensures switching projects properly resets the plugin.
    _baseUrl = "";
    if (_settings) {
        _settings.obmAccessToken = "";
        _settings.obmRefreshToken = "";
        _settings.obmBaseUrl = "";
        _settings.projectTable = "";
        _settings.projectName = "";
        _settings.isLoggedIn = false;
    }

    var filePath = "";
    try { filePath = _qgisProject ? _qgisProject.fileName : ""; } catch(e) {}

    if (!filePath) {
        if (_iface) _iface.logMessage("AuthManager.restoreSession: no project loaded, state cleared.");
        return;
    }

    if (_iface) _iface.logMessage("AuthManager.restoreSession: project=" + filePath);

    var savedUrl = _getProjectVar("obmBaseUrl");
    if (savedUrl && _settings) { _settings.obmBaseUrl = savedUrl; _baseUrl = savedUrl; }

    var savedToken = _getProjectVar("obmAccessToken");
    if (savedToken && _settings) _settings.obmAccessToken = savedToken;

    var savedRefresh = _getProjectVar("obmRefreshToken");
    if (savedRefresh && _settings) _settings.obmRefreshToken = savedRefresh;

    var savedProjectTable = _getProjectVar("projectTable");
    if (savedProjectTable && _settings) _settings.projectTable = savedProjectTable;

    var savedProjectName = _getProjectVar("projectName");
    if (savedProjectName && _settings) _settings.projectName = savedProjectName;

    // Update the isLoggedIn state
    if (_settings) {
        _settings.isLoggedIn = !!(savedToken && savedToken !== "");
    }

    if (_iface) {
        _iface.logMessage("AuthManager.restoreSession: token=" + (savedToken ? "yes" : "no")
            + ", refresh=" + (savedRefresh ? "yes" : "no")
            + ", url=" + (savedUrl || "none")
            + ", projectTable=" + (savedProjectTable || "none")
            + ", projectName=" + (savedProjectName || "none")
            + ", isLoggedIn=" + !!(savedToken && savedToken !== ""));
    }
}

/**
 * Set the base URL for the OBM server.
 * @param {string} url - The base URL of the OpenBioMaps server
 */
function setBaseUrl(url) {
    _baseUrl = url;
    if (_settings) {
        _settings.obmBaseUrl = url;
    }
    _setProjectVar("obmBaseUrl", url);
}

/**
 * Get the current base URL.
 * @returns {string} The base URL
 */
function getBaseUrl() {
    if (_baseUrl !== "") {
        return _baseUrl;
    }
    if (_settings && _settings.obmBaseUrl) {
        _baseUrl = _settings.obmBaseUrl;
        return _baseUrl;
    }
    return "";
}

/**
 * Retrieve the saved Bearer token.
 * @returns {string} The auth token
 */
function getToken() {
    if (_settings) {
        return _settings.obmAccessToken || "";
    }
    return "";
}

/**
 * Save the Bearer token.
 * @param {string} token - The auth token
 */
function setToken(token) {
    if (_settings) {
        _settings.obmAccessToken = token;
    }
    _setProjectVar("obmAccessToken", token);
}

/**
 * Retrieve the saved refresh token.
 * @returns {string} The refresh token
 */
function getRefreshToken() {
    if (_settings) {
        return _settings.obmRefreshToken || "";
    }
    return "";
}

/**
 * Save the refresh token.
 * @param {string} token - The refresh token
 */
function setRefreshToken(token) {
    if (_settings) {
        _settings.obmRefreshToken = token;
    }
    _setProjectVar("obmRefreshToken", token);
}

/**
 * Get the currently selected project table identifier.
 * @returns {string} The project table name used in API URLs
 */
function getSelectedProject() {
    if (_settings) {
        return _settings.projectTable || "";
    }
    return "";
}

/**
 * Get the human-readable project display name.
 * @returns {string} The project display name
 */
function getProjectName() {
    if (_settings) {
        return _settings.projectName || "";
    }
    return "";
}

/**
 * Save the user's selected project.
 * @param {string} projectTable - The project's table identifier (used in API URLs)
 * @param {string} projectName - The human-readable project display name
 */
function setSelectedProject(projectTable, projectName) {
    if (_settings) {
        _settings.projectTable = projectTable;
        _settings.projectName = projectName || projectTable;
    }
    _setProjectVar("projectTable", projectTable);
    _setProjectVar("projectName", projectName || projectTable);
}

/**
 * Clear the authentication state.
 */
function logout() {
    setToken("");
    setRefreshToken("");

    _setProjectVar("obmAccessToken", "");
    _setProjectVar("obmRefreshToken", "");
}

/**
 * Check if the user is currently logged in (has a token).
 * @returns {boolean} True if logged in
 */
function isLoggedIn() {
    var token = getToken();
    return token !== null && token !== "";
}

/**
 * Fetch available projects from the server's API.
 * @param {function} callback - callback(success: boolean, response: object|string)
 */
function fetchProjects(callback) {
    var url = getBaseUrl();
    if (!url) {
        callback(false, "Base URL is not set.");
        return;
    }

    var xhr = new XMLHttpRequest();
    // According to OpenBioMaps Project API, this endpoint returns the list of projects
    var endpoint = url + "/server-api/v3/projects";

    xhr.open("GET", endpoint, true);
    // Request minimal headers as expected.
    xhr.setRequestHeader("Accept", "application/json");

    // Attempt to get QField/Qt UI language, default to 'hu'
    var lang = "hu";
    if (typeof Qt !== "undefined" && Qt.uiLanguage) {
        // e.g., "en_US" -> "en"
        lang = String(Qt.uiLanguage).split("_")[0] || "hu";
    }

    if (_iface) {
        _iface.logMessage("QField4OBM: Detected UI language: " + lang + " (Raw Qt.uiLanguage: " + (typeof Qt !== 'undefined' ? Qt.uiLanguage : 'undefined') + ")");
    }

    xhr.setRequestHeader("Accept-Language", lang);

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var projectsArray = null;

                    if (Array.isArray(response)) {
                        projectsArray = response;
                    } else if (response.data && Array.isArray(response.data)) {
                        projectsArray = response.data;
                    }

                    if (projectsArray) {
                        // Sort projects alphabetically by 'name'
                        projectsArray.sort(function(a, b) {
                            var nameA = (a.name || "").toLowerCase();
                            var nameB = (b.name || "").toLowerCase();
                            if (nameA < nameB) return -1;
                            if (nameA > nameB) return 1;
                            return 0;
                        });
                        callback(true, { message: "Projects loaded", data: projectsArray });
                    } else {
                        callback(false, "Unexpected response format: " + xhr.responseText);
                    }
                } catch (e) {
                    callback(false, "Invalid JSON response: " + e.toString());
                }
            } else {
                callback(false, "HTTP Error " + xhr.status + ": " + xhr.responseText);
            }
        }
    };

    try {
        xhr.send();
    } catch (e) {
        callback(false, "Network error: " + e.toString());
    }
}

/**
 * Authenticate with the OBM server asynchronously using the pure OAuth POST flow.
 *
 * @param {string} username
 * @param {string} password
 * @param {string} projectTable - The project table identifier used in API URLs
 * @param {string} projectName - The human-readable project display name
 * @param {function} callback - callback(success: boolean, response: object|string)
 */
function login(username, password, projectTable, projectName, callback) {
    var url = getBaseUrl();
    if (!url) {
        callback(false, "Base URL is not set.");
        return;
    }
    if (!projectTable) {
        callback(false, "Project not selected.");
        return;
    }

    var xhr = new XMLHttpRequest();
    // Use the OBM OAuth endpoint for the specific project.
    var endpoint = url + "/oauth/token.php";
    if (_iface) {
        _iface.logMessage("QField4OBM Login URL: " + endpoint + " | projectTable: " + projectTable);
    }

    xhr.open("POST", endpoint, true);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    // OBM oauth returns the token in standard access_token field
                    if (response.access_token) {
                        setToken(response.access_token);
                        if (response.refresh_token) {
                            setRefreshToken(response.refresh_token);
                        }
                        setSelectedProject(projectTable, projectName);
                        callback(true, { message: "Login successful", token: response.access_token });
                    } else {
                        callback(false, "No token found in response.");
                    }
                } catch (e) {
                    var snippet = xhr.responseText ? xhr.responseText.substring(0, 150) : "empty response";
                    if (_iface) {
                        _iface.logMessage("QField4OBM: Login JSON parse error. Snippet: " + snippet);
                    }
                    callback(false, "Invalid JSON from server. Response snippet: " + snippet);
                }
            } else {
                callback(false, "HTTP Error " + xhr.status + ": " + xhr.responseText);
            }
        }
    };

    // The OBM PWA mobile flow requires grant_type, client_id=mobile, client_secret, and necessary scopes
    var payloadElements = [
        "grant_type=password",
        "client_id=mobile",
        "client_secret=123",
        "username=" + encodeURIComponent(username),
        "password=" + encodeURIComponent(password),
        "scope=" + encodeURIComponent("apiprofile get_tables get_data get_project_vars get_form_list get_form_data put_data tracklog")
    ];

    var payload = payloadElements.join("&");

    try {
        xhr.send(payload);
    } catch (e) {
        callback(false, "Network error: " + e.toString());
    }
}

/**
 * Refresh the authentication token using the saved refresh_token.
 *
 * @param {function} callback - callback(success: boolean, response: object|string)
 */
function refreshToken(callback) {
    var url = getBaseUrl();
    if (!url) {
        callback(false, "Base URL is not set.");
        return;
    }

    var currentRefreshToken = getRefreshToken();
    if (!currentRefreshToken) {
        callback(false, "No refresh token available.");
        return;
    }

    var xhr = new XMLHttpRequest();
    var endpoint = url + "/oauth/token.php";

    xhr.open("POST", endpoint, true);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    if (response.access_token) {
                        setToken(response.access_token);
                        if (response.refresh_token) {
                            setRefreshToken(response.refresh_token);
                        }
                        callback(true, { message: "Token refreshed successfully", token: response.access_token });
                    } else {
                        logout(); // Invalid properties in success response means our tokens are messed up
                        callback(false, "No access token found in refresh response.");
                    }
                } catch (e) {
                    callback(false, "Invalid JSON from refresh server.");
                }
            } else {
                // If refreshing fails (e.g. 400 Bad Request, 401 Unauthorized for refresh token), we log out
                if (xhr.status >= 400 && xhr.status < 500) {
                    if (_iface) {
                        _iface.logMessage("QField4OBM: Refresh token rejected (HTTP " + xhr.status + "). Forcing logout.");
                    }
                    logout();
                }
                callback(false, "HTTP Error " + xhr.status + " while refreshing token.");
            }
        }
    };

    var payloadElements = [
        "grant_type=refresh_token",
        "client_id=mobile",
        "client_secret=123",
        "refresh_token=" + encodeURIComponent(currentRefreshToken)
    ];

    var payload = payloadElements.join("&");

    try {
        xhr.send(payload);
    } catch (e) {
        callback(false, "Network error during token refresh: " + e.toString());
    }
}
