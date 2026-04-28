import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

/*  Alisupen – BarWidget.qml
 *  Top-bar widget for Noctalia Shell.
 *  Uses NIconButton — the proven pattern from official plugins.
 *  Clicking toggles the panel via pluginApi.togglePanel().
 */

NIconButton {
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

    // ── Update counts from Main ──────────────────────────────
    readonly property int pacmanCount: mainInstance?.pacmanCount ?? 0
    readonly property int aurCount: mainInstance?.aurCount ?? 0
    readonly property int flatpakCount: mainInstance?.flatpakCount ?? 0
    readonly property int totalCount: pacmanCount + aurCount + flatpakCount
    readonly property bool isRefreshing: mainInstance?.isRefreshing ?? false

    // ── Per-screen properties ────────────────────────────────
    readonly property string screenName: screen?.name ?? ""
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    // ── NIconButton config ───────────────────────────────────
    icon: "system-software-update"
    tooltipText: root.totalCount > 0
        ? root.totalCount + " update(s) pending"
        : "System is up to date"
    tooltipDirection: BarService.getTooltipDirection(screenName)
    baseSize: capsuleHeight
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: Style.capsuleColor
    colorFg: root.totalCount > 0 ? Color.mError : Color.mOnSurfaceVariant
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // ── Pulsing opacity when refreshing ──────────────────────
    SequentialAnimation on opacity {
        running: root.isRefreshing
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.5; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.5; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
    }

    // ── Click handler ────────────────────────────────────────
    onClicked: {
        if (pluginApi) {
            pluginApi.togglePanel(root.screen, root)
        }
    }
}
