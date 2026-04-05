import QtQuick 2.12
import QtTest 1.12

import "../../scripts/AuthManager.js" as AuthManager
import "../../scripts/ApiClient.js" as ApiClient

Item {
    id: window
    width: 400
    height: 400

    QtObject {
        id: mockSettings
        property string obmAccessToken: "test-token"
        property string obmRefreshToken: "test-refresh"
        property string obmBaseUrl: "http://mock-url"
        property string projectTable: "test_project"
        property string projectName: "Test Project"
        property bool isLoggedIn: false
    }

    TestCase {
        name: "ApiClient_GetDataTables"
        when: window.visible

        function initTestCase() {
            AuthManager.init(mockSettings, null, null, null, null);
            AuthManager.setBaseUrl("http://mock-url");
            AuthManager.setSelectedProject("test_project", "Test Project");
            AuthManager.setToken("dummy-token");
            ApiClient.init(AuthManager);
        }

        function test_getDataTablesSuccess() {
            var originalSend = ApiClient._sendAuthenticatedRequest;
            var capturedMethod = "";
            var capturedUrl = "";

            ApiClient._sendAuthenticatedRequest = function(method, endpointUrl, payload, callback) {
                capturedMethod = method;
                capturedUrl = endpointUrl;
                callback(true, { data: [{ table_name: "table1" }, { table_name: "table2" }] });
            };

            var callbackCalled = false;
            ApiClient.getDataTables(function(success, response) {
                callbackCalled = true;
                compare(success, true, "Should return true on success");
                compare(response.data.length, 2, "Should return 2 tables");
                compare(response.data[0].table_name, "table1", "Should return table1");
            });

            verify(callbackCalled, "Callback should be called");
            compare(capturedMethod, "GET", "Should use GET method");
            compare(capturedUrl, "http://mock-url/projects/test_project/api/v3/data-tables", "Should request correct URL");

            ApiClient._sendAuthenticatedRequest = originalSend;
        }

        function test_getDataTablesFailure() {
            var originalSend = ApiClient._sendAuthenticatedRequest;

            ApiClient._sendAuthenticatedRequest = function(method, endpointUrl, payload, callback) {
                callback(false, "Network error");
            };

            var callbackCalled = false;
            ApiClient.getDataTables(function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should return false on failure");
                compare(response, "Network error", "Should return error message");
            });

            verify(callbackCalled, "Callback should be called");

            ApiClient._sendAuthenticatedRequest = originalSend;
        }
    }
}
