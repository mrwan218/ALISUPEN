import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

/*  Alisupen – Panel.qml
 *  Dropdown panel opened via pluginApi.openPanel() from BarWidget.
 *  Contains category counters, action buttons, update queue, and status.
 *
 *  Uses only well-tested Noctalia widget types.
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

                NText {
                    text: panelRoot.isRefreshing ? "Checking…" :
                          panelRoot.totalCount > 0 ? panelRoot.totalCount + " update(s)" : "Up to date"
                    font.pixelSize: Style.fontSizeS
                    font.bold: true
                    color: panelRoot.isRefreshing ? Color.mOnSurfaceVariant :
                           panelRoot.totalCount > 0 ? Color.mError : Color.mOnSurfaceVariant
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

                // Pacman badge
                Rectangle {
                    radius: Style.radiusM
                    height: 28
                    width: pacRow.width + 16
                    color: Color.mSurface
                    border.color: Color.mPrimary
                    border.width: 1

                    Row {
                        id: pacRow
                        anchors.centerIn: parent
                        spacing: 4
                        NText { text: "Pacman"; font.pixelSize: Style.fontSizeS; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                        NText { text: panelRoot.pacmanCount; font.pixelSize: Style.fontSizeS; font.bold: true; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateCategory("pacman")
                    }
                }

                // AUR badge
                Rectangle {
                    radius: Style.radiusM
                    height: 28
                    width: aurRow.width + 16
                    color: Color.mSurface
                    border.color: Color.mSecondary
                    border.width: 1

                    Row {
                        id: aurRow
                        anchors.centerIn: parent
                        spacing: 4
                        NText { text: "AUR"; font.pixelSize: Style.fontSizeS; color: Color.mSecondary; anchors.verticalCenter: parent.verticalCenter }
                        NText { text: panelRoot.aurCount; font.pixelSize: Style.fontSizeS; font.bold: true; color: Color.mSecondary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateCategory("aur")
                    }
                }

                // Flatpak badge
                Rectangle {
                    radius: Style.radiusM
                    height: 28
                    width: flatRow.width + 16
                    color: Color.mSurface
                    border.color: Color.mTertiary
                    border.width: 1

                    Row {
                        id: flatRow
                        anchors.centerIn: parent
                        spacing: 4
                        NText { text: "Flatpak"; font.pixelSize: Style.fontSizeS; color: Color.mTertiary; anchors.verticalCenter: parent.verticalCenter }
                        NText { text: panelRoot.flatpakCount; font.pixelSize: Style.fontSizeS; font.bold: true; color: Color.mTertiary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateCategory("flatpak")
                    }
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: Color.mSurfaceVariant }

            // ── Action buttons ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    text: "Refresh"
                    enabled: !panelRoot.isRefreshing && !panelRoot.isUpdating
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.refresh()
                }
                NButton {
                    text: "Update All"
                    highlighted: true
                    enabled: panelRoot.totalCount > 0 && !panelRoot.isRefreshing && !panelRoot.isUpdating
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updateAll()
                }
                NButton {
                    text: "Rm Lock"
                    enabled: !panelRoot.isUpdating
                    onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.removeLock()
                }
            }

            // ── Separator ─────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: Color.mSurfaceVariant }

            // ── Update queue header + search ───────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText { text: "Update Queue"; font.bold: true; font.pixelSize: Style.fontSizeM }

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

                delegate: ItemDelegate {
                    width: pkgList.width
                    height: 38
                    padding: 2

                    background: Rectangle {
                        color: parent.hovered ? Color.mSurfaceVariant : "transparent"
                        radius: Style.radiusM
                    }

                    contentItem: RowLayout {
                        spacing: Style.marginS

                        // Source dot
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: modelData.source === "pacman" ? Color.mPrimary :
                                   modelData.source === "aur"     ? Color.mSecondary : Color.mTertiary
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            NText {
                                text: modelData.name
                                font.pixelSize: Style.fontSizeM
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            NText {
                                text: modelData.version + (modelData.size ? "  (" + modelData.size + ")" : "")
                                font.pixelSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }

                        // Source tag
                        Rectangle {
                            width: srcTag.width + 8; height: 14; radius: 3
                            color: modelData.source === "pacman" ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.15) :
                                   modelData.source === "aur"     ? Qt.rgba(Color.mSecondary.r, Color.mSecondary.g, Color.mSecondary.b, 0.15) :
                                                                    Qt.rgba(Color.mTertiary.r, Color.mTertiary.g, Color.mTertiary.b, 0.15)
                            NText {
                                id: srcTag
                                anchors.centerIn: parent
                                text: modelData.source.toUpperCase()
                                font.pixelSize: 8; font.bold: true
                                color: modelData.source === "pacman" ? Color.mPrimary :
                                       modelData.source === "aur"     ? Color.mSecondary : Color.mTertiary
                            }
                        }

                        // Update button
                        NIconButton {
                            icon: "go-up"
                            baseSize: 24
                            onClicked: if (panelRoot.mainInstance) panelRoot.mainInstance.updatePackage(modelData.name, modelData.source)
                        }
                    }

                    visible: panelRoot.filterText === "" || modelData.name.toLowerCase().indexOf(panelRoot.filterText) !== -1
                }
            }

            // ── Empty state ───────────────────────────────────
            NText {
                visible: panelRoot.pendingPackages.length === 0 && !panelRoot.isRefreshing
                text: "No pending updates"
                font.italic: true
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
            }

            // ── Refreshing indicator ──────────────────────────
            NText {
                visible: panelRoot.isRefreshing
                text: "Checking for updates…"
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
            }

            // ── Footer status ─────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: Color.mSurfaceVariant; visible: panelRoot.statusMessage.length > 0 }
            NText {
                visible: panelRoot.statusMessage.length > 0
                text: panelRoot.statusMessage
                font.italic: true; font.pixelSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true; elide: Text.ElideRight
            }
        }
    }
}
