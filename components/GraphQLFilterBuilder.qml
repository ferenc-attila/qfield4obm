// GraphQLFilterBuilder.qml
// Component for building dynamic GraphQL filter objects.
// Uses ApiClient.js to fetch available data tables and their column definitions.
// Generates a JS object matching the ObmDataFilterInput schema.
// Supports AND/OR/NOT logical operators and nested filter groups.

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0
import Theme 1.0
import "../scripts/ApiClient.js" as ApiClient

Item {
    id: root
    width: 400
    height: 600

    // Expose the generated filter object (read-only)
    property var filterObject: ({})
    property int targetSrid: 4326

    // Expose selection state for main.qml
    property alias selectedSubLayerIndex: subLayerCombo.currentIndex
    property alias subLayers: subLayerModel
    property alias fields: fieldsModel
    property string selectedSchema: tableCombo.currentIndex >= 0 && tablesModel.count > tableCombo.currentIndex ? (tablesModel.get(tableCombo.currentIndex).schema || "public") : "public"
    property string selectedTable: tableCombo.currentIndex >= 0 && tablesModel.count > tableCombo.currentIndex ? tablesModel.get(tableCombo.currentIndex).name : ""

    // ----- Models -----
    ListModel { id: tablesModel }
    ListModel { id: subLayerModel }
    ListModel { id: fieldsModel }

    // Safe Theme color properties (overridden from main.qml)
    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    // ----- Filter state -----
    property string rootLogic: "AND"
    property var createdFilterItems: []  // array of dynamically created QML filter item objects

    // ----- Test Hooks -----
    property alias testMainColumn: mainColumn
    property alias testErrorLabel: errorLabel
    property alias testAddButton: addConditionButton
    property alias testFilterItemsColumn: filterItemsColumn

    // ----- Operator definitions -----
    function getOperators(baseType) {
        if (baseType === "numeric") {
            return [
                { name: "equals",                 label: "= equals" },
                { name: "not_equals",             label: "≠ not equals" },
                { name: "greater_than",           label: "> greater than" },
                { name: "less_than",              label: "< less than" },
                { name: "greater_than_or_equals", label: "≥ at least" },
                { name: "less_than_or_equals",    label: "≤ at most" },
                { name: "in",                     label: "in list" },
                { name: "not_in",                 label: "not in list" },
                { name: "is_null",                label: "is null" },
                { name: "is_not_null",            label: "is not null" }
            ]
        } else if (baseType === "boolean") {
            return [
                { name: "equals",     label: "equals" },
                { name: "not_equals", label: "not equals" },
                { name: "is_null",    label: "is null" },
                { name: "is_not_null", label: "is not null" }
            ]
        } else if (baseType === "date") {
            return [
                { name: "equals",                 label: "equals" },
                { name: "not_equals",             label: "not equals" },
                { name: "greater_than",           label: "after" },
                { name: "less_than",              label: "before" },
                { name: "greater_than_or_equals", label: "on or after" },
                { name: "less_than_or_equals",    label: "on or before" },
                { name: "year",                   label: "year equals" },
                { name: "is_past",                label: "is in past" },
                { name: "is_future",              label: "is in future" },
                { name: "is_today",               label: "is today" },
                { name: "is_null",                label: "is null" },
                { name: "is_not_null",            label: "is not null" }
            ]
        } else {
            // string (default)
            return [
                { name: "equals",        label: "equals" },
                { name: "not_equals",    label: "not equals" },
                { name: "iequals",       label: "equals (ignore case)" },
                { name: "ilike",         label: "contains" },
                { name: "not_ilike",     label: "not contains" },
                { name: "istarts_with",  label: "starts with" },
                { name: "iends_with",    label: "ends with" },
                { name: "in",            label: "in list" },
                { name: "not_in",        label: "not in list" },
                { name: "is_null",       label: "is null" },
                { name: "is_not_null",   label: "is not null" },
                { name: "is_empty",      label: "is empty" },
                { name: "is_not_empty",  label: "is not empty" }
            ]
        }
    }

    function isNoValueOp(opName) {
        return ["is_null", "is_not_null", "is_empty", "is_not_empty",
                "is_past", "is_future", "is_today"].indexOf(opName) >= 0
    }

    function isListOp(opName) {
        return ["in", "not_in"].indexOf(opName) >= 0
    }

    function buildValue(op, baseType, rawVal) {
        if (isNoValueOp(op)) return true

        if (isListOp(op)) {
            var parts = rawVal.split(",").map(function(v) { return v.trim() }).filter(function(v) { return v !== "" })
            if (parts.length === 0) return null
            if (baseType === "numeric") {
                var nums = parts.map(function(v) { return parseFloat(v) }).filter(function(v) { return !isNaN(v) })
                return nums.length > 0 ? nums : null
            }
            return parts
        }

        if (baseType === "numeric") {
            if (op === "year") { var y = parseInt(rawVal); return isNaN(y) ? null : y }
            var n = parseFloat(rawVal)
            return isNaN(n) ? null : n
        }
        if (baseType === "boolean") {
            return rawVal === "true" || rawVal === true
        }
        if (rawVal === "") return null
        return rawVal
    }

    // ----- Filter object builder -----
    function updateFilter() {
        var items = []
        for (var i = 0; i < createdFilterItems.length; i++) {
            var item = createdFilterItems[i]
            if (item && typeof item.buildFilter === "function") {
                var built = item.buildFilter()
                if (built !== null) items.push(built)
            }
        }
        if (items.length === 0) {
            filterObject = {}
        } else {
            var result = {}
            result[rootLogic] = items
            filterObject = result
        }
        console.log("GraphQLFilterBuilder: filterObject", JSON.stringify(filterObject))
    }

    // ----- Dynamic item management -----
    function addFilterCondition() {
        var item = conditionRowComp.createObject(filterItemsColumn, {
            initialFieldIndex: 0
        })
        if (item) {
            item.removeRequested.connect(function() { removeFilterItem(item) })
            item.filterChanged.connect(updateFilter)
            var newItems = createdFilterItems.slice()
            newItems.push(item)
            createdFilterItems = newItems
        }
        updateFilter()
    }

    function addFilterGroup() {
        var item = groupRowComp.createObject(filterItemsColumn)
        if (item) {
            item.removeRequested.connect(function() { removeFilterItem(item) })
            item.filterChanged.connect(updateFilter)
            var newItems = createdFilterItems.slice()
            newItems.push(item)
            createdFilterItems = newItems
        }
        updateFilter()
    }

    function removeFilterItem(item) {
        var newItems = []
        for (var i = 0; i < createdFilterItems.length; i++) {
            if (createdFilterItems[i] !== item) newItems.push(createdFilterItems[i])
        }
        createdFilterItems = newItems
        item.destroy()
        updateFilter()
    }

    function clearAllFilterItems() {
        for (var i = 0; i < createdFilterItems.length; i++) {
            if (createdFilterItems[i]) createdFilterItems[i].destroy()
        }
        createdFilterItems = []
    }

    // ----- Condition Row Component -----
    // Used at root level and inside groups (isGroupCondition controls visual depth).
    Component {
        id: conditionRowComp

        Rectangle {
            id: condRow
            width: parent ? parent.width : root.width
            height: condColumn.implicitHeight + 24
            radius: 8
            color: "transparent"
            border.color: isGroupCondition ? Qt.lighter(root.borderColor, 1.3) : root.borderColor
            border.width: 1

            signal removeRequested()
            signal filterChanged()

            property int initialFieldIndex: 0
            property bool isGroupCondition: false

            // UI state — all written back by child controls
            property int currentFieldIndex: initialFieldIndex
            property string currentBaseType: {
                if (fieldsModel.count > 0 && initialFieldIndex < fieldsModel.count)
                    return fieldsModel.get(initialFieldIndex).baseType || "string"
                return "string"
            }
            property int currentOpIndex: 0
            property string currentValue: ""
            property bool negated: false

            // Computed from state
            property var currentOps: root.getOperators(currentBaseType)
            property string currentOperator: currentOpIndex < currentOps.length ? currentOps[currentOpIndex].name : "equals"
            property bool isNoValue: root.isNoValueOp(currentOperator)
            property bool isListValue: root.isListOp(currentOperator)

            // Sync currentValue changes back to the text field (e.g. when field changes)
            onCurrentValueChanged: {
                if (textValueInput.text !== currentValue) textValueInput.text = currentValue
            }

            function buildFilter() {
                if (fieldsModel.count === 0) return null
                var fieldIdx = currentFieldIndex < fieldsModel.count ? currentFieldIndex : 0
                var col = fieldsModel.get(fieldIdx).name
                if (!col || !currentOperator) return null
                var val = root.buildValue(currentOperator, currentBaseType, currentValue)
                if (val === null && !isNoValue) return null
                var cond = {}
                cond[currentOperator] = val
                var field = {}
                field[col] = cond
                if (negated) return { NOT: field }
                return field
            }

            Column {
                id: condColumn
                width: parent.width - 24
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                spacing: 10

                // Row 1: Field and Operator selectors
                Row {
                    width: parent.width
                    spacing: 8

                    ComboBox {
                        id: fieldCombo
                        width: (parent.width - 8) / 2
                        model: fieldsModel
                        textRole: "name"
                        Component.onCompleted: {
                            currentIndex = condRow.initialFieldIndex < fieldsModel.count ? condRow.initialFieldIndex : 0
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < fieldsModel.count
                                    && currentIndex !== condRow.currentFieldIndex) {
                                condRow.currentFieldIndex = currentIndex
                                condRow.currentBaseType = fieldsModel.get(currentIndex).baseType || "string"
                                condRow.currentOpIndex = 0
                                condRow.currentValue = ""
                                condRow.filterChanged()
                            }
                        }
                    }

                    ComboBox {
                        id: opCombo
                        width: (parent.width - 8) / 2
                        model: condRow.currentOps
                        textRole: "label"
                        onModelChanged: currentIndex = 0
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < condRow.currentOps.length
                                    && currentIndex !== condRow.currentOpIndex) {
                                condRow.currentOpIndex = currentIndex
                                condRow.filterChanged()
                            }
                        }
                    }
                }

                // Row 2a: Text / number / date value input
                TextField {
                    id: textValueInput
                    visible: !condRow.isNoValue && condRow.currentBaseType !== "boolean"
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    placeholderText: condRow.isListValue ? "val1, val2, val3..." :
                                     condRow.currentBaseType === "date" ? "YYYY-MM-DD" :
                                     condRow.currentBaseType === "numeric" ? "Enter number..." : "Enter text..."
                    inputMethodHints: condRow.currentBaseType === "numeric" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
                    onTextChanged: {
                        if (text !== condRow.currentValue) {
                            condRow.currentValue = text
                            condRow.filterChanged()
                        }
                    }
                }

                // Row 2b: Boolean value input
                ComboBox {
                    id: boolValueCombo
                    visible: !condRow.isNoValue && condRow.currentBaseType === "boolean"
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    model: ["true", "false"]
                    onVisibleChanged: {
                        if (visible) {
                            condRow.currentValue = currentText
                            condRow.filterChanged()
                        }
                    }
                    onCurrentTextChanged: {
                        if (visible) {
                            condRow.currentValue = currentText
                            condRow.filterChanged()
                        }
                    }
                }

                // Row 3: NOT toggle and Remove button
                Row {
                    width: parent.width
                    spacing: 8

                    CheckBox {
                        text: "NOT"
                        checked: condRow.negated
                        onCheckedChanged: {
                            condRow.negated = checked
                            condRow.filterChanged()
                        }
                    }

                    Button {
                        text: "Remove"
                        height: 48
                        onClicked: condRow.removeRequested()
                    }
                }
            }
        }
    }

    // ----- Filter Group Component -----
    // A logical group (AND/OR) containing nested condition rows.
    Component {
        id: groupRowComp

        Rectangle {
            id: groupRect
            width: parent ? parent.width : root.width
            height: groupColumn.implicitHeight + 24
            radius: 8
            color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.08)
            border.color: root.borderColor
            border.width: 2

            signal removeRequested()
            signal filterChanged()

            property string groupLogic: "OR"
            property bool negated: false
            property var groupConditionItems: []

            function buildFilter() {
                var items = []
                for (var i = 0; i < groupConditionItems.length; i++) {
                    var item = groupConditionItems[i]
                    if (item && typeof item.buildFilter === "function") {
                        var built = item.buildFilter()
                        if (built !== null) items.push(built)
                    }
                }
                if (items.length === 0) return null
                var g = {}
                g[groupLogic] = items
                if (negated) return { NOT: g }
                return g
            }

            function addGroupCondition() {
                var item = conditionRowComp.createObject(groupInnerColumn, {
                    initialFieldIndex: 0,
                    isGroupCondition: true
                })
                if (item) {
                    item.removeRequested.connect(function() { removeGroupCondition(item) })
                    item.filterChanged.connect(groupRect.filterChanged)
                    groupConditionItems.push(item)
                }
                groupRect.filterChanged()
            }

            function removeGroupCondition(item) {
                var newItems = []
                for (var i = 0; i < groupConditionItems.length; i++) {
                    if (groupConditionItems[i] !== item) newItems.push(groupConditionItems[i])
                }
                groupConditionItems = newItems
                item.destroy()
                groupRect.filterChanged()
            }

            Component.onCompleted: addGroupCondition()

            Column {
                id: groupColumn
                width: parent.width - 24
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                spacing: 10

                // Group header
                Row {
                    width: parent.width
                    spacing: 8

                    Label {
                        text: "Group:"
                        color: root.fgColor
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                        height: 48
                    }

                    ComboBox {
                        width: 110
                        model: ["OR", "AND"]
                        currentIndex: groupRect.groupLogic === "AND" ? 1 : 0
                        onCurrentTextChanged: {
                            groupRect.groupLogic = currentText
                            groupRect.filterChanged()
                        }
                    }

                    CheckBox {
                        text: "NOT"
                        checked: groupRect.negated
                        onCheckedChanged: {
                            groupRect.negated = checked
                            groupRect.filterChanged()
                        }
                    }

                    Button {
                        text: "Remove Group"
                        height: 48
                        onClicked: groupRect.removeRequested()
                    }
                }

                // Nested conditions
                Column {
                    id: groupInnerColumn
                    width: parent.width
                    spacing: 8
                }

                Button {
                    text: "+ Add Condition"
                    height: 48
                    width: parent.width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: groupRect.addGroupCondition()
                }
            }
        }
    }

    // ----- UI -----
    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: availableWidth
        contentHeight: mainColumn.implicitHeight + 40
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            id: mainColumn
            width: scrollView.width
            spacing: 24
            objectName: "mainColumn"

            // Step 1: Table selection
            Column {
                width: parent.width
                spacing: 12

                Label {
                    text: "Select Data Table:"
                    color: root.fgColor
                    font.bold: true
                    font.pixelSize: 16
                }

                ComboBox {
                    id: tableCombo
                    width: parent.width
                    model: tablesModel
                    textRole: "name"
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && tablesModel.count > currentIndex) {
                            var table = tablesModel.get(currentIndex).name
                            var schema = tablesModel.get(currentIndex).schema || "public"
                            ApiClient.getTableDetails(schema, table, function(success, response) {
                                if (success) {
                                    fieldsModel.clear()
                                    subLayerModel.clear()
                                    if (typeof iface !== "undefined") {
                                        iface.logMessage("QField4OBM: getTableDetails response -> " + JSON.stringify(response))
                                    }
                                    var fields = response.fields || []
                                    var obmGeom = null
                                    root.targetSrid = 4326
                                    for (var i = 0; i < fields.length; ++i) {
                                        var fieldObj = typeof fields[i] === "object" ? fields[i] : null
                                        var fieldName = fieldObj ? fieldObj.name : fields[i]
                                        var fieldType = fieldObj ? (fieldObj.type || "").toLowerCase() : "character varying"

                                        if (fieldObj && fieldName === "obm_geometry") {
                                            obmGeom = fieldObj
                                            if (fieldObj.geometry_column_details && fieldObj.geometry_column_details.SRID) {
                                                root.targetSrid = fieldObj.geometry_column_details.SRID
                                            }
                                        }

                                        var baseType = ""
                                        if (fieldType.indexOf("geometry") >= 0 || fieldType.indexOf("geography") >= 0) {
                                            continue
                                        } else if (fieldType.indexOf("character") >= 0 || fieldType.indexOf("text") >= 0) {
                                            baseType = "string"
                                        } else if (fieldType.indexOf("numeric") >= 0 || fieldType.indexOf("integer") >= 0 || fieldType.indexOf("double") >= 0 || fieldType.indexOf("real") >= 0 || fieldType.indexOf("int") >= 0) {
                                            baseType = "numeric"
                                        } else if (fieldType.indexOf("date") >= 0 || fieldType.indexOf("time") >= 0) {
                                            baseType = "date"
                                        } else if (fieldType.indexOf("bool") >= 0) {
                                            baseType = "boolean"
                                        } else {
                                            baseType = "string"
                                        }

                                        if (fieldName) {
                                            fieldsModel.append({ name: fieldName, baseType: baseType })
                                        }
                                    }

                                    if (!obmGeom) {
                                        subLayerModel.append({ name: table + " (Attributes)", icon: "mIconTable" })
                                    } else {
                                        var details = obmGeom.geometry_column_details
                                        if (details) {
                                            var pts = (details["Point"] || 0) + (details["MultiPoint"] || 0)
                                            var lines = (details["LineString"] || 0) + (details["MultiLineString"] || 0)
                                            var polys = (details["Polygon"] || 0) + (details["MultiPolygon"] || 0)
                                            if (pts > 0) subLayerModel.append({ name: table + " (Points)", icon: "mIconPoint" })
                                            if (lines > 0) subLayerModel.append({ name: table + " (Lines)", icon: "mIconLine" })
                                            if (polys > 0) subLayerModel.append({ name: table + " (Polygons)", icon: "mIconPolygon" })
                                            if (pts === 0 && lines === 0 && polys === 0) {
                                                subLayerModel.append({ name: table + " (Attributes)", icon: "mIconTable" })
                                            }
                                        } else {
                                            subLayerModel.append({ name: table + " (Attributes)", icon: "mIconTable" })
                                        }
                                    }

                                    // Reset filters for the new table
                                    root.clearAllFilterItems()
                                    root.addFilterCondition()
                                } else {
                                    errorLabel.text = "Failed to load table details: " + response
                                    errorLabel.visible = true
                                }
                            })
                        }
                    }
                }

                Label {
                    text: "Select Virtual Layer:"
                    color: root.fgColor
                    font.bold: true
                    font.pixelSize: 16
                    visible: subLayerModel.count > 0
                }

                ComboBox {
                    id: subLayerCombo
                    width: parent.width
                    model: subLayerModel
                    textRole: "name"
                    visible: subLayerModel.count > 0

                    delegate: ItemDelegate {
                        width: subLayerCombo.width
                        contentItem: RowLayout {
                            spacing: 12
                            Image {
                                source: (typeof Theme !== "undefined" && typeof Theme.getThemeIcon === "function") ? Theme.getThemeIcon(model.icon) : ("qrc:/icons/" + model.icon + ".svg")
                                sourceSize: Qt.size(24, 24)
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                fillMode: Image.PreserveAspectFit
                            }
                            Label {
                                text: model.name
                                color: root.fgColor
                                font.pixelSize: 14
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 12
                        Image {
                            source: subLayerCombo.currentIndex >= 0 ? ((typeof Theme !== "undefined" && typeof Theme.getThemeIcon === "function") ? Theme.getThemeIcon(subLayerModel.get(subLayerCombo.currentIndex).icon) : ("qrc:/icons/" + subLayerModel.get(subLayerCombo.currentIndex).icon + ".svg")) : ""
                            sourceSize: Qt.size(24, 24)
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            fillMode: Image.PreserveAspectFit
                        }
                        Label {
                            text: subLayerCombo.currentIndex >= 0 ? subLayerModel.get(subLayerCombo.currentIndex).name : ""
                            color: root.fgColor
                            font.pixelSize: 14
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Label {
                id: errorLabel
                objectName: "errorLabel"
                visible: false
                width: parent.width
                wrapMode: Label.WordWrap
                color: "red"
                font.italic: true
            }

            // Step 2: Filter builder
            Column {
                width: parent.width
                spacing: 12

                // Filter section header with root logic and add buttons
                Row {
                    width: parent.width
                    spacing: 8

                    Label {
                        text: "Filters:"
                        color: root.fgColor
                        font.bold: true
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        height: 48
                    }

                    ComboBox {
                        id: rootLogicCombo
                        width: 110
                        model: ["AND", "OR"]
                        currentIndex: root.rootLogic === "OR" ? 1 : 0
                        onCurrentTextChanged: {
                            root.rootLogic = currentText
                            root.updateFilter()
                        }
                    }

                    Button {
                        id: addConditionButton
                        objectName: "addFilterButton"
                        text: "+ Condition"
                        height: 48
                        onClicked: root.addFilterCondition()
                    }

                    Button {
                        text: "+ Group"
                        height: 48
                        onClicked: root.addFilterGroup()
                    }
                }

                // Container for dynamically created filter items
                Column {
                    id: filterItemsColumn
                    objectName: "filterItemsColumn"
                    width: parent.width
                    spacing: 12
                }
            }
        }
    }

    // ----- Helper: Load tables externally -----
    function loadTables(tables) {
        tablesModel.clear()
        for (var i = 0; i < tables.length; ++i) {
            var t = tables[i]
            var tableName = t.table_name || t.name || (typeof t === "string" ? t : "")
            var tableSchema = t.schema || "public"
            if (tableName) {
                tablesModel.append({ name: tableName, schema: tableSchema })
            }
        }
        if (tablesModel.count > 0) {
            tableCombo.currentIndex = 0
        }
    }
}