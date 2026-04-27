import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

/*  Alisupen – Settings.qml
 *  Plugin configuration panel accessible from Noctalia's Settings → Plugins.
 *
 *  Settings are persisted via pluginApi and read back by Main.qml on reload.
 */

Rectangle {
    id: settingsRoot
    color: "transparent"

    // ── Settings state (initialized from pluginApi) ──────────
    property int    refreshInterval:  pluginApi.get("refreshInterval", 30)
    property bool   showPacman:       pluginApi.get("showPacman", true)
    property bool   showAur:          pluginApi.get("showAur", true)
    property bool   showFlatpak:      pluginApi.get("showFlatpak", true)
    property string aurHelper:        pluginApi.get("aurHelper", "auto")
    property bool   skipPkgbuild:     pluginApi.get("skipPkgbuild", false)
    property bool   removeBuildDeps:  pluginApi.get("removeBuildDeps", true)
    property string excludedPkgsText: {
        var arr = pluginApi.get("excludedPkgs", [])
        return arr.join(", ")
    }

    // ── Helper to save a value ───────────────────────────────
    function save(key, value) {
        pluginApi.set(key, value)
    }

    implicitWidth:  400
    implicitHeight: settingsCol.implicitHeight + 32

    // ═══════════════════════════════════════════════════════════
    //  Layout
    // ═══════════════════════════════════════════════════════════
    ColumnLayout {
        id: settingsCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // ── Title ─────────────────────────────────────────────
        Text {
            text: "Alisupen Settings"
            color: "#cba6f7"
            font.pixelSize: 18
            font.bold: true
        }

        // ══════════════════════════════════════════════════════
        //  Auto-Refresh Interval
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Auto-Refresh Interval" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Slider {
                id: intervalSlider
                Layout.fillWidth: true
                from: 5
                to: 120
                stepSize: 5
                value: settingsRoot.refreshInterval

                onMoved: {
                    settingsRoot.refreshInterval = Math.round(value)
                    save("refreshInterval", settingsRoot.refreshInterval)
                }

                background: Rectangle {
                    x: intervalSlider.leftPadding
                    y: intervalSlider.topPadding + intervalSlider.availableHeight / 2 - height / 2
                    width: intervalSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#313244"

                    Rectangle {
                        width: intervalSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: "#cba6f7"
                    }
                }

                handle: Rectangle {
                    x: intervalSlider.leftPadding + intervalSlider.visualPosition * (intervalSlider.availableWidth - width)
                    y: intervalSlider.topPadding + intervalSlider.availableHeight / 2 - height / 2
                    width: 16; height: 16; radius: 8
                    color: intervalSlider.pressed ? "#b4befe" : "#cba6f7"
                }
            }

            Text {
                text: settingsRoot.refreshInterval + " min"
                color: "#cdd6f4"
                font.pixelSize: 12
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
            checked: settingsRoot.showPacman
            onToggled: {
                settingsRoot.showPacman = checked
                save("showPacman", checked)
            }
        }
        ToggleRow {
            label: "Show AUR updates"
            checked: settingsRoot.showAur
            onToggled: {
                settingsRoot.showAur = checked
                save("showAur", checked)
            }
        }
        ToggleRow {
            label: "Show Flatpak updates"
            checked: settingsRoot.showFlatpak
            onToggled: {
                settingsRoot.showFlatpak = checked
                save("showFlatpak", checked)
            }
        }

        // ══════════════════════════════════════════════════════
        //  AUR Helper Selection
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "AUR Helper" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

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
                        radius: 6
                        color: settingsRoot.aurHelper === modelData.value
                               ? "#cba6f7"
                               : (parent.containsMouse ? "#45475a" : "#313244")
                    }

                    Text {
                        id: helperLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        color: settingsRoot.aurHelper === modelData.value ? "#1e1e2e" : "#cdd6f4"
                        font.pixelSize: 11
                        font.bold: settingsRoot.aurHelper === modelData.value
                    }

                    onClicked: {
                        settingsRoot.aurHelper = modelData.value
                        save("aurHelper", modelData.value)
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
            checked: settingsRoot.skipPkgbuild
            onToggled: {
                settingsRoot.skipPkgbuild = checked
                save("skipPkgbuild", checked)
            }
        }
        ToggleRow {
            label: "Remove build dependencies after install"
            checked: settingsRoot.removeBuildDeps
            onToggled: {
                settingsRoot.removeBuildDeps = checked
                save("removeBuildDeps", checked)
            }
        }

        // ══════════════════════════════════════════════════════
        //  Excluded Packages
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Excluded Packages" }

        TextField {
            id: excludeField
            Layout.fillWidth: true
            placeholderText: "e.g. linux, nvidia-dkms, mesa"
            placeholderTextColor: "#6c7086"
            text: settingsRoot.excludedPkgsText
            color: "#cdd6f4"
            font.pixelSize: 12

            background: Rectangle {
                radius: 6
                color: "#313244"
                border.color: excludeField.activeFocus ? "#cba6f7" : "#45475a"
                border.width: 1
            }

            onEditingFinished: {
                var arr = text.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
                settingsRoot.excludedPkgsText = text
                save("excludedPkgs", arr)
            }
        }

        // ══════════════════════════════════════════════════════
        //  Actions
        // ══════════════════════════════════════════════════════
        SectionLabel { text: "Actions" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SettingsButton {
                label: "Reset Defaults"
                accent: false
                onClicked: {
                    intervalSlider.value = 30
                    settingsRoot.refreshInterval = 30
                    settingsRoot.showPacman = true
                    settingsRoot.showAur = true
                    settingsRoot.showFlatpak = true
                    settingsRoot.aurHelper = "auto"
                    settingsRoot.skipPkgbuild = false
                    settingsRoot.removeBuildDeps = true
                    settingsRoot.excludedPkgsText = ""
                    excludeField.text = ""

                    save("refreshInterval", 30)
                    save("showPacman", true)
                    save("showAur", true)
                    save("showFlatpak", true)
                    save("aurHelper", "auto")
                    save("skipPkgbuild", false)
                    save("removeBuildDeps", true)
                    save("excludedPkgs", [])
                }
            }

            SettingsButton {
                label: "Revert Changes"
                accent: true
                onClicked: {
                    // Reload from pluginApi
                    settingsRoot.refreshInterval = pluginApi.get("refreshInterval", 30)
                    settingsRoot.showPacman      = pluginApi.get("showPacman", true)
                    settingsRoot.showAur         = pluginApi.get("showAur", true)
                    settingsRoot.showFlatpak     = pluginApi.get("showFlatpak", true)
                    settingsRoot.aurHelper       = pluginApi.get("aurHelper", "auto")
                    settingsRoot.skipPkgbuild    = pluginApi.get("skipPkgbuild", false)
                    settingsRoot.removeBuildDeps = pluginApi.get("removeBuildDeps", true)
                    var arr = pluginApi.get("excludedPkgs", [])
                    settingsRoot.excludedPkgsText = arr.join(", ")
                    excludeField.text = settingsRoot.excludedPkgsText
                    intervalSlider.value = settingsRoot.refreshInterval
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
                color: "#a6e3a1"
            }
            Text {
                text: "Plugin active – settings saved automatically"
                color: "#6c7086"
                font.pixelSize: 10
                font.italic: true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Sub-components
    // ═══════════════════════════════════════════════════════════

    // ── Section label ────────────────────────────────────────
    component SectionLabel: Text {
        color: "#a6adc8"
        font.pixelSize: 11
        font.bold: true
        font.capitalization: Font.AllUppercase
        Layout.topMargin: 6
    }

    // ── Toggle row ───────────────────────────────────────────
    component ToggleRow: RowLayout {
        id: tRow
        property string label: ""
        property bool   checked: false
        signal toggled()

        Layout.fillWidth: true
        spacing: 10

        // Custom toggle switch
        Rectangle {
            id: toggleTrack
            width: 36; height: 20; radius: 10
            color: tRow.checked ? "#cba6f7" : "#45475a"
            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                id: toggleKnob
                width: 16; height: 16; radius: 8
                color: "#1e1e2e"
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

        Text {
            text: tRow.label
            color: "#cdd6f4"
            font.pixelSize: 12
            Layout.fillWidth: true
        }
    }

    // ── Settings button ──────────────────────────────────────
    component SettingsButton: MouseArea {
        id: sBtn
        property string label: ""
        property bool   accent: false
        signal clicked()

        implicitWidth:  sBtnLbl.width + 24
        implicitHeight: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: sBtn.accent
                   ? (sBtn.containsMouse ? "#b4befe" : "#cba6f7")
                   : (sBtn.containsMouse ? "#45475a" : "#313244")
        }

        Text {
            id: sBtnLbl
            anchors.centerIn: parent
            text: sBtn.label
            color: sBtn.accent ? "#1e1e2e" : "#cdd6f4"
            font.pixelSize: 11
            font.bold: sBtn.accent
        }

        onClicked: sBtn.clicked()
    }
}
