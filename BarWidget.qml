import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

/*  Alisupen – BarWidget.qml
 *  Top-bar widget shown in the Noctalia Shell panel.
 *  Displays a compact update-count badge; clicking opens a dropdown
 *  panel with category counters, the update queue, and action buttons.
 *
 *  Integrates with Main.qml via property bindings and signal connections.
 *  Uses Catppuccin Mocha palette for consistent dark-theme styling.
 */

MouseArea {
    id: root

    // ── Public API (bound by Noctalia Shell from Main.qml) ────
    property int    pacmanCount: 0
    property int    aurCount: 0
    property int    flatpakCount: 0
    property var    pendingPackages: []   // [{name, version, source, size}]
    property bool   isRefreshing: false
    property bool   isUpdating: false
    property string statusMessage: "Idle"
    property real   updateProgress: 0.0   // 0.0 → 1.0

    // ── Signals ──────────────────────────────────────────────
    signal requestRefresh()
    signal requestUpdateAll()
    signal requestUpdateCategory(string category)
    signal requestRemoveLock()
    signal requestUpdatePackage(string pkgName, string source)

    // ── Internal ─────────────────────────────────────────────
    property bool panelOpen: false
    property int  totalCount: pacmanCount + aurCount + flatpakCount
    property string filterText: ""

    // ── Dimensions ───────────────────────────────────────────
    implicitWidth:  badgeRow.width + 16
    implicitHeight: 32

    hoverEnabled: true

    // ── Animation for refresh indicator ───────────────────────
    SequentialAnimation on opacity {
        running: root.isRefreshing
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.5; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.5; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
    }

    // ═══════════════════════════════════════════════════════════
    //  Badge in the top bar
    // ═══════════════════════════════════════════════════════════
    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 6

        // Update icon (canvas glyph)
        Canvas {
            id: updateIcon
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = root.panelOpen ? "#cba6f7" :
                                  root.totalCount > 0 ? "#f38ba8" : "#cdd6f4"
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                // Circular arrow
                ctx.beginPath()
                ctx.arc(8, 8, 6, -Math.PI * 0.3, Math.PI * 1.2)
                ctx.stroke()
                // Arrow tip
                ctx.beginPath()
                ctx.moveTo(5.2, 1.6)
                ctx.lineTo(8.8, 2.8)
                ctx.lineTo(6.2, 5.4)
                ctx.stroke()
            }
        }

        // Count label
        Text {
            id: countLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.isRefreshing ? "…" :
                  root.totalCount > 0 ? root.totalCount.toString() : "OK"
            color: root.isRefreshing ? "#f9e2af" :
                   root.totalCount > 0 ? "#f38ba8" : "#a6e3a1"
            font.pixelSize: 13
            font.bold: true
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Dropdown panel
    // ═══════════════════════════════════════════════════════════
    Popup {
        id: dropdown
        y: root.height + 4
        x: -(width - root.width) / 2

        width: 400
        height: panelContent.implicitHeight + 24
        padding: 12

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: root.panelOpen

        onClosed: root.panelOpen = false

        background: Rectangle {
            color: "#1e1e2e"
            radius: 12
            border.color: "#313244"
            border.width: 1
        }

        ColumnLayout {
            id: panelContent
            anchors.fill: parent
            spacing: 8

            // ── Header ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Alisupen"
                    color: "#cba6f7"
                    font.pixelSize: 16
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Status pill
                Rectangle {
                    radius: 8
                    height: 20
                    width: statusPill.width + 12
                    color: root.isRefreshing ? "#f9e2af20" :
                           root.totalCount > 0 ? "#f38ba820" : "#a6e3a120"

                    Row {
                        id: statusPill
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root.isRefreshing ? "#f9e2af" :
                                   root.totalCount > 0 ? "#f38ba8" : "#a6e3a1"
                            anchors.verticalCenter: parent.verticalCenter

                            // Pulse animation for refreshing state
                            SequentialAnimation on scale {
                                running: root.isRefreshing
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 1.5; duration: 500 }
                                NumberAnimation { from: 1.5; to: 1.0; duration: 500 }
                            }
                        }

                        Text {
                            text: root.isRefreshing ? "Checking…" :
                                  root.totalCount > 0 ?
                                      qsTr("%n update(s)", "", root.totalCount) :
                                      "Up to date"
                            color: root.isRefreshing ? "#f9e2af" :
                                   root.totalCount > 0 ? "#f38ba8" : "#a6e3a1"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }
            }

            // ── Progress bar (visible during update) ──────────
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: "#313244"
                visible: root.isUpdating

                Rectangle {
                    width: root.updateProgress * parent.width
                    height: parent.height
                    radius: 2
                    color: "#cba6f7"

                    // Animated shimmer when indeterminate
                    SequentialAnimation on width {
                        running: root.isUpdating && root.updateProgress <= 0
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 400; duration: 1500 }
                    }
                }
            }

            // ── Category counters ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                CategoryBadge {
                    label: "Pacman"
                    count: root.pacmanCount
                    badgeColor: "#89b4fa"
                    iconChar: "P"
                    onClicked: root.requestUpdateCategory("pacman")
                }
                CategoryBadge {
                    label: "AUR"
                    count: root.aurCount
                    badgeColor: "#cba6f7"
                    iconChar: "A"
                    onClicked: root.requestUpdateCategory("aur")
                }
                CategoryBadge {
                    label: "Flatpak"
                    count: root.flatpakCount
                    badgeColor: "#94e2d5"
                    iconChar: "F"
                    onClicked: root.requestUpdateCategory("flatpak")
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // ── Action buttons ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ActionButton {
                    label: "Refresh"
                    iconChar: "↻"
                    accent: false
                    enabled: !root.isRefreshing && !root.isUpdating
                    onClicked: root.requestRefresh()
                }
                ActionButton {
                    label: "Update All"
                    iconChar: "⬆"
                    accent: true
                    enabled: root.totalCount > 0 && !root.isRefreshing && !root.isUpdating
                    onClicked: root.requestUpdateAll()
                }
                ActionButton {
                    label: "Rm Lock"
                    iconChar: "⊗"
                    accent: false
                    enabled: !root.isUpdating
                    onClicked: root.requestRemoveLock()
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // ── Update queue header + search ───────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Update Queue"
                    color: "#bac2de"
                    font.pixelSize: 12
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Search / filter box
                TextField {
                    id: searchField
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 24
                    placeholderText: "Filter…"
                    placeholderTextColor: "#6c7086"
                    color: "#cdd6f4"
                    font.pixelSize: 11
                    leftPadding: 6
                    rightPadding: 6
                    topPadding: 2
                    bottomPadding: 2

                    background: Rectangle {
                        radius: 4
                        color: "#181825"
                        border.color: searchField.activeFocus ? "#cba6f7" : "#313244"
                        border.width: 1
                    }

                    onTextChanged: root.filterText = text.toLowerCase()
                }
            }

            // ── Update queue list ─────────────────────────────
            ListView {
                id: pkgList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 240)
                clip: true
                model: root.pendingPackages
                spacing: 2

                delegate: PackageDelegate {
                    width: pkgList.width
                    pkgName:    modelData.name
                    pkgVersion: modelData.version
                    pkgSource:  modelData.source
                    pkgSize:    modelData.size
                    visible: root.filterText === "" ||
                             pkgName.toLowerCase().indexOf(root.filterText) !== -1
                    height: visible ? 40 : 0
                    onUpdateRequested: root.requestUpdatePackage(pkgName, pkgSource)
                }
            }

            // ── Empty state ───────────────────────────────────
            ColumnLayout {
                visible: root.pendingPackages.length === 0 && !root.isRefreshing
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                Text {
                    text: "No pending updates"
                    color: "#6c7086"
                    font.pixelSize: 12
                    font.italic: true
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Your system is up to date"
                    color: "#585b70"
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // ── Refreshing spinner ────────────────────────────
            RowLayout {
                visible: root.isRefreshing
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                BusyIndicator {
                    running: root.isRefreshing
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }

                Text {
                    text: "Checking for updates…"
                    color: "#f9e2af"
                    font.pixelSize: 11
                }
            }

            // ── Footer status ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
                visible: root.statusMessage.length > 0
            }

            Text {
                visible: root.statusMessage.length > 0
                text: root.statusMessage
                color: "#585b70"
                font.pixelSize: 9
                font.italic: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    // ── Toggle panel on click ─────────────────────────────────
    onClicked: {
        root.panelOpen = !root.panelOpen
        if (root.panelOpen) {
            dropdown.open()
        } else {
            dropdown.close()
        }
    }

    // ── Re-paint icon when state changes ──────────────────────
    onTotalCountChanged: updateIcon.requestPaint()
    onPanelOpenChanged: updateIcon.requestPaint()
    onIsRefreshingChanged: updateIcon.requestPaint()

    // ═══════════════════════════════════════════════════════════
    //  Sub-components
    // ═══════════════════════════════════════════════════════════

    // ── Category badge (Pacman / AUR / Flatpak) ──────────────
    component CategoryBadge: MouseArea {
        id: catBadge
        property string label: ""
        property int    count: 0
        property color  badgeColor: "#89b4fa"
        property string iconChar: "P"
        signal clicked()

        implicitWidth:  badgeRow.width + 18
        implicitHeight: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: catBadge.containsMouse ? "#313244" : "#181825"
            border.color: catBadge.containsMouse ? catBadge.badgeColor : "transparent"
            border.width: 1

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: catBadge.iconChar
                    color: catBadge.badgeColor
                    font.pixelSize: 11
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: catBadge.label
                    color: "#bac2de"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: countLbl.width + 10
                    height: 18
                    radius: 9
                    color: catBadge.badgeColor
                    opacity: 0.2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: countLbl
                        anchors.centerIn: parent
                        text: catBadge.count
                        color: catBadge.badgeColor
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }

        onClicked: catBadge.clicked()
    }

    // ── Action button ────────────────────────────────────────
    component ActionButton: MouseArea {
        id: actBtn
        property string label: ""
        property string iconChar: ""
        property bool   accent: false
        property bool   enabled: true
        signal clicked()

        implicitWidth:  actBtnContent.width + 20
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: {
                if (!actBtn.enabled) return "#1e1e2e"
                if (actBtn.accent) return actBtn.containsMouse ? "#b4befe" : "#cba6f7"
                return actBtn.containsMouse ? "#45475a" : "#313244"
            }
            opacity: actBtn.enabled ? 1.0 : 0.4

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Row {
            id: actBtnContent
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: actBtn.iconChar
                color: actBtn.accent ? "#1e1e2e" : "#cdd6f4"
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: actBtn.label
                color: actBtn.accent ? "#1e1e2e" : "#cdd6f4"
                font.pixelSize: 11
                font.bold: actBtn.accent
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        onClicked: if (actBtn.enabled) actBtn.clicked()
    }

    // ── Package delegate in the queue ─────────────────────────
    component PackageDelegate: ItemDelegate {
        id: pkgDel
        property string pkgName: ""
        property string pkgVersion: ""
        property string pkgSource: ""
        property string pkgSize: ""
        signal updateRequested()

        height: 40
        padding: 4

        background: Rectangle {
            color: pkgDel.hovered ? "#31324480" : "transparent"
            radius: 6
        }

        contentItem: RowLayout {
            spacing: 8

            // Source dot
            Rectangle {
                width: 6; height: 6; radius: 3
                color: pkgDel.pkgSource === "pacman" ? "#89b4fa" :
                       pkgDel.pkgSource === "aur"     ? "#cba6f7" :
                                                       "#94e2d5"
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                Text {
                    text: pkgDel.pkgName
                    color: "#cdd6f4"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: pkgDel.pkgVersion + (pkgDel.pkgSize ? "  (" + pkgDel.pkgSize + ")" : "")
                    color: "#6c7086"
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Source label
            Rectangle {
                width: srcLbl.width + 8
                height: 16
                radius: 3
                color: {
                    var c = pkgDel.pkgSource === "pacman" ? "#89b4fa" :
                            pkgDel.pkgSource === "aur"     ? "#cba6f7" :
                                                            "#94e2d5"
                    return Qt.rgba(c.r, c.g, c.b, 0.15)
                }

                Text {
                    id: srcLbl
                    anchors.centerIn: parent
                    text: pkgDel.pkgSource.toUpperCase()
                    color: pkgDel.pkgSource === "pacman" ? "#89b4fa" :
                           pkgDel.pkgSource === "aur"     ? "#cba6f7" :
                                                            "#94e2d5"
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            // Update single-package button
            Rectangle {
                width: 28; height: 24; radius: 4
                color: updateBtnArea.containsMouse ? "#89b4fa30" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "⬆"
                    color: "#89b4fa"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: updateBtnArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: pkgDel.updateRequested()
                }
            }
        }
    }
}
