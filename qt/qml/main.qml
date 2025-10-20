import QtQuick 2.0
import QtQuick.Window 2.0
import Qt.labs.platform 1.1 as Labs

// 主窗口：提供缩放、滚动查看 PNG 的能力；底部提供处理与保存按钮
Window {
    id: win
    width: 960
    height: 720
    visible: true
    title: "PNG 查看器 (PNG Viewer)"

    property real zoom: 1.0
    property string currentPath: typeof argvPath !== 'undefined' ? argvPath : ""
    property int cacheBust: 0

    // 当后端报告 image_path 变化时，更新一次 cacheBust 以强制刷新 Image 源
    Connections {
        target: viewer
        function onImage_pathChanged() { cacheBust = cacheBust + 1 }
    }

    Rectangle {
        anchors.fill: parent
        color: "#202124"

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: Math.max(content.width, flick.width)
            contentHeight: Math.max(content.height, flick.height)
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: content
                width: img.implicitWidth * win.zoom
                height: img.implicitHeight * win.zoom
                x: width < flick.width ? (flick.width - width) / 2 : 0
                y: height < flick.height ? (flick.height - height) / 2 : 0

                // 棋盘格背景：便于观察透明像素区域
                Rectangle {
                    id: checkerboard
                    anchors.fill: parent
                    color: "#ffffff"
                    
                    // 使用Canvas绘制棋盘格
                    Canvas {
                        id: checkerboardCanvas
                        anchors.fill: parent
                        smooth: false  // 禁用抗锯齿，确保像素边缘清晰
                        
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            
                            // 禁用抗锯齿
                            ctx.imageSmoothingEnabled = false
                            
                            var tileSize = 16
                            var cols = Math.ceil(width / tileSize)
                            var rows = Math.ceil(height / tileSize)
                            
                            for (var row = 0; row < rows; row++) {
                                for (var col = 0; col < cols; col++) {
                                    if ((row + col) % 2 === 0) {
                                        ctx.fillStyle = "#ffffff"
                                    } else {
                                        ctx.fillStyle = "#e0e0e0"
                                    }
                                    // 确保像素对齐，避免亚像素渲染
                                    var x = Math.floor(col * tileSize)
                                    var y = Math.floor(row * tileSize)
                                    var w = Math.ceil(tileSize)
                                    var h = Math.ceil(tileSize)
                                    ctx.fillRect(x, y, w, h)
                                }
                            }
                        }
                        
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                    }
                }

                // 实际展示的图片：优先显示 display_path（临时处理结果），否则显示原图
                Image {
                    id: img
                    anchors.fill: parent
                    cache: false
                    fillMode: Image.Stretch
                    source: viewer.display_path && viewer.display_path.length > 0 ? ("file:///" + viewer.display_path + "?v=" + win.cacheBust) : (viewer.image_path && viewer.image_path.length > 0 ? ("file:///" + viewer.image_path + "?v=" + win.cacheBust) : "")
                    smooth: false
                    antialiasing: false
                    onStatusChanged: {
                        if (status === Image.Error) {
                            console.error("Image load error:", source, errorString)
                        }
                        console.log("Image status:", status, "source:", source)
                    }
                    Component.onCompleted: console.log("Image completed, source:", source)
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onWheel: function(event) {
                    var oldZoom = win.zoom
                    var factor = event.angleDelta.y > 0 ? 1.1 : 1/1.1
                    var newZoom = Math.max(0.05, Math.min(20, oldZoom * factor))
                    if (newZoom === oldZoom) return

                    var px = content.x + flick.contentX + event.x
                    var py = content.y + flick.contentY + event.y
                    win.zoom = newZoom
                    var scale = newZoom / oldZoom
                    var nx = px * scale - event.x
                    var ny = py * scale - event.y
                    var maxX = Math.max(0, flick.contentWidth - flick.width)
                    var maxY = Math.max(0, flick.contentHeight - flick.height)
                    if (nx < 0) nx = 0
                    if (ny < 0) ny = 0
                    if (nx > maxX) nx = maxX
                    if (ny > maxY) ny = maxY
                    flick.contentX = nx
                    flick.contentY = ny
                    event.accepted = true
                }
            }

            Text {
                anchors.centerIn: parent
                color: "#80868b"
                text: img.status === Image.Error ? ("加载失败 (Load Failed): " + img.errorString) : ((viewer.image_path && viewer.image_path.length === 0) ? "未加载图片 (No Image Loaded)" : (img.status === Image.Loading ? "加载中... (Loading...)" : ""))
                visible: text.length > 0
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                color: "#9aa0a6"
                text: "path=" + win.currentPath + "\nsource=" + img.source
            }

            Rectangle {
                id: refreshBtn
                width: refreshText.implicitWidth + 16; height: 32
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                radius: 4
                color: "#3c4043"
                border.color: "#5f6368"
                Text { 
                    id: refreshText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "刷新 (Refresh)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { viewer.refresh_display(); win.cacheBust = win.cacheBust + 1 }
                }
            }

            Rectangle {
                id: openBtn
                width: openText.implicitWidth + 16; height: 32
                anchors.left: refreshBtn.right
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                radius: 4
                color: "#3c4043"
                border.color: "#5f6368"
                Text { 
                    id: openText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "打开 (Open)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: fileDialog.open()
                }
            }

            Rectangle {
                id: saveBtn
                width: saveText.implicitWidth + 16; height: 32
                anchors.left: openBtn.right
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                radius: 4
                color: viewer.has_pending ? "#1a73e8" : "#3c4043"
                border.color: viewer.has_pending ? "#4285f4" : "#5f6368"
                opacity: viewer.has_pending ? 1.0 : 0.6
                Text { 
                    id: saveText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "保存 (Save)"
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: viewer.has_pending
                    onClicked: {
                        viewer.save_processed()
                        win.cacheBust = win.cacheBust + 1
                    }
                }
            }

            Rectangle {
                id: preprocessBtn
                width: preprocessText.implicitWidth + 16; height: 32
                anchors.left: saveBtn.right
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                radius: 4
                color: "#3c4043"
                border.color: "#5f6368"
                Text { 
                    id: preprocessText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "灰色预览 (Gray Preview)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        viewer.gray_preview()
                        if (viewer.has_pending) { win.cacheBust = win.cacheBust + 1 }
                    }
                }
            }

            Rectangle {
                id: openThresholdBtn
                width: thresholdText.implicitWidth + 16; height: 32
                anchors.left: preprocessBtn.right
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                radius: 4
                color: "#3c4043"
                border.color: "#5f6368"
                Text { 
                    id: thresholdText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "阈值窗口 (Threshold)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var w = Qt.createComponent("qrc:/qml/ThresholdWindow.qml").createObject(win)
                        if (w) {
                            w.confirmed.connect(function(stops, isAverageMode){
                                console.log("阈值段数:", stops.length, "stops:", stops, "平均模式:", isAverageMode)
                                // 将 stops 数组和映射模式转换为 JSON 字符串传给 Rust
                                var data = {
                                    stops: stops,
                                    averageMode: isAverageMode
                                }
                                var jsonStr = JSON.stringify(data)
                                viewer.apply_threshold_mapping(jsonStr)
                                win.cacheBust = win.cacheBust + 1
                            })
                            w.visible = true
                        }
                    }
                }
            }

            Rectangle {
                id: cleanupBtn
                width: cleanupText.implicitWidth + 16; height: 32
                anchors.left: openThresholdBtn.right
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                radius: 4
                color: "#3c4043"
                border.color: "#5f6368"
                Text { 
                    id: cleanupText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "清理散点 (Clean)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        viewer.cleanup_scattered_pixels()
                        if (viewer.has_pending) { win.cacheBust = win.cacheBust + 1 }
                    }
                }
            }

            Keys.onPressed: {
                if (event.key === Qt.Key_Plus || event.text === "+") { win.zoom = Math.min(win.zoom * 1.1, 20); event.accepted = true }
                else if (event.key === Qt.Key_Minus || event.text === "-") { win.zoom = Math.max(win.zoom / 1.1, 0.05); event.accepted = true }
                else if (event.key === Qt.Key_0) { win.zoom = 1.0; event.accepted = true }
                else if (event.key === Qt.Key_Escape) { colorWin.visible = false }
            }
            focus: true
        }
    }

    Window {
        id: colorWin
        width: 360; height: 240
        title: "颜色映射 (Color Mapping)"
        visible: false
        modality: Qt.NonModal
        flags: Qt.Dialog

        Rectangle { anchors.fill: parent; color: "#2b2f33" }
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            Text { color: "#e8eaed"; text: "颜色映射占位（后续添加滑块）(Color Mapping Placeholder - Sliders to be added later)" }
        }
    }

    Labs.FileDialog {
        id: fileDialog
        title: "选择 PNG 文件 (Select PNG File)"
        fileMode: Labs.FileDialog.OpenFile
        nameFilters: ["PNG Files (*.png)"]
        onAccepted: {
            if (!file) return
            var url = file
            var p = url.toLocalFile ? url.toLocalFile() : url.toString()
            if (p.startsWith("file://")) {
                p = p.replace("file://", "")
            }
            viewer.set_image_path(p)
            win.cacheBust = win.cacheBust + 1
        }
    }
}


