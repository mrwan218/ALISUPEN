import QtQuick 2.15

/*  Alisupen – Main.qml
 *  Background service: periodic update checks, command execution,
 *  and data flow to BarWidget.qml.
 *
 *  Uses the Noctalia Process API for running system commands and
 *  pluginApi for persistent settings.
 */

QtObject {
    id: service

    // ── Exposed to BarWidget ─────────────────────────────────
    property int  pacmanCount: 0
    property int  aurCount: 0
    property int  flatpakCount: 0
    property var  pendingPackages: []

    // ── Status ───────────────────────────────────────────────
    property string statusMessage: "Idle"
    property bool   isRefreshing: false
    property bool   isUpdating: false

    // ── Settings (persisted via pluginApi) ────────────────────
    property int    refreshInterval: pluginApi.get("refreshInterval", 30)   // minutes
    property bool   showPacman:      pluginApi.get("showPacman", true)
    property bool   showAur:         pluginApi.get("showAur", true)
    property bool   showFlatpak:     pluginApi.get("showFlatpak", true)
    property string aurHelper:       pluginApi.get("aurHelper", "auto")    // auto | paru | yay
    property bool   skipPkgbuild:    pluginApi.get("skipPkgbuild", false)
    property bool   removeBuildDeps: pluginApi.get("removeBuildDeps", true)
    property var    excludedPkgs:    pluginApi.get("excludedPkgs", [])

    // ── Internal ─────────────────────────────────────────────
    property string _detectedHelper: ""

    // ═══════════════════════════════════════════════════════════
    //  Periodic refresh timer
    // ═══════════════════════════════════════════════════════════
    Timer {
        id: refreshTimer
        interval: service.refreshInterval * 60 * 1000
        running: true
        repeat: true
        onTriggered: service.refresh()
    }

    // ═══════════════════════════════════════════════════════════
    //  AUR helper auto-detection
    // ═══════════════════════════════════════════════════════════
    function detectAurHelper() {
        var p = Process.create("which", ["paru"])
        p.finished.connect(function(exitCode) {
            if (exitCode === 0) {
                service._detectedHelper = "paru"
            } else {
                var p2 = Process.create("which", ["yay"])
                p2.finished.connect(function(ec) {
                    service._detectedHelper = (ec === 0) ? "yay" : ""
                })
                p2.start()
            }
        })
        p.start()
    }

    function effectiveAurHelper() {
        if (service.aurHelper === "auto") {
            if (service._detectedHelper === "") detectAurHelper()
            return service._detectedHelper || "paru"
        }
        return service.aurHelper
    }

    // ═══════════════════════════════════════════════════════════
    //  Refresh – check for available updates
    // ═══════════════════════════════════════════════════════════
    function refresh() {
        if (service.isRefreshing) return
        service.isRefreshing = true
        service.statusMessage = "Checking for updates…"

        var newPackages = []
        var pacCount = 0, aCount = 0, flatCount = 0
        var checksRemaining = 0
        if (service.showPacman)  checksRemaining++
        if (service.showAur)     checksRemaining++
        if (service.showFlatpak) checksRemaining++

        if (checksRemaining === 0) {
            service.isRefreshing = false
            service.statusMessage = "No sources enabled"
            return
        }

        function maybeFinish() {
            checksRemaining--
            if (checksRemaining <= 0) {
                // Filter excluded packages
                var filtered = []
                for (var i = 0; i < newPackages.length; i++) {
                    if (service.excludedPkgs.indexOf(newPackages[i].name) === -1) {
                        filtered.push(newPackages[i])
                    }
                }
                service.pendingPackages = filtered
                service.pacmanCount = pacCount
                service.aurCount   = aCount
                service.flatpakCount = flatCount
                service.isRefreshing = false
                service.statusMessage = "Last checked: " + Qt.formatTime(new Date(), "hh:mm")
            }
        }

        // ── Pacman ────────────────────────────────────────────
        if (service.showPacman) {
            var pPac = Process.create("pacman", ["-Qu"])
            pPac.stdout.connect(function(lines) {
                var items = lines.trim().split("\n")
                for (var i = 0; i < items.length; i++) {
                    var parts = items[i].split(/\s+/)
                    if (parts.length >= 2) {
                        newPackages.push({
                            name:    parts[0],
                            version: parts[1],
                            source:  "pacman",
                            size:    ""
                        })
                        pacCount++
                    }
                }
            })
            pPac.finished.connect(function() { maybeFinish() })
            pPac.start()
        }

        // ── AUR ───────────────────────────────────────────────
        if (service.showAur) {
            var helper = effectiveAurHelper()
            var args = helper === "yay" ? ["-Qua", "--noconfirm"] : ["-Qua", "--noconfirm"]
            var pAur = Process.create(helper, args)
            pAur.stdout.connect(function(lines) {
                var items = lines.trim().split("\n")
                for (var i = 0; i < items.length; i++) {
                    var parts = items[i].split(/\s+/)
                    if (parts.length >= 2) {
                        newPackages.push({
                            name:    parts[0],
                            version: parts[1],
                            source:  "aur",
                            size:    ""
                        })
                        aCount++
                    }
                }
            })
            pAur.finished.connect(function() { maybeFinish() })
            pAur.start()
        }

        // ── Flatpak ───────────────────────────────────────────
        if (service.showFlatpak) {
            var pFlat = Process.create("flatpak", ["update", "--no-deploy", "--no-related"])
            pFlat.stdout.connect(function(lines) {
                // Flatpak outputs a table; parse lines that start with an app ID
                var items = lines.trim().split("\n")
                for (var i = 0; i < items.length; i++) {
                    var line = items[i].trim()
                    if (line.length > 0 && line[0] !== "=" && line[0] !== " " && line.indexOf("Updating") === -1) {
                        var parts = line.split(/\s+/)
                        if (parts.length >= 1 && parts[0].indexOf(".") !== -1) {
                            newPackages.push({
                                name:    parts[0],
                                version: parts.length > 1 ? parts[1] : "?",
                                source:  "flatpak",
                                size:    parts.length > 2 ? parts[parts.length - 1] : ""
                            })
                            flatCount++
                        }
                    }
                }
            })
            pFlat.finished.connect(function() { maybeFinish() })
            pFlat.start()
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Update All
    // ═══════════════════════════════════════════════════════════
    function updateAll() {
        if (service.isUpdating) return
        service.isUpdating = true
        service.statusMessage = "Updating all packages…"

        var commands = []

        if (service.pacmanCount > 0) {
            commands.push({ cmd: "pkexec", args: ["pacman", "-Syu", "--noconfirm"] })
        }
        if (service.aurCount > 0) {
            var helper = effectiveAurHelper()
            var aurArgs = ["-Syu", "--noconfirm"]
            if (service.skipPkgbuild)   aurArgs.push("--noconfirm")  // skip PKGBUILD review
            if (service.removeBuildDeps) aurArgs.push("--removemake")
            commands.push({ cmd: helper, args: aurArgs })
        }
        if (service.flatpakCount > 0) {
            commands.push({ cmd: "flatpak", args: ["update", "-y"] })
        }

        runCommandQueue(commands, 0, function() {
            service.isUpdating = false
            service.statusMessage = "Update complete"
            service.refresh()
        })
    }

    // ── Run a queue of commands sequentially ──────────────────
    function runCommandQueue(queue, idx, onDone) {
        if (idx >= queue.length) { onDone(); return }
        var entry = queue[idx]
        var p = Process.create(entry.cmd, entry.args)
        p.finished.connect(function(exitCode) {
            if (exitCode !== 0) {
                service.statusMessage = "Command failed: " + entry.cmd + " (exit " + exitCode + ")"
            }
            runCommandQueue(queue, idx + 1, onDone)
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Update by category
    // ═══════════════════════════════════════════════════════════
    function updateCategory(category) {
        if (service.isUpdating) return
        service.isUpdating = true
        service.statusMessage = "Updating " + category + "…"

        var cmd, args
        if (category === "pacman") {
            cmd = "pkexec"; args = ["pacman", "-Syu", "--noconfirm"]
        } else if (category === "aur") {
            cmd = effectiveAurHelper()
            args = ["-Syu", "--noconfirm"]
            if (service.skipPkgbuild)    args.push("--noconfirm")
            if (service.removeBuildDeps) args.push("--removemake")
        } else {
            cmd = "flatpak"; args = ["update", "-y"]
        }

        var p = Process.create(cmd, args)
        p.finished.connect(function(exitCode) {
            service.isUpdating = false
            service.statusMessage = exitCode === 0
                ? category + " updated"
                : category + " update failed (exit " + exitCode + ")"
            service.refresh()
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Update single package
    // ═══════════════════════════════════════════════════════════
    function updatePackage(pkgName, source) {
        if (service.isUpdating) return
        service.isUpdating = true
        service.statusMessage = "Updating " + pkgName + "…"

        var cmd, args
        if (source === "pacman") {
            cmd = "pkexec"; args = ["pacman", "-S", pkgName, "--noconfirm"]
        } else if (source === "aur") {
            cmd = effectiveAurHelper()
            args = ["-S", pkgName, "--noconfirm"]
            if (service.skipPkgbuild)    args.push("--noconfirm")
            if (service.removeBuildDeps) args.push("--removemake")
        } else {
            cmd = "flatpak"; args = ["update", "-y", pkgName]
        }

        var p = Process.create(cmd, args)
        p.finished.connect(function(exitCode) {
            service.isUpdating = false
            service.statusMessage = exitCode === 0
                ? pkgName + " updated"
                : pkgName + " failed (exit " + exitCode + ")"
            service.refresh()
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Remove Pacman lock
    // ═══════════════════════════════════════════════════════════
    function removeLock() {
        service.statusMessage = "Removing pacman lock…"
        var p = Process.create("pkexec", ["rm", "-f", "/var/lib/pacman/db.lck"])
        p.finished.connect(function(exitCode) {
            service.statusMessage = exitCode === 0
                ? "Lock removed"
                : "Failed to remove lock"
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Persistence helpers
    // ═══════════════════════════════════════════════════════════
    function saveSetting(key, value) {
        pluginApi.set(key, value)
    }

    // ═══════════════════════════════════════════════════════════
    //  Initialization
    // ═══════════════════════════════════════════════════════════
    Component.onCompleted: {
        detectAurHelper()
        refresh()
    }
}
