import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0
import "../scripts/AuthManager.js" as AuthManager
import "../scripts/ApiClient.js" as ApiClient
import "../scripts/SyncEngine.js" as SyncEngine
import "../scripts/Utils.js" as Utils

// Dashboard Popup for when the user is logged in
Popup {
    id: dashboardPopup
    parent: mainWindow ? mainWindow.contentItem : null
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 400)
    height: Math.min(parent.height * 0.9, 500)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Use QField Theme properties discovered from logs, fallback to light mode colors
    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    property alias syncStatusText: syncStatusLabel.text
    property alias syncStatusColor: syncStatusLabel.color
    property alias syncProgressValue: syncProgressBar.value
    property alias syncProgressVisible: syncProgressBar.visible

    background: Rectangle {
        color: dashboardPopup.bgColor
        radius: 8
        border.color: dashboardPopup.borderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Label {
            text: "QField4OBM Dashboard"
            font.pixelSize: 20
            font.bold: true
            color: dashboardPopup.fgColor
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: dashboardPopup.borderColor
            opacity: 0.3
        }

        Label {
            text: "Logged in to: " + (pluginSettings.projectName || "")
            color: "green"
            font.bold: true
            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
        }

        Label {
            id: syncStatusLabel
            text: "Ready to synchronize data from OpenBioMaps."
            color: dashboardPopup.fgColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
        }

        ProgressBar {
            id: syncProgressBar
            Layout.fillWidth: true
            from: 0
            to: 100
            value: 0
            visible: false
        }

        Item { Layout.fillHeight: true } // Spacer

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "My Projects"
                Layout.fillWidth: true
                implicitHeight: 48
                enabled: !syncProgressBar.visible
                onClicked: {
                    syncStatusLabel.text = "Loading projects...";
                    syncStatusLabel.color = dashboardPopup.fgColor;

                    ApiClient.getUserProjects(function(success, response) {
                        dashboardPopup.close();
                        projectsPopup.open();

                        if (success) {
                            syncStatusLabel.text = "Ready to synchronize data from OpenBioMaps.";
                            syncStatusLabel.color = dashboardPopup.fgColor;

                            var projectsArray = Array.isArray(response) ? response : (response.data || []);
                            var mappedProjects = [];
                            for (var i = 0; i < projectsArray.length; i++) {
                                var item = projectsArray[i];
                                if (!item.name && item.languages) {
                                    var langs = Object.keys(item.languages);
                                    if (langs.length > 0) {
                                        var uiLang = (typeof Qt !== "undefined" && Qt.uiLanguage) ? String(Qt.uiLanguage).split("_")[0] : null;
                                        var selectedLang = null;

                                        if (uiLang && item.languages[uiLang]) {
                                            selectedLang = uiLang;
                                        } else if (item.languages["hu"]) {
                                            selectedLang = "hu";
                                        } else {
                                            selectedLang = langs[0];
                                        }

                                        if (selectedLang && item.languages[selectedLang].name) {
                                            item.name = item.languages[selectedLang].name;
                                        }
                                    }
                                }
                                if (!item.name) {
                                    item.name = item.project_table || "Unknown";
                                }
                                mappedProjects.push(item);
                            }

                            projectsPopup.userProjectsList = mappedProjects;
                            projectsPopup.errorMessage = "";
                        } else {
                            projectsPopup.errorMessage = "Error loading projects: " + response;
                            projectsPopup.userProjectsList = [];
                        }
                    });
                }
            }

            Button {
                text: "Get Data Tables"
                Layout.fillWidth: true
                implicitHeight: 48
                enabled: !syncProgressBar.visible
                onClicked: {
                    syncStatusLabel.text = "Loading data tables...";
                    syncStatusLabel.color = dashboardPopup.fgColor;

                    ApiClient.getDataTables(function(success, response) {
                        if (success) {
                            syncStatusLabel.text = "Data tables loaded.";
                            syncStatusLabel.color = "green";
                            dashboardPopup.close();
                            filterBuilderPopup.open();
                            var tablesArray = Array.isArray(response) ? response : (response.data || []);
                            filterBuilderPopup.myFilterBuilder.loadTables(tablesArray);
                        } else {
                            syncStatusLabel.text = "Error: " + response;
                            syncStatusLabel.color = "red";
                        }
                    });
                }
            }
        }
    }
}
