import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0
import "../scripts/AuthManager.js" as AuthManager
import "../scripts/ApiClient.js" as ApiClient
import "../scripts/SyncEngine.js" as SyncEngine
import "../scripts/Utils.js" as Utils

// GraphQL Filter Builder Popup
Popup {
    id: filterBuilderPopup
    parent: mainWindow ? mainWindow.contentItem : null
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 600)
    height: Math.min(parent.height * 0.9, 700)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    // Optional: reference the inner filter builder so parents can access it.
    property alias myFilterBuilder: actualFilterBuilder

    background: Rectangle {
        color: filterBuilderPopup.bgColor
        radius: 8
        border.color: filterBuilderPopup.borderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Label {
            text: "API Query Builder"
            font.pixelSize: 20
            font.bold: true
            color: filterBuilderPopup.fgColor
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: filterBuilderPopup.borderColor
            opacity: 0.3
        }

        GraphQLFilterBuilder {
            id: actualFilterBuilder
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Item { Layout.fillHeight: true } // Spacer

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Proceed to Styling/BBOX"
                Layout.fillWidth: true
                implicitHeight: 48
                visible: actualFilterBuilder.subLayers.count > 0
                enabled: actualFilterBuilder.selectedSubLayerIndex >= 0
                onClicked: {
                    if (typeof iface !== "undefined") {
                        var subModel = actualFilterBuilder.subLayers;
                        var idx = actualFilterBuilder.selectedSubLayerIndex;
                        var selectedLayerName = (idx >= 0 && subModel.count > idx) ? subModel.get(idx).name : "Unknown";
                        iface.logMessage("QField4OBM: Proceed to Styling/BBOX clicked for " + selectedLayerName);

                        // Parse geometry type out of the layer name: e.g. "Table (Points)" -> "Point"
                        var geomType = "Attributes";
                        if (selectedLayerName.indexOf("(Points)") !== -1) geomType = "Point";
                        else if (selectedLayerName.indexOf("(Lines)") !== -1) geomType = "Line";
                        else if (selectedLayerName.indexOf("(Polygons)") !== -1) geomType = "Polygon";

                        // This assumes myStyleBboxPanel is accessible. In the monolithic qml it was.
                        // We will have to update this logic later or bind properties.
                        if (typeof myStyleBboxPanel !== "undefined" && myStyleBboxPanel) {
                            myStyleBboxPanel.currentGeometryType = geomType;
                        } else if (typeof styleAndBboxPopup !== "undefined" && styleAndBboxPopup) {
                            styleAndBboxPopup.currentGeometryType = geomType;
                        }

                        // Detect whether the target layer already exists in the project.
                        // If so, style settings will have no effect, so disable them in the UI.
                        const layerName = actualFilterBuilder.selectedTable + "_" + geomType;
                        let layerExists = false;
                        if (typeof qgisProject !== "undefined" && qgisProject) {
                            try {
                                const layers = (typeof qgisProject.mapLayersByName === "function")
                                    ? qgisProject.mapLayersByName(layerName)
                                    : null;
                                if (layers && layers.length > 0) {
                                    layerExists = true;
                                } else {
                                    const allLayers = (typeof qgisProject.mapLayers === "function")
                                        ? qgisProject.mapLayers()
                                        : qgisProject.mapLayers;
                                    if (allLayers) {
                                        const keys = Object.keys(allLayers);
                                        for (let k = 0; k < keys.length; k++) {
                                            const l = allLayers[keys[k]];
                                            if (l && (l.name === layerName || (typeof l.name === "function" && l.name() === layerName))) {
                                                layerExists = true;
                                                break;
                                            }
                                        }
                                    }
                                }
                            } catch(e) {}
                        }
                        if (typeof styleAndBboxPopup !== "undefined" && styleAndBboxPopup) {
                            styleAndBboxPopup.isExistingLayer = layerExists;
                        }
                    }
                    filterBuilderPopup.close();
                    if (typeof styleAndBboxPopup !== "undefined") {
                        styleAndBboxPopup.open();
                    }
                }
            }

            Button {
                text: "Close"
                Layout.fillWidth: true
                implicitHeight: 48
                onClicked: filterBuilderPopup.close()
            }
        }
    }
}
