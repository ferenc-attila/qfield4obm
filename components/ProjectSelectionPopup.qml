import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0
import "../scripts/AuthManager.js" as AuthManager
import "../scripts/ApiClient.js" as ApiClient
import "../scripts/SyncEngine.js" as SyncEngine
import "../scripts/Utils.js" as Utils

// Projects Popup to switch between available projects
Popup {
    id: projectsPopup
    parent: mainWindow ? mainWindow.contentItem : null
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 400)
    height: Math.min(parent.height * 0.9, 500) // Increased slightly for warning
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    property var userProjectsList: []
    property string errorMessage: ""

    background: Rectangle {
        color: projectsPopup.bgColor
        radius: 8
        border.color: projectsPopup.borderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Label {
            text: "My Projects"
            font.pixelSize: 20
            font.bold: true
            color: projectsPopup.fgColor
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: projectsPopup.borderColor
            opacity: 0.3
        }

        Label {
            text: projectsPopup.errorMessage
            color: "red"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            visible: projectsPopup.errorMessage !== ""
        }

        Label {
            text: "Select Project:"
            color: projectsPopup.fgColor
            Layout.topMargin: 10
        }

        ComboBox {
            id: userProjectCombo
            Layout.fillWidth: true
            model: projectsPopup.userProjectsList
            textRole: "name"

            contentItem: Text {
                text: userProjectCombo.displayText
                color: projectsPopup.fgColor
                font: userProjectCombo.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: 10
            }

            popup: Popup {
                y: userProjectCombo.height - 1
                width: userProjectCombo.width
                implicitHeight: Math.min(contentItem.implicitHeight, projectsPopup.height - userProjectCombo.y - 60)
                padding: 1

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: userProjectCombo.popup.visible ? userProjectCombo.delegateModel : null
                    currentIndex: userProjectCombo.highlightedIndex
                    ScrollIndicator.vertical: ScrollIndicator { }
                }

                background: Rectangle {
                    color: projectsPopup.bgColor
                    border.color: projectsPopup.borderColor
                    radius: 2
                }
            }

            delegate: ItemDelegate {
                width: userProjectCombo.width

                background: Rectangle {
                    color: userProjectCombo.highlightedIndex === index ?
                        ((typeof Theme !== "undefined" && typeof Theme.mainColorSemiOpaque !== "undefined") ? Theme.mainColorSemiOpaque : "#e0e0e0")
                        : "transparent"
                }

                contentItem: Text {
                    text: typeof modelData !== "undefined" && modelData.name ? modelData.name : ""
                    color: projectsPopup.fgColor
                    font: userProjectCombo.font
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                }
                highlighted: userProjectCombo.highlightedIndex === index
            }
        }

        Item { Layout.fillHeight: true } // Spacer

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "Logout"
                Layout.fillWidth: true
                implicitHeight: 48
                onClicked: {
                    AuthManager.logout();
                    pluginSettings.isLoggedIn = false;
                    projectsPopup.close();
                    loginPopup.step = 0;
                    loginPopup.open();
                }
            }

            Button {
                text: "Cancel"
                Layout.fillWidth: true
                implicitHeight: 48
                onClicked: {
                    projectsPopup.close();
                }
            }
        }

        Button {
            text: "Switch Project"
            Layout.fillWidth: true
            implicitHeight: 48
            onClicked: {
                var selectedProjObj = projectsPopup.userProjectsList[userProjectCombo.currentIndex];
                var projectTable = selectedProjObj.project_table || selectedProjObj.table_name;
                var projectName = selectedProjObj.name || projectTable;

                if (projectTable !== AuthManager.getSelectedProject()) {
                    AuthManager.setSelectedProject(projectTable, projectName);
                    dashboardPopup.open(); // Will reload with new project name string
                } else {
                    dashboardPopup.open();
                }
                projectsPopup.close();
            }
        }
    }
}
