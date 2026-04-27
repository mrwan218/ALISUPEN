import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

/*  Alisupen – BarWidget.qml
 *  Top-bar widget shown in the Noctalia Shell panel.
 *  Displays a compact update-count badge; clicking opens a dropdown
 *  panel with category counters, the update queue, and action buttons.
 */

MouseArea {
    id: root

    // ── Public API (set by Main.qml) ─────────────────────────
    property int pacmanCount: 0
    property int aurCount: 0
    property int flatpakCount: 0
    property var  pendingPackages: []   // [{name, version, source, size}]

    // ── Signals ──────────────────────────────────────────────
    signal requestRefresh()
    signal requestUpdateAll()
    signal requestUpdateCategory(string category)
    signal requestRemoveLock()
    signal requestUpdatePackage(string pkgName)

    // ── Internal ─────────────────────────────────────────────
    property bool panelOpen: false
    property int  totalCount: pacmanCount + aurCount + flatpakCount

    // ── Dimensions ───────────────────────────────────────────
    implicitWidth:  badgeRow.width + 16
    implicitHeight: 32

    hoverEnabled: true

    // ═══════════════════════════════════════════════════════════
    //  Badge in the top bar
    // ═══════════════════════════════════════════════════════════
    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 6

        // Update icon (simple SVG-like canvas glyph)
        Canvas {
            id: updateIcon
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = panelOpen ? "#cba6f7" : "#cdd6f4"
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
            text: root.totalCount > 0 ? root.totalCount.toString() : "✓"
            color: root.totalCount > 0 ? "#f38ba8" : "#a6e3a1"
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

        width: 380
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

            // Subtle shadow
            layer.enabled: true
            layer.effect: /* shadow handled via border + opacity */
                Item {}
        }

        ColumnLayout {
            id: panelContent
            anchors.fill: parent
            spacing: 10

            // ── Header ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "⬆ Alisupen"
                    color: "#cba6f7"
                    font.pixelSize: 16
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.totalCount > 0
                          ? qsTr("%n update(s) pending", "", root.totalCount)
                          : qsTr("System is up to date")
                    color: root.totalCount > 0 ? "#f9e2af" : "#a6e3a1"
                    font.pixelSize: 11
                }
            }

            // ── Category counters ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                CategoryBadge {
                    label: "Pacman"
                    count: root.pacmanCount
                    color: "#89b4fa"
                    onClicked: root.requestUpdateCategory("pacman")
                }
                CategoryBadge {
                    label: "AUR"
                    count: root.aurCount
                    color: "#cba6f7"
                    onClicked: root.requestUpdateCategory("aur")
                }
                CategoryBadge {
                    label: "Flatpak"
                    count: root.flatpakCount
                    color: "#94e2d5"
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
                    label: "↻ Refresh"
                    accent: false
                    onClicked: root.requestRefresh()
                }
                ActionButton {
                    label: "⬆ Update All"
                    accent: true
                    enabled: root.totalCount > 0
                    onClicked: root.requestUpdateAll()
                }
                ActionButton {
                    label: "🔓 Rm Lock"
                    accent: false
                    onClicked: root.requestRemoveLock()
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // ── Update queue ──────────────────────────────────
            Text {
                text: "Update Queue"
                color: "#bac2de"
                font.pixelSize: 12
                font.bold: true
            }

            ListView {
                id: pkgList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(implicitHeight, 220)
                clip: true
                model: root.pendingPackages
                spacing: 2

                delegate: PackageDelegate {
                    width: pkgList.width
                    pkgName:   modelData.name
                    pkgVersion: modelData.version
                    pkgSource: modelData.source
                    pkgSize:   modelData.size
                    onUpdateRequested: root.requestUpdatePackage(pkgName)
                }
            }

            // ── Empty state ───────────────────────────────────
            Text {
                visible: root.pendingPackages.length === 0
                text: "No pending updates"
                color: "#6c7086"
                font.pixelSize: 12
                font.italic: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Toggle panel on click ─────────────────────────────────
    onClicked: {
        root.panelOpen = !root.panelOpen
        dropdown.open()
    }

    // ── Re-paint icon when state changes ──────────────────────
    onPanelOpenChanged: updateIcon.requestPaint()

    // ═══════════════════════════════════════════════════════════
    //  Sub-components
    // ═══════════════════════════════════════════════════════════

    // ── Category badge (Pacman / AUR / Flatpak) ──────────────
    component CategoryBadge: MouseArea {
        id: catBadge
        property string label: ""
        property int    count: 0
        property color  color: "#89b4fa"
        signal clicked()

        implicitWidth:  row.width + 16
        implicitHeight: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
                width: 8; height: 8; radius: 4
                color: catBadge.color
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: catBadge.label
                color: "#cdd6f4"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: catBadge.count
                color: catBadge.color
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: "#313244"
            opacity: catBadge.containsMouse ? 0.6 : 0.35
        }

        onClicked: catBadge.clicked()
    }

    // ── Action button ────────────────────────────────────────
    component ActionButton: MouseArea {
        id: actBtn
        property string label: ""
        property bool   accent: false
        signal clicked()

        implicitWidth:  btnText.width + 16
        implicitHeight: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: typeof _actBtnEnabled === "undefined" ? true : _actBtnEnabled

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: actBtn.accent
                   ? (actBtn.containsMouse ? "#b4befe" : "#cba6f7")
                   : (actBtn.containsMouse ? "#45475a" : "#313244")
            opacity: actBtn.enabled ? 1.0 : 0.4
        }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: actBtn.label
            color: actBtn.accent ? "#1e1e2e" : "#cdd6f4"
            font.pixelSize: 11
            font.bold: actBtn.accent
        }

        onClicked: actBtn.clicked()
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
            color: pkgDel.hovered ? "#313244" : "transparent"
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
                Text {
                    text: pkgDel.pkgName
                    color: "#cdd6f4"
                    font.pixelSize: 12
                }
                Text {
                    text: pkgDel.pkgVersion + (pkgDel.pkgSize ? "  (" + pkgDel.pkgSize + ")" : "")
                    color: "#6c7086"
                    font.pixelSize: 10
                }
            }

            Item { Layout.fillWidth: true }

            // Update single-package button
            Text {
                text: "⬆"
                color: "#89b4fa"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pkgDel.updateRequested()
                }
            }
        }
    }
}
