import QtQuick 2.12

Item {
    id: drawer
    property bool round: false
    property var bgcolor: "transparent"
    property string iconSource: ""
    property var iconColor: "transparent"
    
    // Allows us to nest children correctly inside the mock Drawer
    default property alias data: drawer.children
}
