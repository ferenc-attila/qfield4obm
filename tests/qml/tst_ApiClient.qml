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
        property string obmAccessToken: ""
        property string obmRefreshToken: ""
        property string obmBaseUrl: ""
        property string projectTable: ""
        property string projectName: ""
        property bool isLoggedIn: false
    }

    TestCase {
        name: "ApiClientTests"
        when: window.visible

        function initTestCase() {
            // Clear settings before starting tests
            mockSettings.obmAccessToken = "";
            mockSettings.obmRefreshToken = "";
            mockSettings.obmBaseUrl = "";
            mockSettings.projectTable = "";
            mockSettings.projectName = "";
            AuthManager.init(mockSettings, null, null, null, null);
            ApiClient.init(AuthManager);
        }

        function test_getFormsWithoutAuth() {
            // Ensure not authenticated
            AuthManager.logout();
            var callbackCalled = false;

            ApiClient.getForms(function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should fail if not logged in");
                verify(response.indexOf("not logged in") !== -1 || response.indexOf("Base URL") !== -1, "Response should complain about auth or config");
            });

            verify(callbackCalled, "Callback should be synchronous on pre-flight failure");
        }

        function test_getSpatialDataWithoutAuth() {
            AuthManager.logout();
            var callbackCalled = false;

            ApiClient.getSpatialData("public", "test_table", "obm_geometry", null, 100, 0, function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should fail if not logged in");
            });

            verify(callbackCalled, "Callback should be synchronous on pre-flight failure");
        }

        // Detailed mocking of XHR for successful queries would require a mock
        // XMLHttpRequest object in QML, which is complex.
        // The core logical paths of ApiClient validation are tested here.
        function test_authPreFlightValidation() {
            AuthManager.setToken("dummy-token");
            AuthManager.setBaseUrl("");
            AuthManager.setSelectedProject("test_project");

            var callbackCalled = false;
            ApiClient.getForms(function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should fail without baseUrl");
            });
            verify(callbackCalled, "Callback should be synchronous");

            AuthManager.setBaseUrl("url");
            AuthManager.setSelectedProject("");

            callbackCalled = false;
            ApiClient.getForms(function(success, response) {
                callbackCalled = true;
                compare(success, false, "Should fail without selectedProject");
            });
            verify(callbackCalled, "Callback should be synchronous");
        }
    }
}
