import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.LocalStorage 2.0

ApplicationWindow {
    visible: true
    width: 400
    height: 400
    title: "Testing LocalStorage"

    Component.onCompleted: {
        try {
            var db = LocalStorage.openDatabaseSync("test_db", "1.0", "Test DB", 1000000);
            console.log("Database opened successfully: " + db);
            label.text = "Success: LocalStorage is available!";
            label.color = "green";
        } catch(e) {
            console.log("Database failed: " + e);
            label.text = "Error: " + e;
            label.color = "red";
        }
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: "Testing..."
        font.pixelSize: 20
    }
}
