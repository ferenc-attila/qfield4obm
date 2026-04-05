import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0

// New Screen: Final Status / Sync Details Popup
Popup {
    id: syncResultPopup
    parent: mainWindow ? mainWindow.contentItem : null
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 400)
    height: Math.min(parent.height * 0.9, 300)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"

    property bool success: false
    property string message: ""

    background: Rectangle {
        color: syncResultPopup.bgColor
        radius: 8
        border.color: syncResultPopup.borderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Label {
            text: syncResultPopup.success ? "Sync Successful" : "Sync Stopped"
            font.pixelSize: 20
            font.bold: true
            color: syncResultPopup.success ? "green" : "orange"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: syncResultPopup.borderColor
            opacity: 0.3
        }

        Label {
            text: syncResultPopup.message
            color: syncResultPopup.fgColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "Download Another Layer"
                Layout.fillWidth: true
                implicitHeight: 48
                onClicked: {
                    syncResultPopup.close();
                    if (typeof filterBuilderPopup !== "undefined" && filterBuilderPopup) {
                        filterBuilderPopup.open();
                    }
                }
            }

            Button {
                text: "Close"
                Layout.fillWidth: true
                implicitHeight: 48
                onClicked: {
                    syncResultPopup.close();
                }
            }
        }
    }
}
