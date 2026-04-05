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
        name: "ApiClient_GetTableDetails"
        when: window.visible

        function initTestCase() {
            AuthManager.init(mockSettings, null, null, null, null);
            AuthManager.setBaseUrl("http://mock-url");
            AuthManager.setSelectedProject("test_project", "Test Project");
            AuthManager.setToken("dummy-token");
            ApiClient.init(AuthManager);
        }

        function test_getTableDetailsSuccess() {
            var originalSend = ApiClient._sendAuthenticatedRequest;
            var capturedMethod = "";
            var capturedUrl = "";

            ApiClient._sendAuthenticatedRequest = function(method, endpointUrl, payload, callback) {
                capturedMethod = method;
                capturedUrl = endpointUrl;
                callback(true, { fields: [{ column_name: "col1" }, { column_name: "col2" }] });
            };

            var callbackCalled = false;
            ApiClient.getTableDetails("test_schema", "test_table", function(success, response) {
                callbackCalled = true;
                compare(success, true, "Should return true on success");
                compare(response.fields.length, 2, "Should return 2 fields");
                compare(response.fields[0].column_name, "col1", "Should return col1");
            });

            verify(callbackCalled, "Callback should be called");
            compare(capturedMethod, "GET", "Should use GET method");
            compare(capturedUrl, "http://mock-url/projects/test_project/api/v3/data-tables/test_schema/test_table", "Should request correct URL");

            ApiClient._sendAuthenticatedRequest = originalSend;
        }

        function test_getTableDetailsFailure() {
            var originalSend = ApiClient._sendAuthenticatedRequest;

            ApiClient._sendAuthenticatedRequest = function(method, endpointUrl, payload, callback) {
                callback(false, "Table not found");
            };

            var callbackCalled = false;
            ApiClient.getTableDetails("test_schema", "test_table", function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should return false on failure");
                compare(response, "Table not found", "Should return error message");
            });

            verify(callbackCalled, "Callback should be called");

            ApiClient._sendAuthenticatedRequest = originalSend;
        }

        function test_getTableDetailsMissingParams() {
            var callbackCalled = false;
            ApiClient.getTableDetails("", "test_table", function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should return false with missing schema");
            });
            verify(callbackCalled, "Callback should be called");

            callbackCalled = false;
            ApiClient.getTableDetails("test_schema", "", function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should return false with missing table");
            });
            verify(callbackCalled, "Callback should be called");
        }
    }
}
