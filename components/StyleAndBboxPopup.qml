import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0
import "../scripts/AuthManager.js" as AuthManager
import "../scripts/ApiClient.js" as ApiClient
import "../scripts/SyncEngine.js" as SyncEngine
import "../scripts/Utils.js" as Utils

// Styling and BBOX Settings Popup
Popup {
    id: styleAndBboxPopup
    parent: mainWindow ? mainWindow.contentItem : null
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 600)
    height: Math.min(parent.height * 0.9, 700)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    property alias currentGeometryType: myStyleBboxPanel.currentGeometryType
    property alias isExistingLayer: myStyleBboxPanel.isExistingLayer

    background: Rectangle {
        color: styleAndBboxPopup.bgColor
        radius: 8
        border.color: styleAndBboxPopup.borderColor
        border.width: 1
    }

    StyleAndBboxPanel {
        id: myStyleBboxPanel
        anchors.fill: parent

        onApplySettings: {
            if (typeof iface !== "undefined") {
                iface.logMessage("QField4OBM: Apply settings: " + JSON.stringify(styleConfig) + " BBOX: " + maxBboxArea);
            }
            styleAndBboxPopup.close();
            if (typeof dashboardPopup !== "undefined" && dashboardPopup) {
                dashboardPopup.open();
                // Instead of relying on internal ids from main.qml, we emit a signal or
                // update the dashboard's properties if accessible. But for now, we leave
                // the monolithic binding assuming dashboardPopup is a global component instance.
                dashboardPopup.syncStatusText = "Starting synchronization with BBOX limit: " + maxBboxArea + " km²...";
                dashboardPopup.syncStatusColor = dashboardPopup.fgColor;
                dashboardPopup.syncProgressValue = 0;
                dashboardPopup.syncProgressVisible = true;
            }

            var currentFilter = typeof filterBuilderPopup !== "undefined" && filterBuilderPopup ? filterBuilderPopup.myFilterBuilder.filterObject : {};
            var targetSrid = typeof filterBuilderPopup !== "undefined" && filterBuilderPopup ? filterBuilderPopup.myFilterBuilder.targetSrid : 4326;
            var selectedSchema = typeof filterBuilderPopup !== "undefined" && filterBuilderPopup ? filterBuilderPopup.myFilterBuilder.selectedSchema : "public";
            var selectedTable = typeof filterBuilderPopup !== "undefined" && filterBuilderPopup ? filterBuilderPopup.myFilterBuilder.selectedTable : "";

            // Extract field names from the filter builder's model to request them in obmDataList
            var fieldNames = [];
            var fModel = typeof filterBuilderPopup !== "undefined" && filterBuilderPopup ? filterBuilderPopup.myFilterBuilder.fields : null;
            if (fModel) {
                for (var i = 0; i < fModel.count; ++i) {
                    fieldNames.push(fModel.get(i).name);
                }
            }
            // Always include obm_id
            if (fieldNames.indexOf("obm_id") === -1) fieldNames.push("obm_id");

            var geomType = myStyleBboxPanel.currentGeometryType;

            SyncEngine.syncAll(maxBboxArea, currentFilter, selectedSchema, selectedTable, targetSrid, geomType, fieldNames, styleConfig, function(percent, message) {
                if (typeof dashboardPopup !== "undefined" && dashboardPopup) {
                    dashboardPopup.syncProgressValue = percent;
                    dashboardPopup.syncStatusText = message;
                }
            }, function(success, message) {
                if (typeof dashboardPopup !== "undefined" && dashboardPopup) {
                    dashboardPopup.syncProgressVisible = false;
                    dashboardPopup.close();
                }

                if (typeof syncResultPopup !== "undefined" && syncResultPopup) {
                    syncResultPopup.success = success;
                    syncResultPopup.message = message;
                    syncResultPopup.open();
                }

                if (typeof iface !== "undefined") {
                    iface.logMessage("QField4OBM Sync Finished: " + message);
                }
            });
        }

        onBackRequested: {
            styleAndBboxPopup.close();
            if (typeof filterBuilderPopup !== "undefined" && filterBuilderPopup) {
                filterBuilderPopup.open();
            }
        }
    }
}
