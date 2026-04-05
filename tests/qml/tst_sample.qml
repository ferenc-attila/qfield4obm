import QtQuick 2.15
import QtTest 1.15

TestCase {
    name: "SampleQMLTest"

    function test_math() {
        compare(1 + 1, 2, "Basic math should work in QML");
    }
}
