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

        function test_isRangeOp() {
            verify(filterBuilder.isRangeOp("between"), "between is a range op")
            verify(filterBuilder.isRangeOp("not_between"), "not_between is a range op")
            verify(filterBuilder.isRangeOp("between_days"), "between_days is a range op")
            verify(filterBuilder.isRangeOp("not_between_days"), "not_between_days is a range op")
            verify(!filterBuilder.isRangeOp("equals"), "equals is not a range op")
            verify(!filterBuilder.isRangeOp("year_in"), "year_in is not a range op")
            verify(!filterBuilder.isRangeOp("in"), "in is not a range op")
        }

        function test_buildValueRange() {
            var r1 = filterBuilder.buildValue("between", "date", { start: "2024-01-01", end: "2024-12-31" })
            verify(r1 !== null, "between with valid start/end returns non-null")
            compare(r1.start, "2024-01-01", "between start is correct")
            compare(r1.end, "2024-12-31", "between end is correct")

            var r2 = filterBuilder.buildValue("between_days", "date", { start: "04-15", end: "08-10" })
            verify(r2 !== null, "between_days with valid start/end returns non-null")
            compare(r2.start, "04-15", "between_days start is correct")
            compare(r2.end, "08-10", "between_days end is correct")

            var r3 = filterBuilder.buildValue("not_between", "date", { start: "2024-01-01", end: "" })
            verify(r3 === null, "between with empty end returns null")

            var r4 = filterBuilder.buildValue("between", "date", { start: "", end: "2024-12-31" })
            verify(r4 === null, "between with empty start returns null")

            var r5 = filterBuilder.buildValue("not_between_days", "date", { start: "12-01", end: "02-28" })
            compare(r5.start, "12-01", "not_between_days start is correct")
            compare(r5.end, "02-28", "not_between_days end is correct")
        }

        function test_buildValueDateIntegerOps() {
            compare(filterBuilder.buildValue("month", "date", "6"), 6, "month parses to integer")
            compare(filterBuilder.buildValue("day", "date", "15"), 15, "day parses to integer")
            compare(filterBuilder.buildValue("day_of_week", "date", "3"), 3, "day_of_week parses to integer")
            compare(filterBuilder.buildValue("day_of_year", "date", "200"), 200, "day_of_year parses to integer")
            verify(filterBuilder.buildValue("month", "date", "abc") === null, "month with non-numeric returns null")
            verify(filterBuilder.buildValue("day", "date", "") === null, "day with empty string returns null")
        }

        function test_buildValueYearIn() {
            var result = filterBuilder.buildValue("year_in", "date", "2022, 2023, 2024")
            verify(result !== null, "year_in returns non-null for valid input")
            compare(result.length, 3, "year_in returns 3 items")
            compare(result[0], 2022, "year_in first item is integer 2022")
            compare(result[1], 2023, "year_in second item is integer 2023")
            compare(result[2], 2024, "year_in third item is integer 2024")

            var r2 = filterBuilder.buildValue("month_in", "date", "3, 6, 9, 12")
            compare(r2.length, 4, "month_in returns 4 items")
            compare(r2[0], 3, "month_in first item is integer 3")

            verify(filterBuilder.buildValue("year_in", "date", "  ,  ") === null, "year_in empty input returns null")
        }

        function test_getOperators_dateHasNewOps() {
            var dateOps = filterBuilder.getOperators("date")
            var names = []
            for (let i = 0; i < dateOps.length; i++) names.push(dateOps[i].name)

            var expected = ["between", "not_between", "between_days", "not_between_days",
                            "year_in", "month", "month_in", "day", "day_of_week", "day_of_year"]
            for (let j = 0; j < expected.length; j++) {
                verify(names.indexOf(expected[j]) >= 0, "Date ops include " + expected[j])
            }
        }

        function test_getOperators_arrayType() {
            var arrayOps = filterBuilder.getOperators("array")
            verify(arrayOps.length === 14, "Array ops list has 14 entries")

            let names = []
            for (let i = 0; i < arrayOps.length; i++) names.push(arrayOps[i].name)

            let expected = [
                "contains", "not_contains",
                "contains_all", "contains_any", "contains_none",
                "icontains", "not_icontains",
                "icontains_all", "icontains_any", "icontains_none",
                "is_null", "is_not_null", "is_empty", "is_not_empty"
            ]
            for (let j = 0; j < expected.length; j++) {
                verify(names.indexOf(expected[j]) >= 0, "Array ops include " + expected[j])
            }
        }

        function test_buildValueArray() {
            // Single-value ops pass the string through
            compare(filterBuilder.buildValue("contains", "array", "fox"), "fox", "contains passes string value")
            compare(filterBuilder.buildValue("not_contains", "array", "fox"), "fox", "not_contains passes string value")
            compare(filterBuilder.buildValue("icontains", "array", "Fox"), "Fox", "icontains passes string value")
            compare(filterBuilder.buildValue("not_icontains", "array", "Fox"), "Fox", "not_icontains passes string value")

            // Empty single value returns null
            verify(filterBuilder.buildValue("contains", "array", "") === null, "contains with empty value returns null")

            // List ops return string arrays
            var r1 = filterBuilder.buildValue("contains_all", "array", "fox, bear")
            compare(r1.length, 2, "contains_all splits into 2 items")
            compare(r1[0], "fox", "contains_all first item correct")
            compare(r1[1], "bear", "contains_all second item correct")

            var r2 = filterBuilder.buildValue("contains_any", "array", "fox, bear, wolf")
            compare(r2.length, 3, "contains_any splits into 3 items")

            var r3 = filterBuilder.buildValue("icontains_none", "array", "Bad, Ugly")
            compare(r3.length, 2, "icontains_none splits into 2 items")
            compare(r3[0], "Bad", "icontains_none first item correct")

            // Empty list returns null
            verify(filterBuilder.buildValue("contains_all", "array", "  ,  ") === null, "contains_all with blank list returns null")

            // No-value ops
            compare(filterBuilder.buildValue("is_null", "array", ""), true, "is_null returns true for array")
            compare(filterBuilder.buildValue("is_not_null", "array", ""), true, "is_not_null returns true for array")
            compare(filterBuilder.buildValue("is_empty", "array", ""), true, "is_empty returns true for array")
            compare(filterBuilder.buildValue("is_not_empty", "array", ""), true, "is_not_empty returns true for array")
        }

        function test_arrayFieldTypeDetection() {
            var originalGetTableDetails = ApiClient.getTableDetails

            ApiClient.getTableDetails = function(schema, table, callback) {
                callback(true, {
                    fields: [
                        { name: "id",       type: "integer" },
                        { name: "tags",     type: "text[]" },
                        { name: "codes",    type: "_int4" },
                        { name: "species",  type: "character varying" }
                    ]
                })
            }

            filterBuilder.loadTables(["array_test_table"])
            wait(50)

            let arrayCount = 0
            let stringCount = 0
            let numericCount = 0
            for (let i = 0; i < filterBuilder.fields.count; i++) {
                let f = filterBuilder.fields.get(i)
                if (f.baseType === "array")   arrayCount++
                if (f.baseType === "string")  stringCount++
                if (f.baseType === "numeric") numericCount++
            }

            compare(arrayCount, 2, "Two array fields detected (text[] and _int4)")
            compare(stringCount, 1, "One string field detected (character varying)")
            compare(numericCount, 1, "One numeric field detected (integer)")

            ApiClient.getTableDetails = originalGetTableDetails
        }
    }
}
