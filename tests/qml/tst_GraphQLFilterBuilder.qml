import QtQuick 2.12
import QtTest 1.12
import QtQuick.Controls 2.12

import "../../components" as Components
import "../../scripts/ApiClient.js" as ApiClient

Item {
    id: window
    width: 600
    height: 600

    Components.GraphQLFilterBuilder {
        id: filterBuilder
        anchors.fill: parent
    }

    TestCase {
        name: "GraphQLFilterBuilder"
        when: true

        function test_initialState() {
            var filter = filterBuilder.filterObject;
            compare(filter.AND, undefined, "Initial filterObject should not have AND");
        }

        function test_loadTablesAndFields() {
            var originalGetTableDetails = ApiClient.getTableDetails;
            var detailsCalled = false;

            ApiClient.getTableDetails = function(schema, table, callback) {
                detailsCalled = true;
                compare(schema, "public", "Should use public schema");
                compare(table, "users", "Should fetch selected table");
                callback(true, { fields: ["id", "username", "email"] });
            };

            var tables = ["users", "projects"];
            filterBuilder.loadTables(tables);

            verify(detailsCalled, "Should call getTableDetails automatically for the first table");

            var mainCol = filterBuilder.testMainColumn;

            var addBtn = filterBuilder.testAddButton;
            var errorLabel = filterBuilder.testErrorLabel;

            // Replaced manual lookup with the Repeater's itemAt implementation or direct access
            // Or since we only care if it's there:
            var repeater = filterBuilder.testRowsRepeater;
            var row1 = null;
            if (repeater && repeater.count > 0) {
                row1 = repeater.itemAt(0);
            }

            verify(addBtn !== null, "Should find + Add Filter button (objectName: addFilterButton)");
            verify(row1 !== null, "Should automatically create one filter row on successful table load (objectName: filterRow)");

            // Now click Add Filter to add a second row
            addBtn.clicked();

            // Wait for UI to process
            wait(50);

            // modify rows - simulate user action
            // QML ComboBox testing relies on UI interaction,
            // but we can also just test the filter object update directly if we can access the generated UI elements.
            // Since accessing internal QML models from a test is tricky without aliases, we are verifying the basic integrations here.

            ApiClient.getTableDetails = originalGetTableDetails;
        }

        function test_apiFailure() {
            var originalGetTableDetails = ApiClient.getTableDetails;

            ApiClient.getTableDetails = function(schema, table, callback) {
                callback(false, "Network error 404");
            };

            filterBuilder.loadTables(["bad_table"]);
            wait(50);

            var errorLabel = filterBuilder.testErrorLabel;

            verify(errorLabel !== null, "Should find error label");
            verify(errorLabel.visible, "Error label should be visible on failure");
            verify(errorLabel.text.indexOf("Network error") !== -1, "Error label should contain error message");

            ApiClient.getTableDetails = originalGetTableDetails;
        }
    }
}
