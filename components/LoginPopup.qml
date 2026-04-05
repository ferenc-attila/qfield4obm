import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import org.qfield 1.0
import "../scripts/AuthManager.js" as AuthManager
import "../scripts/ApiClient.js" as ApiClient
import "../scripts/SyncEngine.js" as SyncEngine
import "../scripts/Utils.js" as Utils

// A simple UI popup for logging in, utilizing QField theme logic where possible
Popup {
    id: loginPopup
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

    // UI State: 0 = Enter Server URL, 1 = Select Project & Login
    property int step: 0
    property var projectsList: []

    // Reset UI state every time the popup opens
    onOpened: {
        if (pluginSettings.isLoggedIn) {
            statusLabel.text = "Status: Logged in to " + pluginSettings.projectName;
            statusLabel.color = "green";
        } else {
            statusLabel.text = "Status: Not logged in";
            statusLabel.color = "red";
            loginPopup.step = 0;
        }
    }

    background: Rectangle {
        color: loginPopup.bgColor
        radius: 8
        border.color: loginPopup.borderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Label {
            text: loginPopup.step === 0 ? "Step 1: Connect to Server" : "Step 2: Login to Project"
            font.pixelSize: 20
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: loginPopup.borderColor
            opacity: 0.3
        }

        // --- STEP 0: SERVER URL ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: loginPopup.step === 0

            Label {
                text: "Server URL:"
                color: loginPopup.fgColor
            }
            TextField {
                id: urlField
                Layout.fillWidth: true
                placeholderText: "https://openbiomaps.org"
                text: AuthManager.getBaseUrl()
                color: loginPopup.fgColor
                leftPadding: 10
            }
        }

        // --- STEP 1: PROJECT & CREDENTIALS ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: loginPopup.step === 1

            Label {
                text: "Select Project:"
                color: loginPopup.fgColor
            }
            ComboBox {
                id: projectCombo
                Layout.fillWidth: true
                model: loginPopup.projectsList
                textRole: "name" // Using 'name' from the OBM server json API

                contentItem: Text {
                    text: projectCombo.displayText
                    color: loginPopup.fgColor
                    font: projectCombo.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    leftPadding: 10
                }

                // Override the popup menu to ensure the background isn't transparent/black
                popup: Popup {
                    y: projectCombo.height - 1
                    width: projectCombo.width
                    // Cap the height so it doesn't spill out of the popup dialog or the screen
                    implicitHeight: Math.min(contentItem.implicitHeight, loginPopup.height - projectCombo.y - 60)
                    padding: 1

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: projectCombo.popup.visible ? projectCombo.delegateModel : null
                        currentIndex: projectCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }

                    background: Rectangle {
                        color: loginPopup.bgColor
                        border.color: loginPopup.borderColor
                        radius: 2
                    }
                }

                delegate: ItemDelegate {
                    width: projectCombo.width

                    background: Rectangle {
                        color: projectCombo.highlightedIndex === index ?
                            ((typeof Theme !== "undefined" && typeof Theme.mainColorSemiOpaque !== "undefined") ? Theme.mainColorSemiOpaque : "#e0e0e0")
                            : "transparent"
                    }

                    contentItem: Text {
                        text: typeof modelData !== "undefined" && modelData.name ? modelData.name : ""
                        color: loginPopup.fgColor
                        font: projectCombo.font
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                    highlighted: projectCombo.highlightedIndex === index
                }
            }

            Label {
                text: "Username:"
                color: loginPopup.fgColor
                Layout.topMargin: 10
            }
            TextField {
                id: usernameField
                Layout.fillWidth: true
                placeholderText: "Username"
                color: loginPopup.fgColor
                leftPadding: 10
            }

            Label {
                text: "Password:"
                color: loginPopup.fgColor
            }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: loginPopup.fgColor
                leftPadding: 10
            }
        }

        Label {
            id: statusLabel
            text: "Status: Not logged in"
            color: "red"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true } // Spacer

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: pluginSettings.isLoggedIn ? "Logout" : "Cancel"
                Layout.fillWidth: true
                implicitHeight: 48
                onClicked: {
                    if (pluginSettings.isLoggedIn) {
                        AuthManager.logout();
                        pluginSettings.isLoggedIn = false;
                        loginPopup.step = 0;
                        statusLabel.text = "Status: Not logged in"
                        statusLabel.color = "red"
                    } else {
                        if (loginPopup.step === 1) {
                            loginPopup.step = 0; // go back
                            statusLabel.text = "";
                        } else {
                            loginPopup.close();
                        }
                    }
                }
            }

            Button {
                text: loginPopup.step === 0 ? "Get Projects" : "Login"
                Layout.fillWidth: true
                implicitHeight: 48
                enabled: !pluginSettings.isLoggedIn
                onClicked: {
                    if (loginPopup.step === 0) {
                        // Fetch Projects logic
                        var currentUrl = urlField.text.trim();
                        if (currentUrl === "") currentUrl = "https://openbiomaps.org";
                        AuthManager.setBaseUrl(currentUrl);

                        statusLabel.text = "Fetching projects...";
                        statusLabel.color = loginPopup.fgColor;

                        AuthManager.fetchProjects(function(success, response) {
                            if (success) {
                                loginPopup.projectsList = response.data;
                                loginPopup.step = 1;
                                statusLabel.text = "Select a project to continue.";
                                statusLabel.color = loginPopup.fgColor;
                            } else {
                                statusLabel.text = "Error: " + response;
                                statusLabel.color = "red";
                            }
                        });
                    } else if (loginPopup.step === 1) {
                        // Login logic
                        statusLabel.text = "Logging in...";
                        statusLabel.color = loginPopup.fgColor;

                        var selectedProjObj = loginPopup.projectsList[projectCombo.currentIndex];
                        // The table identifier used in API URLs
                        var projectTable = selectedProjObj.project_table || selectedProjObj.table_name;
                        // The human-readable display name
                        var projectName = selectedProjObj.name || projectTable;

                        AuthManager.login(usernameField.text, passwordField.text, projectTable, projectName, function(success, response) {
                            if (success) {
                                pluginSettings.isLoggedIn = true;
                                statusLabel.text = "Successfully connected to " + projectName + "!";
                                statusLabel.color = "green";
                                loginPopup.close(); // Auto-close on successful UI
                            } else {
                                statusLabel.text = "Error: " + response;
                                statusLabel.color = "red";
                            }
                        });
                    }
                }
            }
        }
    }
}
