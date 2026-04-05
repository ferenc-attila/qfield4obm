import QtQuick 2.12
import QtTest 1.12

// Import the main component
import "../../" as Plugin

Item {
    id: window
    width: 600
    height: 600

    property var mainComponent: null

    TestCase {
        name: "MainQmlTests"
        when: window.visible

        function initTestCase() {
            var component = Qt.createComponent("../../main.qml");
            if (component.status === Component.Ready) {
                mainComponent = component.createObject(window);
            } else {
                console.error("Error loading main.qml: " + component.errorString());
            }
        }

        function test_initialState() {
            verify(mainComponent !== null, "Main.qml should instantiate without errors");
            compare(mainComponent.pluginName, "QField4OBM", "Plugin name should match");
        }

        function test_proxyFunctions() {
            verify(typeof mainComponent._executeGpkgProxy === "function", "GPKG proxy function should exist");
            verify(typeof mainComponent._executeBboxProxy === "function", "BBOX proxy function should exist");
        }
    }
}
