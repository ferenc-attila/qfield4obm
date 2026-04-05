pragma Singleton
import QtQuick 2.12

QtObject {
    property color controlBackgroundColor: "#ffffff"
    property color mainTextColor: "#000000"
    property color controlBorderColor: "#cccccc"
    property color primaryColor: "#007bff"
    function getThemeIcon(name) {
        return ""
    }
}
