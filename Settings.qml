import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Widgets
import qs.Services.UI

/*  Alisupen – Settings.qml
 *  Plugin configuration panel accessible from Noctalia's Settings → Plugins.
 *
 *  Uses pluginApi.pluginSettings for reading/writing and
 *  pluginApi.saveSettings() for persistence.
 */

Item {
    id: settingsRoot

    // ── Injected by PluginService ────────────────────────────
    property var pluginApi: null

    // ── Settings shortcuts ───────────────────────────────────
    readonly property var s: pluginApi?.pluginSettings ?? ({})

    implicitWidth:  400
    implicitHeight: settingsCol.implicitHeight + 32

    // ═══════════════════════════════════════════════════════════
    //  Layout
    // ═══════════════════════════════════════════════════════════
    ColumnLayout {
        id: settingsCol
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        // ── Title ─────────────────────────────────────────────
        NText {
            text: "Alisupen Settings"
            font.bold: true
            font.pixelSize: Style.fontSizeL
            color: Color.mPrimary
        }

        // ══════════════════════════════════════════════════════
        //  Auto-Refresh Interval
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Auto-Refresh Interval" }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Slider {
                id: intervalSlider
                Layout.fillWidth: true
                from: 5
                to: 120
                stepSize: 5
                value: settingsRoot.s.refreshInterval ?? 30

                onMoved: {
                    if (settingsRoot.pluginApi) {
                        settingsRoot.pluginApi.pluginSettings.refreshInterval = Math.round(value)
                        settingsRoot.pluginApi.saveSettings()
                    }
                }

                background: Rectangle {
                    x: intervalSlider.leftPadding
                    y: intervalSlider.topPadding + intervalSlider.availableHeight / 2 - height / 2
                    width: intervalSlider.availableWidth
                    height: 4
                    radius: 2
                    color: Color.mSurfaceVariant

                    Rectangle {
                        width: intervalSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Color.mPrimary
                    }
                }

                handle: Rectangle {
                    x: intervalSlider.leftPadding + intervalSlider.visualPosition * (intervalSlider.availableWidth - width)
                    y: intervalSlider.topPadding + intervalSlider.availableHeight / 2 - height / 2
                    width: 16; height: 16; radius: 8
                    color: intervalSlider.pressed ? Color.mSecondary : Color.mPrimary
                }
            }

            NText {
                text: Math.round(intervalSlider.value) + " min"
                font.pixelSize: Style.fontSizeM
                Layout.minimumWidth: 56
                horizontalAlignment: Text.AlignRight
            }
        }

        // ══════════════════════════════════════════════════════
        //  Visibility Toggles
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Visibility Toggles" }

        ToggleRow {
            label: "Show Pacman updates"
            checked: settingsRoot.s.showPacman ?? true
            onToggled: {
                if (settingsRoot.pluginApi) {
                    settingsRoot.pluginApi.pluginSettings.showPacman = checked
                    settingsRoot.pluginApi.saveSettings()
                }
            }
        }
        ToggleRow {
            label: "Show AUR updates"
            checked: settingsRoot.s.showAur ?? true
            onToggled: {
                if (settingsRoot.pluginApi) {
                    settingsRoot.pluginApi.pluginSettings.showAur = checked
                    settingsRoot.pluginApi.saveSettings()
                }
            }
        }
        ToggleRow {
            label: "Show Flatpak updates"
            checked: settingsRoot.s.showFlatpak ?? true
            onToggled: {
                if (settingsRoot.pluginApi) {
                    settingsRoot.pluginApi.pluginSettings.showFlatpak = checked
                    settingsRoot.pluginApi.saveSettings()
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  AUR Helper Selection
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "AUR Helper" }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
                model: [
                    { value: "auto", label: "Auto-detect" },
                    { value: "paru", label: "paru" },
                    { value: "yay",  label: "yay" }
                ]

                delegate: MouseArea {
                    required property var modelData
                    Layout.fillHeight: true
                    implicitWidth: helperLbl.width + 20
                    implicitHeight: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    Rectangle {
                        anchors.fill: parent
                        radius: Style.radiusM
                        color: settingsRoot.s.aurHelper === modelData.value
                               ? Color.mPrimary
                               : (parent.containsMouse ? Color.mSurfaceVariant : Color.mSurface)
                        border.color: settingsRoot.s.aurHelper === modelData.value ? Color.mPrimary : "transparent"
                        border.width: 1
                    }

                    NText {
                        id: helperLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Style.fontSizeS
                        font.bold: settingsRoot.s.aurHelper === modelData.value
                        color: settingsRoot.s.aurHelper === modelData.value ? Color.mOnPrimary : Color.mOnSurface
                    }

                    onClicked: {
                        if (settingsRoot.pluginApi) {
                            settingsRoot.pluginApi.pluginSettings.aurHelper = modelData.value
                            settingsRoot.pluginApi.saveSettings()
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  Advanced AUR Options
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Advanced AUR Options" }

        ToggleRow {
            label: "Skip PKGBUILD review"
            checked: settingsRoot.s.skipPkgbuild ?? false
            onToggled: {
                if (settingsRoot.pluginApi) {
                    settingsRoot.pluginApi.pluginSettings.skipPkgbuild = checked
                    settingsRoot.pluginApi.saveSettings()
                }
            }
        }
        ToggleRow {
            label: "Remove build dependencies after install"
            checked: settingsRoot.s.removeBuildDeps ?? true
            onToggled: {
                if (settingsRoot.pluginApi) {
                    settingsRoot.pluginApi.pluginSettings.removeBuildDeps = checked
                    settingsRoot.pluginApi.saveSettings()
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  Excluded Packages
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Excluded Packages" }

        NTextInput {
            id: excludeField
            Layout.fillWidth: true
            placeholderText: "e.g. linux, nvidia-dkms, mesa"
            text: {
                var arr = settingsRoot.s.excludedPkgs ?? []
                return arr.join(", ")
            }

            onEditingFinished: {
                if (settingsRoot.pluginApi) {
                    var arr = text.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
                    settingsRoot.pluginApi.pluginSettings.excludedPkgs = arr
                    settingsRoot.pluginApi.saveSettings()
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  Actions
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Actions" }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
                text: "Reset Defaults"
                highlighted: false
                onClicked: {
                    if (settingsRoot.pluginApi) {
                        var defaults = {
                            refreshInterval: 30,
                            showPacman: true,
                            showAur: true,
                            showFlatpak: true,
                            aurHelper: "auto",
                            skipPkgbuild: false,
                            removeBuildDeps: true,
                            excludedPkgs: []
                        }
                        for (var key in defaults) {
                            settingsRoot.pluginApi.pluginSettings[key] = defaults[key]
                        }
                        settingsRoot.pluginApi.saveSettings()
                        intervalSlider.value = 30
                    }
                }
            }

            NButton {
                text: "Revert Changes"
                highlighted: true
                onClicked: {
                    // Reload from persisted settings
                    if (settingsRoot.pluginApi) {
                        settingsRoot.pluginApi.loadSettings()
                        intervalSlider.value = settingsRoot.pluginApi.pluginSettings.refreshInterval ?? 30
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════
        //  Status
        // ══════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                width: 8; height: 8; radius: 4
                color: Color.mOnSurfaceVariant
            }
            NText {
                text: "Plugin active — settings saved automatically"
                font.italic: true
                font.pixelSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Sub-components
    // ═══════════════════════════════════════════════════════════

    component SectionLabel: NText {
        color: Color.mOnSurfaceVariant
        font.pixelSize: Style.fontSizeS
        font.bold: true
        font.capitalization: Font.AllUppercase
        Layout.topMargin: Style.marginS
    }

    component ToggleRow: RowLayout {
        id: tRow
        property string label: ""
        property bool   checked: false
        signal toggled()

        Layout.fillWidth: true
        spacing: Style.marginS

        // Toggle switch
        Rectangle {
            id: toggleTrack
            width: 36; height: 20; radius: 10
            color: tRow.checked ? Color.mPrimary : Color.mSurfaceVariant
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                id: toggleKnob
                width: 16; height: 16; radius: 8
                color: Color.mSurface
                x: tRow.checked ? toggleTrack.width - width - 2 : 2
                y: 2
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    tRow.checked = !tRow.checked
                    tRow.toggled()
                }
            }
        }

        NText {
            text: tRow.label
            font.pixelSize: Style.fontSizeM
            Layout.fillWidth: true
        }
    }
}
