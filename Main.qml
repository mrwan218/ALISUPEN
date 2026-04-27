import QtQuick 2.15

/*  Alisupen – Main.qml
 *  Background service: periodic update checks, command execution,
 *  and data flow to BarWidget.qml.
 *
 *  Uses the Noctalia Process API for running system commands and
 *  pluginApi for persistent settings.
 *
 *  Architecture:
 *  - Timer drives periodic refresh (configurable interval)
 *  - Process.create() runs pacman/paru/yay/flatpak commands asynchronously
 *  - Results are collected and pushed to BarWidget via property bindings
 *  - pluginApi.get/set for all user-configurable settings
 */

QtObject {
    id: service

    // ── Exposed to BarWidget ─────────────────────────────────
    property int    pacmanCount: 0
    property int    aurCount: 0
    property int    flatpakCount: 0
    property var    pendingPackages: []
    property bool   isRefreshing: false
    property bool   isUpdating: false
    property string statusMessage: "Idle"
    property real   updateProgress: 0.0

    // ── Settings (persisted via pluginApi) ────────────────────
    property int    refreshInterval: pluginApi.get("refreshInterval", 30)
    property bool   showPacman:      pluginApi.get("showPacman", true)
    property bool   showAur:         pluginApi.get("showAur", true)
    property bool   showFlatpak:     pluginApi.get("showFlatpak", true)
    property string aurHelper:       pluginApi.get("aurHelper", "auto")
    property bool   skipPkgbuild:    pluginApi.get("skipPkgbuild", false)
    property bool   removeBuildDeps: pluginApi.get("removeBuildDeps", true)
    property var    excludedPkgs:    pluginApi.get("excludedPkgs", [])

    // ── Internal ─────────────────────────────────────────────
    property string _detectedHelper: ""
    property var    _updateQueue: []       // packages being updated
    property int    _updateCompleted: 0
    property int    _updateTotal: 0

    // ═══════════════════════════════════════════════════════════
    //  Periodic refresh timer
    // ═══════════════════════════════════════════════════════════
    Timer {
        id: refreshTimer
        interval: Math.max(service.refreshInterval, 5) * 60 * 1000
        running: true
        repeat: true
        onTriggered: service.refresh()

        onIntervalChanged: {
            // Restart timer when interval changes
            restart()
        }
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
                    if (service._detectedHelper === "") {
                        service.statusMessage = "No AUR helper found (install paru or yay)"
                    }
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
    //  Refresh – check for available updates from all sources
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
                var excludedList = service.excludedPkgs || []
                for (var i = 0; i < newPackages.length; i++) {
                    var isExcluded = false
                    for (var j = 0; j < excludedList.length; j++) {
                        if (newPackages[i].name === excludedList[j]) {
                            isExcluded = true
                            break
                        }
                    }
                    if (!isExcluded) {
                        filtered.push(newPackages[i])
                    }
                }

                // Sort: pacman first, then AUR, then Flatpak; alphabetical within each
                filtered.sort(function(a, b) {
                    var order = { pacman: 0, aur: 1, flatpak: 2 }
                    var diff = (order[a.source] || 0) - (order[b.source] || 0)
                    if (diff !== 0) return diff
                    return a.name.localeCompare(b.name)
                })

                service.pendingPackages = filtered
                service.pacmanCount = pacCount
                service.aurCount   = aCount
                service.flatpakCount = flatCount
                service.isRefreshing = false

                var total = pacCount + aCount + flatCount
                service.statusMessage = total > 0
                    ? total + " update(s) available"
                    : "System is up to date"

                // Send desktop notification for new updates
                if (total > 0) {
                    notifyUpdates(total, pacCount, aCount, flatCount)
                }
            }
        }

        // ── Pacman ────────────────────────────────────────────
        if (service.showPacman) {
            var pPac = Process.create("pacman", ["-Qu"])
            var pacOutput = ""
            pPac.stdout.connect(function(lines) {
                pacOutput += lines
            })
            pPac.finished.connect(function(exitCode) {
                if (exitCode === 0 && pacOutput.trim().length > 0) {
                    var items = pacOutput.trim().split("\n")
                    for (var i = 0; i < items.length; i++) {
                        var line = items[i].trim()
                        if (line.length === 0) continue
                        // pacman -Qu format: "package_name old_version -> new_version"
                        var match = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                        if (match) {
                            newPackages.push({
                                name:    match[1],
                                version: match[3],
                                source:  "pacman",
                                size:    ""
                            })
                            pacCount++
                        } else {
                            // Fallback parsing
                            var parts = line.split(/\s+/)
                            if (parts.length >= 1) {
                                newPackages.push({
                                    name:    parts[0],
                                    version: parts.length > 1 ? parts[parts.length - 1] : "?",
                                    source:  "pacman",
                                    size:    ""
                                })
                                pacCount++
                            }
                        }
                    }
                }
                maybeFinish()
            })
            pPac.start()
        }

        // ── AUR ───────────────────────────────────────────────
        if (service.showAur) {
            var helper = effectiveAurHelper()
            var pAur = Process.create(helper, ["-Qua"])
            var aurOutput = ""
            pAur.stdout.connect(function(lines) {
                aurOutput += lines
            })
            pAur.finished.connect(function(exitCode) {
                if (exitCode === 0 && aurOutput.trim().length > 0) {
                    var items = aurOutput.trim().split("\n")
                    for (var i = 0; i < items.length; i++) {
                        var line = items[i].trim()
                        if (line.length === 0) continue
                        var match = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                        if (match) {
                            newPackages.push({
                                name:    match[1],
                                version: match[3],
                                source:  "aur",
                                size:    ""
                            })
                            aCount++
                        } else {
                            var parts = line.split(/\s+/)
                            if (parts.length >= 1) {
                                newPackages.push({
                                    name:    parts[0],
                                    version: parts.length > 1 ? parts[parts.length - 1] : "?",
                                    source:  "aur",
                                    size:    ""
                                })
                                aCount++
                            }
                        }
                    }
                }
                maybeFinish()
            })
            pAur.start()
        }

        // ── Flatpak ───────────────────────────────────────────
        if (service.showFlatpak) {
            var pFlat = Process.create("flatpak", ["remote-ls", "--updates", "flathub"])
            var flatOutput = ""
            pFlat.stdout.connect(function(lines) {
                flatOutput += lines
            })
            pFlat.finished.connect(function(exitCode) {
                if (exitCode === 0 && flatOutput.trim().length > 0) {
                    var items = flatOutput.trim().split("\n")
                    for (var i = 0; i < items.length; i++) {
                        var line = items[i].trim()
                        if (line.length === 0 || line.startsWith("Ref")) continue
                        // flatpak remote-ls --updates format columns
                        var parts = line.split(/\s+/)
                        if (parts.length >= 1) {
                            var appId = parts[0]
                            var version = parts.length > 1 ? parts[1] : "?"
                            var dlSize = ""
                            // Find download size column
                            for (var p = 2; p < parts.length; p++) {
                                if (parts[p].match(/^\d/)) {
                                    dlSize = parts[p]
                                    break
                                }
                            }
                            newPackages.push({
                                name:    appId,
                                version: version,
                                source:  "flatpak",
                                size:    dlSize ? formatSize(dlSize) : ""
                            })
                            flatCount++
                        }
                    }
                }
                maybeFinish()
            })
            pFlat.start()
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Update All
    // ═══════════════════════════════════════════════════════════
    function updateAll() {
        if (service.isUpdating || service.isRefreshing) return
        service.isUpdating = true
        service.updateProgress = 0
        service.statusMessage = "Updating all packages…"

        var commands = []
        var totalSteps = 0

        if (service.pacmanCount > 0) {
            commands.push({ cmd: "pkexec", args: ["pacman", "-Syu", "--noconfirm"], label: "pacman" })
            totalSteps += service.pacmanCount
        }
        if (service.aurCount > 0) {
            var helper = effectiveAurHelper()
            var aurArgs = ["-Syu", "--noconfirm"]
            if (service.skipPkgbuild)    aurArgs.push("--noconfirm")
            if (service.removeBuildDeps) aurArgs.push("--removemake")
            commands.push({ cmd: helper, args: aurArgs, label: "aur" })
            totalSteps += service.aurCount
        }
        if (service.flatpakCount > 0) {
            commands.push({ cmd: "flatpak", args: ["update", "-y"], label: "flatpak" })
            totalSteps += service.flatpakCount
        }

        service._updateTotal = totalSteps
        service._updateCompleted = 0

        runCommandQueue(commands, 0, function() {
            service.isUpdating = false
            service.updateProgress = 1.0
            service.statusMessage = "Update complete"
            // Brief delay then reset progress bar
            resetTimer.start()
            service.refresh()
        })
    }

    Timer {
        id: resetTimer
        interval: 2000
        onTriggered: {
            service.updateProgress = 0
            service._updateCompleted = 0
            service._updateTotal = 0
        }
    }

    // ── Run a queue of commands sequentially ──────────────────
    function runCommandQueue(queue, idx, onDone) {
        if (idx >= queue.length) { onDone(); return }
        var entry = queue[idx]
        service.statusMessage = "Updating " + entry.label + "…"

        var p = Process.create(entry.cmd, entry.args)
        p.stdout.connect(function(lines) {
            // Track progress based on output lines
            var lineCount = lines.split("\n").filter(function(l) { return l.trim().length > 0 }).length
            service._updateCompleted += lineCount
            if (service._updateTotal > 0) {
                service.updateProgress = Math.min(0.95, service._updateCompleted / service._updateTotal)
            }
        })
        p.finished.connect(function(exitCode) {
            if (exitCode !== 0) {
                service.statusMessage = entry.label + " failed (exit " + exitCode + ")"
            }
            runCommandQueue(queue, idx + 1, onDone)
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Update by category
    // ═══════════════════════════════════════════════════════════
    function updateCategory(category) {
        if (service.isUpdating || service.isRefreshing) return
        service.isUpdating = true
        service.updateProgress = 0
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
            service.updateProgress = exitCode === 0 ? 1.0 : 0
            service.statusMessage = exitCode === 0
                ? category + " updated successfully"
                : category + " update failed (exit " + exitCode + ")"
            resetTimer.start()
            service.refresh()
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Update single package
    // ═══════════════════════════════════════════════════════════
    function updatePackage(pkgName, source) {
        if (service.isUpdating || service.isRefreshing) return
        service.isUpdating = true
        service.updateProgress = 0
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
            service.updateProgress = 0
            service.statusMessage = exitCode === 0
                ? pkgName + " updated successfully"
                : pkgName + " failed (exit " + exitCode + ")"
            service.refresh()
        })
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Remove Pacman lock file
    // ═══════════════════════════════════════════════════════════
    function removeLock() {
        service.statusMessage = "Removing pacman lock…"

        // Check if lock exists first
        var pCheck = Process.create("test", ["-f", "/var/lib/pacman/db.lck"])
        pCheck.finished.connect(function(exitCode) {
            if (exitCode !== 0) {
                service.statusMessage = "No lock file found"
                return
            }
            var pRm = Process.create("pkexec", ["rm", "-f", "/var/lib/pacman/db.lck"])
            pRm.finished.connect(function(ec) {
                service.statusMessage = ec === 0
                    ? "Pacman lock removed successfully"
                    : "Failed to remove lock (permission denied?)"
            })
            pRm.start()
        })
        pCheck.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Desktop notification
    // ═══════════════════════════════════════════════════════════
    function notifyUpdates(total, pac, aur, flat) {
        var body = ""
        if (pac > 0)  body += pac + " Pacman"
        if (aur > 0)  body += (body ? ", " : "") + aur + " AUR"
        if (flat > 0) body += (body ? ", " : "") + flat + " Flatpak"

        var p = Process.create("notify-send", [
            "-a", "Alisupen",
            "-i", "system-software-update",
            "-u", "normal",
            total + " updates available",
            body
        ])
        p.start()
    }

    // ═══════════════════════════════════════════════════════════
    //  Utility
    // ═══════════════════════════════════════════════════════════
    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(1) + " GB"
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
        // Delay first refresh slightly to let shell settle
        initialDelay.start()
    }

    Timer {
        id: initialDelay
        interval: 3000
        onTriggered: service.refresh()
    }
}
