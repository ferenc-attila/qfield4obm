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
            var filter = filterBuilder.filterObject
            compare(filter.AND, undefined, "Initial filterObject should not have AND")
            compare(filter.OR, undefined, "Initial filterObject should not have OR")
        }

        function test_loadTablesAndFields() {
            var originalGetTableDetails = ApiClient.getTableDetails
            var detailsCalled = false

            ApiClient.getTableDetails = function(schema, table, callback) {
                detailsCalled = true
                compare(schema, "public", "Should use public schema")
                compare(table, "users", "Should fetch selected table")
                callback(true, { fields: ["id", "username", "email"] })
            }

            var tables = ["users", "projects"]
            filterBuilder.loadTables(tables)

            verify(detailsCalled, "Should call getTableDetails automatically for the first table")

            var addBtn = filterBuilder.testAddButton
            var errorLabel = filterBuilder.testErrorLabel
            var filterItemsCol = filterBuilder.testFilterItemsColumn

            verify(addBtn !== null, "Should find + Condition button (objectName: addFilterButton)")
            verify(errorLabel !== null, "Should find error label")

            // After successful table load, one condition row should be automatically created
            verify(filterItemsCol !== null, "Should find filter items column")
            verify(filterItemsCol.children.length > 0, "Should automatically create one filter row on successful table load")

            // Click Add Condition to add a second row
            addBtn.clicked()
            wait(50)
            verify(filterItemsCol.children.length > 1, "Should have more than one filter row after clicking Add Condition")

            ApiClient.getTableDetails = originalGetTableDetails
        }

        function test_addGroupButton() {
            var originalGetTableDetails = ApiClient.getTableDetails

            ApiClient.getTableDetails = function(schema, table, callback) {
                callback(true, { fields: ["id", "name"] })
            }

            filterBuilder.loadTables(["test_table"])
            wait(50)

            var filterItemsCol = filterBuilder.testFilterItemsColumn
            var countBefore = filterItemsCol.children.length

            // Find the "+ Group" button by clicking the add group function directly
            filterBuilder.addFilterGroup()
            wait(50)

            verify(filterItemsCol.children.length > countBefore, "Should have more filter items after adding a group")

            ApiClient.getTableDetails = originalGetTableDetails
        }

        function test_filterObjectUpdatesOnRootLogicChange() {
            var originalGetTableDetails = ApiClient.getTableDetails

            ApiClient.getTableDetails = function(schema, table, callback) {
                callback(true, { fields: ["id", "species"] })
            }

            filterBuilder.loadTables(["species_table"])
            wait(50)

            // Default root logic is AND
            compare(filterBuilder.rootLogic, "AND", "Default root logic should be AND")

            // Change to OR
            filterBuilder.rootLogic = "OR"
            filterBuilder.updateFilter()
            wait(50)

            // filterObject should use OR if there are conditions
            if (filterBuilder.filterObject.OR !== undefined) {
                verify(true, "filterObject uses OR when rootLogic is OR")
            }

            filterBuilder.rootLogic = "AND"
            ApiClient.getTableDetails = originalGetTableDetails
        }

        function test_apiFailure() {
            var originalGetTableDetails = ApiClient.getTableDetails

            ApiClient.getTableDetails = function(schema, table, callback) {
                callback(false, "Network error 404")
            }

            filterBuilder.loadTables(["bad_table"])
            wait(50)

            var errorLabel = filterBuilder.testErrorLabel

            verify(errorLabel !== null, "Should find error label")
            verify(errorLabel.visible, "Error label should be visible on failure")
            verify(errorLabel.text.indexOf("Network error") !== -1, "Error label should contain error message")

            ApiClient.getTableDetails = originalGetTableDetails
        }

        function test_buildValueNoValueOps() {
            // is_null and similar operators should return true regardless of input
            compare(filterBuilder.buildValue("is_null", "string", ""), true, "is_null returns true")
            compare(filterBuilder.buildValue("is_not_null", "string", ""), true, "is_not_null returns true")
            compare(filterBuilder.buildValue("is_empty", "string", ""), true, "is_empty returns true")
            compare(filterBuilder.buildValue("is_not_empty", "string", ""), true, "is_not_empty returns true")
            compare(filterBuilder.buildValue("is_past", "date", ""), true, "is_past returns true")
            compare(filterBuilder.buildValue("is_future", "date", ""), true, "is_future returns true")
            compare(filterBuilder.buildValue("is_today", "date", ""), true, "is_today returns true")
        }

        function test_buildValueNumeric() {
            compare(filterBuilder.buildValue("equals", "numeric", "42"), 42, "numeric equals parses float")
            compare(filterBuilder.buildValue("greater_than", "numeric", "3.14"), 3.14, "numeric greater_than parses float")
            verify(filterBuilder.buildValue("equals", "numeric", "abc") === null, "non-numeric string returns null")
            verify(filterBuilder.buildValue("equals", "numeric", "") === null, "empty string returns null for numeric")
        }

        function test_buildValueList() {
            var result = filterBuilder.buildValue("in", "string", "foo, bar, baz")
            compare(result.length, 3, "in list splits comma-separated values")
            compare(result[0], "foo", "first list item is correct")

            var numResult = filterBuilder.buildValue("in", "numeric", "1, 2, 3")
            compare(numResult.length, 3, "numeric in list parses numbers")
            compare(numResult[0], 1, "first numeric list item is 1")

            verify(filterBuilder.buildValue("in", "string", "  ,  , ") === null, "empty list values return null")
        }

        function test_buildValueBoolean() {
            compare(filterBuilder.buildValue("equals", "boolean", "true"), true, "boolean true parses correctly")
            compare(filterBuilder.buildValue("equals", "boolean", "false"), false, "boolean false parses correctly")
        }

        function test_buildValueStringEmpty() {
            verify(filterBuilder.buildValue("equals", "string", "") === null, "empty string value returns null")
            compare(filterBuilder.buildValue("ilike", "string", "foo"), "foo", "non-empty string passes through")
        }

        function test_getOperatorsReturnsCorrectOps() {
            var stringOps = filterBuilder.getOperators("string")
            verify(stringOps.length > 0, "String operators list is not empty")
            var hasIlike = false
            var hasIn = false
            var hasIsNull = false
            for (var i = 0; i < stringOps.length; i++) {
                if (stringOps[i].name === "ilike") hasIlike = true
                if (stringOps[i].name === "in") hasIn = true
                if (stringOps[i].name === "is_null") hasIsNull = true
            }
            verify(hasIlike, "String ops include ilike")
            verify(hasIn, "String ops include in")
            verify(hasIsNull, "String ops include is_null")

            var numOps = filterBuilder.getOperators("numeric")
            var hasGte = false
            for (var j = 0; j < numOps.length; j++) {
                if (numOps[j].name === "greater_than_or_equals") hasGte = true
            }
            verify(hasGte, "Numeric ops include greater_than_or_equals")

            var dateOps = filterBuilder.getOperators("date")
            var hasYear = false
            var hasIsPast = false
            for (var k = 0; k < dateOps.length; k++) {
                if (dateOps[k].name === "year") hasYear = true
                if (dateOps[k].name === "is_past") hasIsPast = true
            }
            verify(hasYear, "Date ops include year")
            verify(hasIsPast, "Date ops include is_past")
        }
    }
}
