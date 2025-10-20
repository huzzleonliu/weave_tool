import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

Window {
    id: dlg
    width: 520
    height: 420
    visible: true
    title: "阈值与映射配置 (Threshold & Mapping Configuration)"
    
    Rectangle {
        anchors.fill: parent
        color: "#2b2f33" // 较暗的背景色
    }

    // 段数（0-7）。确认按钮点击后生效
    property int segmentCount: 0
    // 每段对应一个滑块位置（0-255），数组长度 == segmentCount
    property var segmentStops: []
    // 映射模式：true为平均模式，false为分段模式
    property bool averageMode: true

    signal confirmed(var stops, bool isAverageMode) // 确认下方按钮时发出，stops为[0..255]数组，isAverageMode为映射模式

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
            spacing: 8
            TextField {
                id: countInput
                width: 120
                placeholderText: "0-7 (0-7)"
                validator: IntValidator { bottom: 0; top: 7 }
                text: "0"
            }
            Button {
                text: "设定段数 (Set Segments)"
                onClicked: {
                    var n = parseInt(countInput.text);
                    if (isNaN(n) || n < 0 || n > 7) return;
                    segmentCount = n;
                    segmentStops = [];
                    for (var i = 0; i < segmentCount; i++) {
                        // 生成初值，均匀分布于[0,255]
                        segmentStops.push(Math.round(i * 255 / Math.max(1, segmentCount - 1)));
                    }
                }
            }
        }

        // 单个滑动条，包含可变数量的滑块
        Rectangle {
            width: parent.width
            height: 60
            color: "#3c4043"
            border.color: "#5f6368"
            border.width: 1
            radius: 4
            
            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                color: "#e8eaed"
                text: "阈值滑动条 (0-255) (Threshold Slider 0-255)"
            }
            
            Rectangle {
                id: sliderTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 30
                anchors.margins: 20
                height: 20
                radius: 2
                
                // 黑到白的水平渐变填充
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#000000" }
                    GradientStop { position: 1.0; color: "#ffffff" }
                }
                
                // 边框
                border.color: "#5f6368"
                border.width: 1
                
                // 动态生成滑块
                Repeater {
                    model: segmentCount
                    delegate: Rectangle {
                        width: 16
                        height: 28
                        radius: 2
                        color: "#4285f4"
                        border.color: "#669df6"
                        border.width: 2
                        y: -4
                        x: (segmentStops[index] / 255.0) * (parent.width - width)
                        
                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            drag.axis: Drag.XAxis
                            drag.minimumX: 0
                            drag.maximumX: sliderTrack.width - parent.width
                            onPositionChanged: {
                                var newValue = Math.round((parent.x / (sliderTrack.width - parent.width)) * 255)
                                newValue = Math.max(0, Math.min(255, newValue))
                                segmentStops[index] = newValue
                                // 强制更新显示
                                dlg.segmentStops = dlg.segmentStops.slice()
                            }
                        }
                        
                        Text {
                            anchors.top: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 2
                            color: "#ffffff"
                            text: segmentStops[index] || 0
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }
        }

        // 映射模式选择
        Row {
            spacing: 16
            Text {
                color: "#e8eaed"
                text: "映射模式： (Mapping Mode:)"
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Rectangle {
                width: averageText.implicitWidth + 16; height: 32
                radius: 4
                color: averageMode ? "#1e8e3e" : "#3c4043"
                border.color: averageMode ? "#34a853" : "#5f6368"
                Text { 
                    id: averageText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "平均 (Average)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: averageMode = true
                }
            }
            
            Rectangle {
                width: segmentText.implicitWidth + 16; height: 32
                radius: 4
                color: !averageMode ? "#1e8e3e" : "#3c4043"
                border.color: !averageMode ? "#34a853" : "#5f6368"
                Text { 
                    id: segmentText
                    anchors.centerIn: parent
                    color: "#e8eaed"
                    text: "分段 (Segment)"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: averageMode = false
                }
            }
        }

        Button {
            text: "确认映射 (Confirm Mapping)"
            onClicked: {
                // 输出排序后的 stops，确保从小到大
                var sorted = segmentStops.slice(0).sort(function(a, b){ return a - b; });
                dlg.confirmed(sorted, averageMode);
                // 不关闭窗口，保持打开状态
            }
        }
    }
}


