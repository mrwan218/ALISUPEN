import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

/*  Alisupen – Panel.qml
 *  Dropdown panel opened via pluginApi.openPanel() from BarWidget.
 *  Contains category counters, action buttons, update queue with
 *  search/filter, progress indicator, and status footer.
 *
 *  Noctalia's Panel system positions this near the bar widget.
 */

Item {
    id: panelRoot

    // ── Injected by PluginService ────────────────────────────
    property var pluginApi: null
    property ShellScreen screen

    // ── Convenience access to Main.qml ───────────────────────
    readonly property var mainInstance: pluginApi?.mainInstance ?? null

    // ── Data from Main ───────────────────────────────────────
    readonly property int pacmanCount: mainInstance?.pacmanCount ?? 0
    readonly property int aurCount: mainInstance?.aurCount ?? 0
    readonly property int flatpakCount: mainInstance?.flatpakCount ?? 0
    readonly property int totalCount: pacmanCount + aurCount + flatpakCount
    readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false
    readonly property bool isUpdating: mainInstance?.isUpdating ?? false
    readonly property string statusMessage: mainInstance?.statusMessage ?? ""
    readonly property real updateProgress: mainInstance?.updateProgress ?? 0
    readonly property var pendingPackages: mainInstance?.pendingPackages ?? []

    property string filterText: ""

    implicitWidth: 400
    implicitHeight: panelBody.implicitHeight + 24

    // ═══════════════════════════════════════════════════════════
    //  Panel background
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        radius: Style.radiusL
        border.color: Color.mSurfaceVariant
        border.width: 1

        ColumnLayout {
            id: panelBody
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            // ── Header ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: "Alisupen"
                    font.bold: true
                    font.pixelSize: Style.fontSizeL
                    color: Color.mPrimary
                }

                Item { Layout.fillWidth: true }

                // Status pill
                Rectangle {
                    radius: Style.radiusM
                    height: 22
                    width: statusRow.width + 12
                    color: panelRoot.isRefreshing ? Color.mSurfaceVariant :
                           panelRoot.totalCount > 0 ? Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.12) :
                                                       Qt.rgba(Color.mOnSurfaceVariant.r, Color.mOnSurfaceVariant.g, Color.mOnSurfaceVariant.b, 0.12)

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: panelRoot.isRefreshing ? Color.mOnSurfaceVariant :
                                   panelRoot.totalCount > 0 ? Color.mError : Color.mOnSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on scale {
                                running: panelRoot.isRefreshing
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 1.6; duration: 500 }
                                NumberAnimation { from: 1.6; to: 1.0; duration: 500 }
                            }
                        }

                        NText {
                            text: panelRoot.isRefreshing ? "Checking…" :
                                  panelRoot.totalCount > 0 ? panelRoot.totalCount + " update(s)" : "Up to date"
                            font.pixelSize: Style.fontSizeS
                            font.bold: true
                            color: panelRoot.isRefreshing ? Color.mOnSurfaceVariant :
                                   panelRoot.totalCount > 0 ? Color.mError : Color.mOnSurfaceVariant
                        }
                    }
                }
            }

            // ── Progress bar ──────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 3
                radius: 1
                color: Color.mSurfaceVariant
                visible: panelRoot.isUpdating

                Rectangle {
                    width: panelRoot.updateProgress * parent.width
                    height: parent.height
                    radius: 1
                    color: Color.mPrimary
                }
            }

            // ── Category counters ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                CategoryBadge {
                    label: "Pacman"
                    count: panelRoot.pacmanCount
                    badgeColor: Color.mPrimary
                    onClicked: if (panelRoot.mainInstance) panelInstance.updateCategory("pacman")
                }
                CategoryBadge {
                    label: "AUR"
                    count: panelRoot.aurCount
                    badgeColor: Color.mSecondary
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateCategory("aur")
                }
                CategoryBadge {
                    label: "Flatpak"
                    count: panelRoot.flatpakCount
                    badgeColor: Color.mTertiary
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateCategory("flatpak")
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mSurfaceVariant
            }

            // ── Action buttons ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    text: "Refresh"
                    icon: "view-refresh"
                    enabled: !panelRoot.isRefreshing && !panelRoot.isUpdating
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.refresh()
                }
                NButton {
                    text: "Update All"
                    icon: "system-software-update"
                    highlighted: true
                    enabled: panelRoot.totalCount > 0 && !panelRoot.isRefreshing && !panelRoot.isUpdating
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateAll()
                }
                NButton {
                    text: "Rm Lock"
                    icon: "edit-delete"
                    enabled: !panelRoot.isUpdating
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.removeLock()
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mSurfaceVariant
            }

            // ── Update queue header + search ───────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: "Update Queue"
                    font.bold: true
                    font.pixelSize: Style.fontSizeM
                }

                Item { Layout.fillWidth: true }

                NTextInput {
                    Layout.preferredWidth: 130
                    placeholderText: "Filter…"
                    onTextChanged: panelRoot.filterText = text.toLowerCase()
                }
            }

            // ── Update queue list ─────────────────────────────
            ListView {
                id: pkgList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 220)
                clip: true
                model: panelRoot.pendingPackages
                spacing: 2

                delegate: PackageDelegate {
                    width: pkgList.width
                    pkgName:    modelData.name
                    pkgVersion: modelData.version
                    pkgSource:  modelData.source
                    pkgSize:    modelData.size
                    visible: panelRoot.filterText === "" ||
                             pkgName.toLowerCase().indexOf(panelRoot.filterText) !== -1
                    height: visible ? 40 : 0
                    onUpdateRequested: if (panelRoot.mainInstance) panelRoot.mainInstance.updatePackage(pkgName, pkgSource)
                }
            }

            // ── Empty state ───────────────────────────────────
            ColumnLayout {
                visible: panelRoot.pendingPackages.length === 0 && !panelRoot.isRefreshing
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                NText {
                    text: "No pending updates"
                    font.italic: true
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // ── Refreshing indicator ──────────────────────────
            RowLayout {
                visible: panelRoot.isRefreshing
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.marginS

                BusyIndicator {
                    running: panelRoot.isRefreshing
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }

                NText {
                    text: "Checking for updates…"
                    color: Color.mOnSurfaceVariant
                }
            }

            // ── Footer status ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mSurfaceVariant
                visible: panelRoot.statusMessage.length > 0
            }

            NText {
                visible: panelRoot.statusMessage.length > 0
                text: panelRoot.statusMessage
                font.italic: true
                font.pixelSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Sub-components
    // ═══════════════════════════════════════════════════════════

    component CategoryBadge: MouseArea {
        id: catBadge
        property string label: ""
        property int    count: 0
        property color  badgeColor: Color.mPrimary
        signal clicked()

        implicitWidth:  badgeRow.width + 16
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: Style.radiusM
            color: catBadge.containsMouse ? Color.mSurfaceVariant : Color.mSurface
            border.color: catBadge.containsMouse ? catBadge.badgeColor : "transparent"
            border.width: 1

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 4

                NText {
                    text: catBadge.label
                    font.pixelSize: Style.fontSizeS
                    color: Color.mOnSurface
                }
                Rectangle {
                    width: countLbl.width + 8
                    height: 16
                    radius: 8
                    color: Qt.rgba(catBadge.badgeColor.r, catBadge.badgeColor.g, catBadge.badgeColor.b, 0.15)

                    NText {
                        id: countLbl
                        anchors.centerIn: parent
                        text: catBadge.count
                        font.pixelSize: Style.fontSizeS
                        font.bold: true
                        color: catBadge.badgeColor
                    }
                }
            }
        }

        onClicked: catBadge.clicked()
    }

    component PackageDelegate: ItemDelegate {
        id: pkgDel
        property string pkgName: ""
        property string pkgVersion: ""
        property string pkgSource: ""
        property string pkgSize: ""
        signal updateRequested()

        height: 38
        padding: 2

        background: Rectangle {
            color: pkgDel.hovered ? Color.mSurfaceVariant : "transparent"
            radius: Style.radiusM
        }

        contentItem: RowLayout {
            spacing: Style.marginS

            // Source dot
            Rectangle {
                width: 6; height: 6; radius: 3
                color: pkgDel.pkgSource === "pacman" ? Color.mPrimary :
                       pkgDel.pkgSource === "aur"     ? Color.mSecondary :
                                                       Color.mTertiary
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                NText {
                    text: pkgDel.pkgName
                    font.pixelSize: Style.fontSizeM
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                NText {
                    text: pkgDel.pkgVersion + (pkgDel.pkgSize ? "  (" + pkgDel.pkgSize + ")" : "")
                    font.pixelSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Source tag
            Rectangle {
                width: srcLbl.width + 8
                height: 14
                radius: 3
                color: Qt.rgba(
                    pkgDel.pkgSource === "pacman" ? Color.mPrimary.r :
                    pkgDel.pkgSource === "aur"     ? Color.mSecondary.r : Color.mTertiary.r,
                    pkgDel.pkgSource === "pacman" ? Color.mPrimary.g :
                    pkgDel.pkgSource === "aur"     ? Color.mSecondary.g : Color.mTertiary.g,
                    pkgDel.pkgSource === "pacman" ? Color.mPrimary.b :
                    pkgDel.pkgSource === "aur"     ? Color.mSecondary.b : Color.mTertiary.b,
                    0.15
                )

                NText {
                    id: srcLbl
                    anchors.centerIn: parent
                    text: pkgDel.pkgSource.toUpperCase()
                    font.pixelSize: 8
                    font.bold: true
                    color: pkgDel.pkgSource === "pacman" ? Color.mPrimary :
                           pkgDel.pkgSource === "aur"     ? Color.mSecondary : Color.mTertiary
                }
            }

            // Update button
            NIconButton {
                icon: "go-up"
                iconSize: Style.fontSizeS
                baseSize: 24
                onClicked: pkgDel.updateRequested()
            }
        }
    }
}
