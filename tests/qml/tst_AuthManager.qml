import QtQuick 2.12
import QtTest 1.12

import "../../scripts/AuthManager.js" as AuthManager

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
        name: "AuthManagerTests"
        when: window.visible

        function initTestCase() {
            // Clear settings before starting tests
            mockSettings.obmAccessToken = "";
            mockSettings.obmRefreshToken = "";
            mockSettings.obmBaseUrl = "";
            mockSettings.projectTable = "";
            mockSettings.projectName = "";
            AuthManager.init(mockSettings, null, null, null, null);
        }

        function test_initialState() {
            compare(AuthManager.isLoggedIn(), false, "Should not be logged in initially");
            compare(AuthManager.getToken(), "", "Token should be empty");
        }

        function test_setAndGetToken() {
            var testToken = "test-bearer-token-123";
            AuthManager.setToken(testToken);
            var retrievedToken = AuthManager.getToken();
            compare(retrievedToken, testToken, "Retrieved token should match set token");
            compare(AuthManager.isLoggedIn(), true, "Should be logged in after setting token");
            compare(mockSettings.obmAccessToken, testToken, "Token should be persisted in Settings");

            var testRefreshToken = "test_refresh_token_789";
            AuthManager.setRefreshToken(testRefreshToken);
            var retrievedRefreshToken = AuthManager.getRefreshToken();
            compare(retrievedRefreshToken, testRefreshToken, "Retrieved refresh token should match");
            compare(mockSettings.obmRefreshToken, testRefreshToken, "Refresh token should be persisted");
        }

        function test_logout() {
            AuthManager.setToken("old_token");
            AuthManager.setRefreshToken("old_refresh");
            verify(AuthManager.isLoggedIn(), "Should be logged in before logout");

            AuthManager.logout();

            verify(!AuthManager.isLoggedIn(), "Should not be logged in after logout");
            compare(AuthManager.getToken(), "", "Token should be cleared");
            compare(AuthManager.getRefreshToken(), "", "Refresh token should be cleared");
            compare(mockSettings.obmAccessToken, "", "Persisted token should be cleared");
            compare(mockSettings.obmRefreshToken, "", "Persisted refresh token should be cleared");
        }

        function test_baseUrlManagement() {
            var testUrl = "https://example.openbiomaps.org";
            AuthManager.setBaseUrl(testUrl);
            compare(AuthManager.getBaseUrl(), testUrl, "Base URL should match what was set");
            compare(mockSettings.obmBaseUrl, testUrl, "Base URL should be persisted in Settings");
        }

        function test_projectManagement() {
            var testProject = "sablon_project";
            AuthManager.setSelectedProject(testProject);
            compare(AuthManager.getSelectedProject(), testProject, "Selected project should match what was set");
            compare(mockSettings.projectTable, testProject, "Selected project should be persisted in Settings");
        }

        function test_loginWithoutBaseUrl() {
            AuthManager.setBaseUrl("");
            var callbackCalled = false;
            AuthManager.login("user", "pass", "project", "projectName", function(success, message) {
                callbackCalled = true;
                compare(success, false, "Login should fail without base URL");
            });
            verify(callbackCalled, "Callback should have been called synchronously");
        }

        function test_loginWithoutProject() {
            AuthManager.setBaseUrl("https://example.com");
            var callbackCalled = false;
            AuthManager.login("user", "pass", "", "", function(success, message) {
                callbackCalled = true;
                compare(success, false, "Login should fail without a selected project");
            });
            verify(callbackCalled, "Callback should have been called synchronously");
        }
    }
}
