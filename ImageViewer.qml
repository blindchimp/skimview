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
        sortField: currentSortField
        sortReversed: !sortAscending
    }

    // Set initial folder when component is completed
    Component.onCompleted: {
        if (initialFolder !== "") {
            folderModel.folder = initialFolder
        }
    }

    // Properties for sort control
    property int currentSortField: FolderListModel.Name
    property bool sortAscending: true

    // Property for search filter
    property string searchFilter: ""

    header: ToolBar {
        background: Rectangle { color: "#1f1f1f" }
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top row: Open button, folder path, copy button
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Button {
                    text: "Open Folder"
                    onClicked: folderDialog.open()
                }

                Label {
                    id: folderPathLabel
                    text: folderModel.folder
                    color: "white"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                Button {
                    text: "Copy Name"
                    visible: gridCurrentIndex >= 0 && gridCurrentIndex < folderModel.count
                    onClicked: {
                        var filename = folderModel.get(gridCurrentIndex, "fileName")
                        Qt.application.clipboard = filename
                    }
                }

                Button {
                    text: "Zoom x2"
                    onClicked: {
                        if (fullImageUrl !== "") {
                            pinchArea.zoomScale = 2.0
                        }
                    }
                }

                Button {
                    text: "Zoom 1:1"
                    onClicked: {
                        if (fullImageUrl !== "") {
                            pinchArea.zoomScale = 1.0
                        }
                    }
                }

                Button {
                    text: "Zoom 1/2"
                    onClicked: {
                        if (fullImageUrl !== "") {
                            pinchArea.zoomScale = 0.5
                        }
                    }
                }
            }

            // Second row: Current filename display
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Label {
                    text: gridCurrentIndex >= 0 && gridCurrentIndex < folderModel.count
                        ? folderModel.get(gridCurrentIndex, "fileName")
                        : ""
                    color: "#aaaaaa"
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    font.bold: true
                }
            }

            // Third row: Sort buttons and search
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                // Sort by name
                Button {
                    text: currentSortField === FolderListModel.Name ? (sortAscending ? "Name Asc" : "Name Desc")
                                                                      : "Name"
                    onClicked: {
                        currentSortField = FolderListModel.Name
                    }
                }

                // Sort by date
                Button {
                    text: currentSortField === FolderListModel.Time ? (sortAscending ? "Date Asc" : "Date Desc")
                                                                      : "Date"
                    onClicked: {
                        currentSortField = FolderListModel.Time
                    }
                }

                // Toggle sort order
                Button {
                    text: sortAscending ? "Ascending" : "Descending"
                    onClicked: sortAscending = !sortAscending
                }

                // Search filter
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search filename..."
                    onTextEdited: {
                        searchFilter = text
                        updateFilters()
                    }
                }
            }
        }
    }

    // Function to update folder model filters
    function updateFilters() {
        if (searchFilter.length === 0) {
            folderModel.nameFilters = ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        } else {
            // Create a filter that matches files containing the search text
            // FolderListModel supports wildcards with *
            var pattern = "*" + searchFilter + "*"
            folderModel.nameFilters = [pattern, "*.png", "*.jpg", "*.jpeg", "*.webp"]
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

        // Full Image View with zoom
        PinchArea {
            id: pinchArea
            anchors.fill: parent
            enabled: fullImageUrl !== ""

            property real zoomScale: 1.0
            property real minScale: 0.25
            property real maxScale: 4.0

            onPinchUpdated: {
                var newScale = pinchArea.zoomScale * pinch.scale
                pinchArea.zoomScale = Math.max(pinchArea.minScale, Math.min(pinchArea.maxScale, newScale))
            }

            onPinchFinished: {
                pinchArea.zoomScale = Math.max(pinchArea.minScale, Math.min(pinchArea.maxScale, pinchArea.zoomScale))
            }

            Image {
                id: fullImage
                anchors.fill: parent
                source: fullImageUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: true

                transform: Scale {
                    id: imageScale
                    origin.x: fullImage.width / 2
                    origin.y: fullImage.height / 2
                    xScale: pinchArea.zoomScale
                    yScale: pinchArea.zoomScale
                }
            }

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