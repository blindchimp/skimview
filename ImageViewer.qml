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
    // Property to receive initial folder from C++ (as QUrl string)
    //property var initialFolder: null

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
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
    }

    // Set initial folder when component is completed
    Component.onCompleted: {
        if (initialFolder !== "") {
            folderModel.folder = initialFolder
        }
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
            focus: true
            interactive: false

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

            // Keyboard navigation
            Keys.onLeftPressed: {
                if (folderModel.count > 0) {
                    gridCurrentIndex = (gridCurrentIndex - 1 + folderModel.count) % folderModel.count
                    gridView.currentIndex = gridCurrentIndex
                    gridView.positionViewAtIndex(gridCurrentIndex, GridView.Contain)
                }
            }
            Keys.onRightPressed: {
                if (folderModel.count > 0) {
                    gridCurrentIndex = (gridCurrentIndex + 1) % folderModel.count
                    gridView.currentIndex = gridCurrentIndex
                    gridView.positionViewAtIndex(gridCurrentIndex, GridView.Contain)
                }
            }
            Keys.onUpPressed: {
                if (folderModel.count > 0) {
                    // Calculate number of columns based on grid width
                    var cols = Math.floor((gridView.width + 10) / 150)
                    if (cols > 0) {
                        gridCurrentIndex = (gridCurrentIndex - cols + folderModel.count) % folderModel.count
                        gridView.currentIndex = gridCurrentIndex
                        gridView.positionViewAtIndex(gridCurrentIndex, GridView.Contain)
                    }
                }
            }
            Keys.onDownPressed: {
                if (folderModel.count > 0) {
                    // Calculate number of columns based on grid width
                    var cols = Math.floor((gridView.width + 10) / 150)
                    if (cols > 0) {
                        gridCurrentIndex = (gridCurrentIndex + cols) % folderModel.count
                        gridView.currentIndex = gridCurrentIndex
                        gridView.positionViewAtIndex(gridCurrentIndex, GridView.Contain)
                    }
                }
            }
            Keys.onEnterPressed: {
                if (gridCurrentIndex >= 0 && gridCurrentIndex < folderModel.count) {
                    fullImageUrl = folderModel.get(gridCurrentIndex, "fileUrl")
                }
            }
            Keys.onSpacePressed: {
                if (gridCurrentIndex >= 0 && gridCurrentIndex < folderModel.count) {
                    fullImageUrl = folderModel.get(gridCurrentIndex, "fileUrl")
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
        }

        Text {
            anchors.centerIn: parent
            visible: folderModel.count === 0 && fullImageUrl === ""
            color: "#aaa"
            text: "No images found in folder"
            font.pixelSize: 16
        }
    }

    // Global shortcuts
    Shortcut {
        sequence: "Escape"
        onActivated: fullImageUrl = ""
    }

    // Keyboard navigation in thumbnail grid
    Shortcut {
        sequence: "Left"
        enabled: fullImageUrl === "" && folderModel.count > 0
        onActivated: {
            gridCurrentIndex = (gridCurrentIndex - 1 + folderModel.count) % folderModel.count
            gridView.currentIndex = gridCurrentIndex
            gridView.positionViewAtIndex(gridCurrentIndex, GridView.Contain)
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: fullImageUrl === "" && folderModel.count > 0
        onActivated: {
            gridCurrentIndex = (gridCurrentIndex + 1) % folderModel.count
            gridView.currentIndex = gridCurrentIndex
            gridView.positionViewAtIndex(gridCurrentIndex, GridView.Contain)
        }
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

    // Trash shortcut - press 'd' to move image to trash and load next image
    Shortcut {
        sequence: "d"
        enabled: fullImageUrl !== ""
        onActivated: {
            trashHandler.moveToTrash(fullImageUrl)
            // Load next image instead of going back to thumbnails
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