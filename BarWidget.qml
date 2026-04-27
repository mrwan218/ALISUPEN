import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

/*  Alisupen – BarWidget.qml
 *  Top-bar widget for Noctalia Shell.
 *  Displays a compact update-count badge; clicking opens the panel.
 *
 *  Root type MUST be Item — Noctalia's bar loader instantiates this
 *  and injects required properties (pluginApi, screen, widgetId, etc.).
 */

Item {
    id: root

    // ── Injected by Noctalia PluginService (REQUIRED) ────────
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // ── Convenience access to Main.qml ───────────────────────
    readonly property var mainInstance: pluginApi?.mainInstance ?? null

    // ── Per-screen bar properties ────────────────────────────
    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    // ── Update counts from Main ──────────────────────────────
    readonly property int pacmanCount: mainInstance?.pacmanCount ?? 0
    readonly property int aurCount: mainInstance?.aurCount ?? 0
    readonly property int flatpakCount: mainInstance?.flatpakCount ?? 0
    readonly property int totalCount: pacmanCount + aurCount + flatpakCount
    readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false
    readonly property bool isUpdating: mainInstance?.isUpdating ?? false

    // ── Layout ───────────────────────────────────────────────
    readonly property real contentWidth: contentRow.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    // ── Pulsing opacity when refreshing ──────────────────────
    SequentialAnimation on opacity {
        running: root.isRefreshing
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.5; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.5; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
    }

    // ═══════════════════════════════════════════════════════════
    //  Visual capsule (standard Noctalia bar widget pattern)
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginS

            // Update icon
            NIcon {
                icon: "system-software-update"
                iconSize: root.barFontSize
                colorKey: root.totalCount > 0 ? "error" : "success"
                Layout.alignment: Qt.AlignVCenter
            }

            // Count label
            NText {
                text: root.isRefreshing ? "…" :
                      root.totalCount > 0 ? root.totalCount.toString() : "OK"
                font.pixelSize: root.barFontSize
                font.bold: true
                color: root.isRefreshing ? Color.mOnSurfaceVariant :
                       root.totalCount > 0 ? Color.mError : Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Mouse area (separate from visual, covers full widget area)
    // ═══════════════════════════════════════════════════════════
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (pluginApi) {
                pluginApi.togglePanel(root.screen, visualCapsule)
            }
        }
    }

    // ── Tooltip ───────────────────────────────────────────────
    TooltipService.tooltipTarget: visualCapsule
    TooltipService.tooltipText: root.totalCount > 0
        ? qsTr("%n update(s) pending", "", root.totalCount)
        : qsTr("System is up to date")
    TooltipService.tooltipDirection: BarService.getTooltipDirection(screenName)
}
