// WARNING: vibe coded ca. 2026
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
    property real zoomScale: 1.0
    property real initialZoomScale: 1.0
    property real panX: 0
    property real panY: 0
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

    // Property for tag search mode
    property bool tagSearchMode: false

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
                    text: "Copy Path"
                    visible: gridCurrentIndex >= 0 && gridCurrentIndex < folderModel.count
                    onClicked: {
                        var fileUrl = folderModel.get(gridCurrentIndex, "fileUrl")
                        clipboardHandler.copyToClipboard(fileUrl)
                    }
                }

                Button {
                    text: "Zoom x2"
                    onClicked: {
                        if (fullImageUrl !== "") {
                            zoomScale = 2.0
                            panX = 0
                            panY = 0
                        }
                    }
                }

                Button {
                    text: "Zoom 1:1"
                    onClicked: {
                        if (fullImageUrl !== "") {
                            zoomScale = 1.0
                            panX = 0
                            panY = 0
                        }
                    }
                }

                Button {
                    text: "Zoom 1/2"
                    onClicked: {
                        if (fullImageUrl !== "") {
                            zoomScale = 0.5
                            panX = 0
                            panY = 0
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

                // Toggle between filename and tag search
                Button {
                    text: tagSearchMode ? "Tags" : "Name"
                    checkable: true
                    checked: tagSearchMode
                    onClicked: {
                        tagSearchMode = !tagSearchMode
                        searchField.placeholderText = tagSearchMode ? "Search tags..." : "Search filename..."
                        searchFilter = searchField.text
                        if (tagSearchMode)
                            doTagSearch(searchField.text)
                        else
                            updateFilters()
                    }
                }

                // Search filter
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search filename..."
                    onTextEdited: {
                        searchFilter = text
                        if (tagSearchMode)
                            doTagSearch(text)
                        else
                            updateFilters()
                    }
                }
            }

            // Fourth row: Date search
            RowLayout {
                Layout.fillWidth: true
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Label {
                    text: "Jump to date:"
                    color: "#aaaaaa"
                }

                TextField {
                    id: dateSearchField
                    Layout.fillWidth: true
                    placeholderText: "e.g. 2024-01-15, 'one month ago', '2 weeks ago', yesterday, today"
                    onAccepted: {
                        scrollToDate(text)
                    }
                }

                Button {
                    text: "Go"
                    onClicked: {
                        scrollToDate(dateSearchField.text)
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
            folderModel.nameFilters = [
                "*" + searchFilter + "*.png",
                "*" + searchFilter + "*.jpg",
                "*" + searchFilter + "*.jpeg",
                "*" + searchFilter + "*.webp"
            ]
        }
    }

    // Search by tags/OCR/description via SQLite tags.db
    function doTagSearch(query) {
        if (query.length === 0) {
            folderModel.nameFilters = ["*.png", "*.jpg", "*.jpeg", "*.webp"]
            return
        }
        var results = tagSearchHandler.search(folderModel.folder, query)
        if (results.length > 0)
            folderModel.nameFilters = results
        else
            folderModel.nameFilters = ["__no_match__"]
    }

    // Clamp pan to valid range based on zoom level
    function clampPan() {
        var maxX = Math.max(0, (fullImage.parent.width / 2) * (zoomScale - 1))
        var maxY = Math.max(0, (fullImage.parent.height / 2) * (zoomScale - 1))
        panX = Math.max(-maxX, Math.min(maxX, panX))
        panY = Math.max(-maxY, Math.min(maxY, panY))
    }

    // Parse date/delta-time input into a Date object
    function parseDateTime(input) {
        if (!input || input.trim().length === 0)
            return null

        input = input.trim().toLowerCase()

        // "today"
        if (input === "today")
            return new Date()

        // "yesterday"
        if (input === "yesterday") {
            var d = new Date()
            d.setDate(d.getDate() - 1)
            return new Date(d.getFullYear(), d.getMonth(), d.getDate())
        }

        // Date format: YYYY-MM-DD or YYYY/MM/DD
        var dateMatch = input.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/)
        if (dateMatch)
            return new Date(parseInt(dateMatch[1]), parseInt(dateMatch[2]) - 1, parseInt(dateMatch[3]))

        // Number words
        var numberWords = {
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "a": 1, "an": 1
        }

        // Delta-time: "<number> <unit> ago" or "<word> <unit> ago"
        var deltaMatch = input.match(/^(?:(\d+)\s*|(\w+)\s+)?(year|month|week|day)s?\s+ago$/)
        if (!deltaMatch)
            return null

        var num = deltaMatch[1] ? parseInt(deltaMatch[1]) : (deltaMatch[2] ? (numberWords[deltaMatch[2]] || null) : 1)
        if (num === null)
            return null

        var unit = deltaMatch[3]
        var result = new Date()
        switch (unit) {
        case "year":
            result.setFullYear(result.getFullYear() - num)
            break
        case "month":
            result.setMonth(result.getMonth() - num)
            break
        case "week":
            result.setDate(result.getDate() - num * 7)
            break
        case "day":
            result.setDate(result.getDate() - num)
            break
        }
        return result
    }

    // Find the index of the file whose modification time is closest to targetDate
    function findClosestIndex(targetDate) {
        if (!targetDate || folderModel.count === 0)
            return -1

        var targetTime = targetDate.getTime()
        var closestIdx = -1
        var closestDiff = Infinity

        for (var i = 0; i < folderModel.count; i++) {
            var fileDate = folderModel.get(i, "fileModified")
            if (!fileDate)
                continue
            var t = fileDate.getTime()
            if (isNaN(t))
                continue
            var diff = Math.abs(t - targetTime)
            if (diff < closestDiff) {
                closestDiff = diff
                closestIdx = i
            }
        }

        return closestIdx
    }

    // Parse input and scroll the grid to the closest matching file
    function scrollToDate(input) {
        if (!input || input.trim().length === 0)
            return

        var targetDate = parseDateTime(input)
        if (!targetDate) {
            return
        }

        var idx = findClosestIndex(targetDate)
        if (idx < 0)
            return

        gridCurrentIndex = idx
        gridView.currentIndex = idx
        gridView.positionViewAtIndex(idx, GridView.Center)
    }

    Rectangle {
        anchors.fill: parent
        color: "#2b2b2b"
        clip: true

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


        Image {
            id: fullImage
            x: panX
            y: panY
            width: parent.width
            height: parent.height
            source: fullImageUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: fullImageUrl !== ""
            scale: zoomScale

            PinchHandler {
                target: null
                onActiveChanged: {
                    if (active) {
                        initialZoomScale = zoomScale
                    }
                }
                onScaleChanged: {
                    zoomScale = Math.max(0.1, Math.min(10.0, initialZoomScale * scale))
                    clampPan()
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: zoomScale > 1.0
                cursorShape: !enabled ? Qt.ArrowCursor
                    : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

                property real startVpX: 0
                property real startVpY: 0
                property real startPanX: 0
                property real startPanY: 0

                onPressed: (mouse) => {
                    startVpX = mouse.x + panX
                    startVpY = mouse.y + panY
                    startPanX = panX
                    startPanY = panY
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var vpX = mouse.x + panX
                    var vpY = mouse.y + panY
                    panX = startPanX + (vpX - startVpX)
                    panY = startPanY + (vpY - startVpY)
                    clampPan()
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
        } else {
            zoomScale = 1.0
            panX = 0
            panY = 0
        }
    }
}
