import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 800
    height: 600
    title: "Image Viewer"

    property var fullImageUrl: ""

    Rectangle {
        anchors.fill: parent
        color: "#2b2b2b"

        GridView {
            id: gridView
            anchors.fill: parent
            visible: fullImageUrl === ""
            cellWidth: 150
            cellHeight: 150

            model: imageUrls

            delegate: Rectangle {
                width: gridView.cellWidth - 10
                height: gridView.cellHeight - 10
                color: "#3b3b3b"
                border.color: "#555"
                border.width: 1
                radius: 4

                Image {
                    id: thumb
                    anchors.centerIn: parent
                    width: parent.width - 4
                    height: parent.height - 4
                    source: modelData
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 200
                    sourceSize.height: 200
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: fullImageUrl = modelData
                }
            }
        }

        Image {
            id: fullImage
            anchors.fill: parent
            visible: fullImageUrl !== ""
            source: fullImageUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: imageUrls.length === 0 && fullImageUrl === ""
            color: "#aaa"
            text: "No images found in folder"
            font.pixelSize: 16
        }
    }

    focus: true
    Keys.onEscapePressed: {
        fullImageUrl = ""
    }
}