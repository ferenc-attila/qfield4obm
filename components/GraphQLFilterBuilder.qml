// GraphQLFilterBuilder.qml
// Component for building dynamic GraphQL filter objects.
// Uses ApiClient.js to fetch available data tables and their column definitions.
// Generates a JS object matching the ObmDataFilterInput schema.

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.LocalStorage 2.12
import org.qfield 1.0
import Theme 1.0
import "../scripts/ApiClient.js" as ApiClient

Item {
    id: root
    width: 400
    height: 600
    // Expose the generated filter object (read‑only)
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
    ListModel { id: rowsModel }

    // Safe Theme color properties (overridden from main.qml)
    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    // ----- Test Hooks -----
    property alias testMainColumn: mainColumn
    property alias testErrorLabel: errorLabel
    property alias testAddButton: addFilterButton
    property alias testRowsRepeater: rowsRepeater

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
                                    var obmGeom = null;
                                    root.targetSrid = 4326; // reset to default
                                    for (var i = 0; i < fields.length; ++i) {
                                        // Handle both string array and object array representations
                                        var fieldObj = typeof fields[i] === "object" ? fields[i] : null;
                                        var fieldName = fieldObj ? fieldObj.name : fields[i];
                                        var fieldType = fieldObj ? (fieldObj.type || "").toLowerCase() : "character varying";

                                        if (fieldObj && fieldName === "obm_geometry") {
                                            obmGeom = fieldObj;
                                            if (fieldObj.geometry_column_details && fieldObj.geometry_column_details.SRID) {
                                                root.targetSrid = fieldObj.geometry_column_details.SRID;
                                            }
                                        }

                                        var baseType = "";
                                        if (fieldType.indexOf("geometry") >= 0 || fieldType.indexOf("geography") >= 0) {
                                            continue; // Skip geometry fields matching what the user requested
                                        } else if (fieldType.indexOf("character") >= 0 || fieldType.indexOf("text") >= 0) {
                                            baseType = "string";
                                        } else if (fieldType.indexOf("numeric") >= 0 || fieldType.indexOf("integer") >= 0 || fieldType.indexOf("double") >= 0 || fieldType.indexOf("real") >= 0 || fieldType.indexOf("int") >= 0) {
                                            baseType = "numeric";
                                        } else if (fieldType.indexOf("date") >= 0 || fieldType.indexOf("time") >= 0) {
                                            baseType = "date";
                                        } else if (fieldType.indexOf("bool") >= 0) {
                                            baseType = "boolean";
                                        } else {
                                            baseType = "string"; // fallback
                                        }

                                        if (fieldName) {
                                            fieldsModel.append({ name: fieldName, baseType: baseType })
                                        }
                                    }

                                    if (!obmGeom) {
                                        subLayerModel.append({ name: table + " (Attributes)", icon: "mIconTable" });
                                    } else {
                                        var details = obmGeom.geometry_column_details;
                                        if (details) {
                                            var pts = (details["Point"] || 0) + (details["MultiPoint"] || 0);
                                            var lines = (details["LineString"] || 0) + (details["MultiLineString"] || 0);
                                            var polys = (details["Polygon"] || 0) + (details["MultiPolygon"] || 0);
                                            
                                            // Append only if counts are > 0
                                            if (pts > 0) subLayerModel.append({ name: table + " (Points)", icon: "mIconPoint" });
                                            if (lines > 0) subLayerModel.append({ name: table + " (Lines)", icon: "mIconLine" });
                                            if (polys > 0) subLayerModel.append({ name: table + " (Polygons)", icon: "mIconPolygon" });
                                            
                                            if (pts === 0 && lines === 0 && polys === 0) {
                                                subLayerModel.append({ name: table + " (Attributes)", icon: "mIconTable" });
                                            }
                                        } else {
                                            subLayerModel.append({ name: table + " (Attributes)", icon: "mIconTable" });
                                        }
                                    }

                                    rowsModel.clear()
                                    rowsModel.append({ column: "", operator: "", value: "" })
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

            // Step 2: Dynamic filter rows
            Column {
                width: parent.width
                spacing: 16

                Repeater {
                    id: rowsRepeater
                    model: rowsModel

                    Rectangle {
                        id: filterRowRect
                        objectName: "filterRow"
                        width: parent.width
                        height: rowLayout.implicitHeight + 24
                        radius: 8
                        color: "transparent"
                        border.color: root.borderColor
                        border.width: 1

                        property string currentBaseType: {
                            if (colCombo.currentIndex >= 0 && fieldsModel.count > colCombo.currentIndex) {
                                var bt = fieldsModel.get(colCombo.currentIndex).baseType;
                                return bt ? bt : "string";
                            }
                            return "string";
                        }

                        Column {
                            id: rowLayout
                            width: parent.width - 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            spacing: 12

                            // Row 1: Column and Operator
                            Row {
                                width: parent.width
                                spacing: 12
                                ComboBox {
                                    id: colCombo
                                    width: (parent.width - 12) / 2
                                    model: fieldsModel
                                    textRole: "name"
                                    onCurrentIndexChanged: { 
                                        if(currentIndex >= 0 && currentIndex < fieldsModel.count && index >= 0) { 
                                            var f = fieldsModel.get(currentIndex);
                                            rowsModel.setProperty(index, "column", f.name);
                                            rowsModel.setProperty(index, "baseType", f.baseType || "string");
                                            rowsModel.setProperty(index, "value", "");
                                            root.updateFilter(); 
                                        } 
                                    }
                                }
                                ComboBox {
                                    id: opCombo
                                    width: (parent.width - 12) / 2
                                    model: [{name:"equals"},{name:"ilike"},{name:"greater_than"},{name:"less_than"},{name:"is_null"}]
                                    textRole: "name"
                                    onCurrentIndexChanged: { 
                                        if(currentIndex >= 0 && currentIndex < model.length && index >= 0) { 
                                            rowsModel.setProperty(index, "operator", opCombo.model[currentIndex].name); 
                                            root.updateFilter(); 
                                        } 
                                    }
                                }
                            }

                            // Row 2: Value and Remove Button
                            Row {
                                width: parent.width
                                spacing: 12
                                
                                TextField {
                                    visible: opCombo.currentText !== "is_null" && filterRowRect.currentBaseType === "string"
                                    width: visible ? (parent.width - 12) / 2 : 0
                                    placeholderText: "Enter text..."
                                    text: filterRowRect.currentBaseType === "string" && model.value !== undefined ? model.value : ""
                                    onTextChanged: { if(visible && text !== model.value) { rowsModel.setProperty(index, "value", text); root.updateFilter(); } }
                                }
                                TextField {
                                    visible: opCombo.currentText !== "is_null" && filterRowRect.currentBaseType === "numeric"
                                    width: visible ? (parent.width - 12) / 2 : 0
                                    placeholderText: "Enter number..."
                                    validator: DoubleValidator {}
                                    text: filterRowRect.currentBaseType === "numeric" && model.value !== undefined ? model.value : ""
                                    onTextChanged: { 
                                        if(visible && text !== String(model.value)) { 
                                            rowsModel.setProperty(index, "value", text); 
                                            root.updateFilter(); 
                                        } 
                                    }
                                }
                                TextField {
                                    visible: opCombo.currentText !== "is_null" && filterRowRect.currentBaseType === "date"
                                    width: visible ? (parent.width - 12) / 2 : 0
                                    placeholderText: "YYYY-MM-DD"
                                    text: filterRowRect.currentBaseType === "date" && model.value !== undefined ? model.value : ""
                                    onTextChanged: { if(visible && text !== model.value) { rowsModel.setProperty(index, "value", text); root.updateFilter(); } }
                                }
                                ComboBox {
                                    visible: opCombo.currentText !== "is_null" && filterRowRect.currentBaseType === "boolean"
                                    width: visible ? (parent.width - 12) / 2 : 0
                                    model: ["true", "false"]
                                    onCurrentTextChanged: { if(visible) { rowsModel.setProperty(index, "value", currentText); root.updateFilter(); } }
                                    onVisibleChanged: { if(visible) { rowsModel.setProperty(index, "value", currentText); root.updateFilter(); } }
                                }

                                Button {
                                    text: "Remove Filter"
                                    width: opCombo.currentText === "is_null" ? parent.width : (parent.width - 12) / 2
                                    onClicked: { rowsModel.remove(index); root.updateFilter(); }
                                }
                            }
                        }
                    }
                }
            }

            Button {
                id: addFilterButton
                objectName: "addFilterButton"
                text: "Add Filter"
                font.bold: true
                width: parent.width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    var initialCol = "";
                    var initialBT = "string";
                    if (fieldsModel.count > 0) {
                        initialCol = fieldsModel.get(0).name;
                        initialBT = fieldsModel.get(0).baseType || "string";
                    }
                    var initialOp = "equals";
                    rowsModel.append({ column: initialCol, baseType: initialBT, operator: initialOp, value: "" });
                    root.updateFilter();
                }
            }
        }
    }

    // ----- Helper: Build filter object -----
    function updateFilter() {
        var andArray = []
        for (var i = 0; i < rowsModel.count; ++i) {
            var row = rowsModel.get(i)
            if (!row.column) continue
            var op = row.operator
            if (!op) continue
            var val = row.value
            
            // Cast string values to correct types for GraphQL based on column baseType
            if (op !== "is_null") {
                var ctype = row.baseType;
                // Skip empty values for non-is_null operators to avoid server-side parse errors (e.g. empty date string)
                if (val === "" && ctype !== "boolean") continue;

                if (ctype === "numeric") {
                    val = parseFloat(val);
                    if (isNaN(val)) continue; // avoid invalid type submissions
                } else if (ctype === "boolean") {
                    val = (val === "true" || val === true || val === "");
                }
            } else {
                val = true; // For is_null, GraphQL object simply needs `true`
            }

            var condition = {}
            condition[op] = val
            var fieldObj = {}
            fieldObj[row.column] = condition
            andArray.push(fieldObj)
        }
        if (andArray.length > 0) {
            filterObject = { AND: andArray }
        } else {
            filterObject = {}
        }
        console.log("GraphQLFilterBuilder: filterObject", JSON.stringify(filterObject))
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
        // Select first table if available
        if (tablesModel.count > 0) {
            tableCombo.currentIndex = 0
        }
    }
}
