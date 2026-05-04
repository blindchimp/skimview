import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform  // Required for FolderDialog
import Qt.labs.folderlistmodel // Required for scanning folders

ApplicationWindow {
    id: window
    visible: true
    width: 800
    height: 600
    title: "Image Viewer"

    property string fullImageUrl: ""
    property int gridCurrentIndex: -1

    // 1. The Dialog to pick a folder
    FolderDialog {
        id: folderDialog
        title: "Select an Image Folder"
        onAccepted: {
            folderModel.folder = folderDialog.folder
            fullImageUrl = "" // Close full view if open
        }
    }

    // 2. The Model that scans the folder
    FolderListModel {
        id: folderModel
        folder: "file:///." // Default starting path
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
    }

    header: ToolBar {
        background: Rectangle { color: "#1f1f1f" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10

            Button {
                text: "Open Folder"
                onClicked: folderDialog.open()
            }

            Label {
                text: folderModel.folder
                color: "white"
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#2b2b2b"

        GridView {
            id: gridView
            anchors.fill: parent
            visible: fullImageUrl === ""
            cellWidth: 150
            cellHeight: 150
            clip: true

            // Link the GridView to our FolderListModel
            model: folderModel

            delegate: Rectangle {
                width: gridView.cellWidth - 10
                height: gridView.cellHeight - 10
                color: "#3b3b3b"
                border.color: (model.index === gridCurrentIndex) ? "red" : "#555"
                border.width: (model.index === gridCurrentIndex) ? 2 : 1
                radius: 4

                Image {
                    id: thumb
                    anchors.centerIn: parent
                    width: parent.width - 4
                    height: parent.height - 4
                    // FolderListModel provides 'fileURL' for the source
                    source: model.fileUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    sourceSize.width: 200
                    sourceSize.height: 200
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        gridCurrentIndex = model.index
                        fullImageUrl = model.fileUrl
                    }
                }
            }
        }

        // Full Image View
        Image {
            id: fullImage
            anchors.fill: parent
            visible: fullImageUrl !== ""
            source: fullImageUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            // Background to hide the grid behind it
            Rectangle {
                anchors.fill: parent
                color: "black"
                z: -1
            }

            // Trash shortcut - press 'd' to move image to trash and load next image
            Shortcut {
                sequence: "d"
                enabled: fullImageUrl !== ""
                onActivated: {
                    trashHandler.moveToTrash(fullImageUrl)
                    // Reload thumbnails by reassigning folder
                    //var currentFolder = folderModel.folder
                    //folderModel.folder = "file:///tmp"  // Temp folder to force refresh
                    //folderModel.folder = currentFolder
                    // Load next image instead of going back to thumbnails
                    gridCurrentIndex = (gridCurrentIndex + 1) % folderModel.count
                    fullImageUrl = folderModel.get(gridCurrentIndex, "fileUrl")
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: folderModel.count === 0 && fullImageUrl === ""
            color: "#aaa"
            text: "No images found in folder"
            font.pixelSize: 16
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: fullImageUrl = ""
    }

    // Keyboard navigation in full image view
    Shortcut {
        sequence: "Left"
        enabled: fullImageUrl !== "" && folderModel.count > 0
        onActivated: {
            gridCurrentIndex = (gridCurrentIndex - 1 + folderModel.count) % folderModel.count
            fullImageUrl = folderModel.get(gridCurrentIndex, "fileUrl")
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: fullImageUrl !== "" && folderModel.count > 0
        onActivated: {
            gridCurrentIndex = (gridCurrentIndex + 1) % folderModel.count
            fullImageUrl = folderModel.get(gridCurrentIndex, "fileUrl")
        }
    }

    // Update gridCurrentIndex when opening a different image
    onFullImageUrlChanged: {
        if (fullImageUrl !== "") {
            for (var i = 0; i < folderModel.count; i++) {
                if (folderModel.get(i, "fileUrl") === fullImageUrl) {
                    gridCurrentIndex = i
                    break
                }
            }
        }
    }
}