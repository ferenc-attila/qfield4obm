import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import Theme 1.0

Item {
    id: root
    width: 400
    height: 600

    property string currentGeometryType: ""
    property string selectedColor: "#e6194b"
    property bool isExistingLayer: false

    signal applySettings(var styleConfig, double maxBboxArea)
    signal backRequested()

    // internal properties
    property color bgColor: (typeof Theme !== "undefined" && typeof Theme.controlBackgroundColor !== "undefined") ? Theme.controlBackgroundColor : "#ffffff"
    property color fgColor: (typeof Theme !== "undefined" && typeof Theme.mainTextColor !== "undefined") ? Theme.mainTextColor : "#000000"
    property color borderColor: (typeof Theme !== "undefined" && typeof Theme.controlBorderColor !== "undefined") ? Theme.controlBorderColor : "#cccccc"
    property color errorColor: (typeof Theme !== "undefined" && typeof Theme.errorColor !== "undefined") ? Theme.errorColor : "red"
    property color warningColor: (typeof Theme !== "undefined" && typeof Theme.warningColor !== "undefined") ? Theme.warningColor : "orange"

    // Helper geometry type categorizer
    property bool isPoint: currentGeometryType.indexOf("Point") !== -1
    property bool isPoly: currentGeometryType.indexOf("Polygon") !== -1 || currentGeometryType === "Attributes"
    // default to line if not point/poly, or if explicitly line
    property bool isLine: currentGeometryType.indexOf("Line") !== -1

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 20

            Label {
                text: "Layer Style Settings"
                font.pixelSize: 18
                font.bold: true
                color: root.fgColor
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.borderColor
            }

            // --- STYLING ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                enabled: !root.isExistingLayer
                opacity: root.isExistingLayer ? 0.4 : 1.0

                Label {
                    text: "Color:"
                    color: root.fgColor
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: ["#e6194b", "#3cb44b", "#ffe119", "#4363d8", "#f58231", "#911eb4", "#46f0f0", "#f032e6", "#bcf60c", "#fabebe"]
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: modelData
                            border.color: root.fgColor
                            border.width: root.selectedColor === modelData ? 3 : 1
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.selectedColor = modelData
                            }
                        }
                    }
                }

                Label {
                    text: root.isPoint ? "Size:" : "Thickness:"
                    color: root.fgColor
                    font.bold: true
                    Layout.topMargin: 10
                }

                RowLayout {
                    Layout.fillWidth: true
                    Slider {
                        id: sizeSlider
                        from: 1
                        to: 20
                        value: root.isPoint ? 5 : 2
                        stepSize: 1
                        Layout.fillWidth: true
                    }
                    Label {
                        text: sizeSlider.value.toString()
                        color: root.fgColor
                        Layout.preferredWidth: 30
                    }
                }

                Label {
                    text: "Symbol / Style:"
                    color: root.fgColor
                    font.bold: true
                    Layout.topMargin: 10
                    visible: root.isPoint || root.isLine || root.isPoly
                }

                ComboBox {
                    id: styleCombo
                    Layout.fillWidth: true
                    model: {
                        if (root.isPoint) return ["Circle", "Square", "Triangle"]
                        if (root.isLine) return ["Solid", "Dashed", "Dotted"]
                        if (root.isPoly) return ["Solid Fill", "No Fill", "Diagonal Hatch"]
                        return ["Default"]
                    }
                    contentItem: Text {
                        text: styleCombo.displayText
                        color: root.fgColor
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                    background: Rectangle {
                        color: root.bgColor
                        border.color: root.borderColor
                        radius: 4
                    }
                }
            }

            Label {
                text: "Style settings are not applied when downloading into an existing layer."
                color: root.warningColor
                font.italic: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: root.isExistingLayer
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.borderColor
                Layout.topMargin: 10
                Layout.bottomMargin: 10
            }

            // --- BBOX ---
            Label {
                text: "Download Settings"
                font.pixelSize: 18
                font.bold: true
                color: root.fgColor
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: "Max Download Area (km²):"
                color: root.fgColor
                font.bold: true
            }

            TextField {
                id: bboxAreaInput
                text: "10"
                validator: DoubleValidator { bottom: 0; decimals: 2 }
                Layout.fillWidth: true
                color: root.fgColor
                background: Rectangle {
                    color: root.bgColor
                    border.color: root.borderColor
                    radius: 4
                }
            }

            Label {
                text: "Warning: Downloading areas larger than 10 km² may be slow or fail due to server limits."
                color: root.warningColor
                font.bold: true
                wrapMode: Label.WordWrap
                Layout.fillWidth: true
                visible: parseFloat(bboxAreaInput.text) > 10.0
            }

            Item { Layout.fillHeight: true } // Spacer

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: "Back"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    onClicked: {
                        root.backRequested();
                    }
                }

                Button {
                    text: "Save and Apply"
                    Layout.fillWidth: true
                    implicitHeight: 48
                    onClicked: {
                        var config = {
                            color: root.selectedColor,
                            sizeOrThickness: sizeSlider.value,
                            styleType: styleCombo.currentText
                        }
                        var area = parseFloat(bboxAreaInput.text) || 10.0;
                        root.applySettings(config, area);
                    }
                }
            }
        }
    }
}
