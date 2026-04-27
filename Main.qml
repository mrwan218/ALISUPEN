import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

/*  Alisupen – Main.qml
 *  Background service: periodic update checks, command execution,
 *  and data exposed to BarWidget.qml via pluginApi.mainInstance.
 *
 *  Uses Quickshell.Io Process for running system commands.
 *  Uses pluginApi.pluginSettings + pluginApi.saveSettings() for persistence.
 *  Uses IpcHandler for inter-plugin / CLI communication.
 */

Item {
    id: service

    // ── Injected by PluginService ────────────────────────────
    property var pluginApi: null

    // ── Exposed to BarWidget via pluginApi.mainInstance ──────
    property int    pacmanCount: 0
    property int    aurCount: 0
    property int    flatpakCount: 0
    property var    pendingPackages: []
    property bool   isRefreshing: false
    property bool   isUpdating: false
    property string statusMessage: "Idle"
    property real   updateProgress: 0.0
    property string detectedHelper: ""

    // ── Settings shortcuts ───────────────────────────────────
    readonly property var s: pluginApi?.pluginSettings ?? ({})

    readonly property int    refreshInterval: s.refreshInterval ?? 30
    readonly property bool   showPacman:      s.showPacman ?? true
    readonly property bool   showAur:         s.showAur ?? true
    readonly property bool   showFlatpak:     s.showFlatpak ?? true
    readonly property string aurHelper:       s.aurHelper ?? "auto"
    readonly property bool   skipPkgbuild:    s.skipPkgbuild ?? false
    readonly property bool   removeBuildDeps: s.removeBuildDeps ?? true
    readonly property var    excludedPkgs:    s.excludedPkgs ?? []

    // ═══════════════════════════════════════════════════════════
    //  IPC Handler — allows CLI/launcher interaction
    // ═══════════════════════════════════════════════════════════
    IpcHandler {
        target: "plugin:alisupen"

        function refresh(): void {
            service.refresh()
        }

        function updateAll(): void {
            service.updateAll()
        }

        function updateCategory(category: string): void {
            service.updateCategory(category)
        }

        function removeLock(): void {
            service.removeLock()
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Periodic refresh timer
    // ═══════════════════════════════════════════════════════════
    Timer {
        id: refreshTimer
        interval: Math.max(service.refreshInterval, 5) * 60 * 1000
        running: true
        repeat: true
        onTriggered: service.refresh()
        onIntervalChanged: restart()
    }

    // ═══════════════════════════════════════════════════════════
    //  AUR helper auto-detection
    // ═══════════════════════════════════════════════════════════
    Process {
        id: detectParu
        command: ["which", "paru"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            if (code === 0) {
                service.detectedHelper = "paru"
            } else {
                detectYay.running = true
            }
        }
    }

    Process {
        id: detectYay
        running: false
        command: ["which", "yay"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            service.detectedHelper = (code === 0) ? "yay" : ""
            if (service.detectedHelper === "") {
                service.statusMessage = "No AUR helper found (install paru or yay)"
            }
        }
    }

    function effectiveAurHelper(): string {
        if (service.aurHelper === "auto") {
            if (service.detectedHelper === "") {
                detectParu.running = true
            }
            return service.detectedHelper || "paru"
        }
        return service.aurHelper
    }

    // ═══════════════════════════════════════════════════════════
    //  Process helpers for update checks
    // ═══════════════════════════════════════════════════════════

    // ── Pacman check ─────────────────────────────────────────
    Process {
        id: checkPacman
        command: ["pacman", "-Qu"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim()
                var pkgs = []
                if (lines.length > 0) {
                    var items = lines.split("\n")
                    for (var i = 0; i < items.length; i++) {
                        var line = items[i].trim()
                        if (line.length === 0) continue
                        var match = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                        if (match) {
                            pkgs.push({ name: match[1], version: match[3], source: "pacman", size: "" })
                        } else {
                            var parts = line.split(/\s+/)
                            if (parts.length >= 1) {
                                pkgs.push({ name: parts[0], version: parts.length > 1 ? parts[parts.length-1] : "?", source: "pacman", size: "" })
                            }
                        }
                    }
                }
                service._pacmanResult = pkgs
                service._pacmanDone = true
                service._maybeFinishRefresh()
            }
        }
    }

    // ── AUR check ────────────────────────────────────────────
    Process {
        id: checkAur
        command: [service.effectiveAurHelper(), "-Qua"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim()
                var pkgs = []
                if (lines.length > 0) {
                    var items = lines.split("\n")
                    for (var i = 0; i < items.length; i++) {
                        var line = items[i].trim()
                        if (line.length === 0) continue
                        var match = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
                        if (match) {
                            pkgs.push({ name: match[1], version: match[3], source: "aur", size: "" })
                        } else {
                            var parts = line.split(/\s+/)
                            if (parts.length >= 1) {
                                pkgs.push({ name: parts[0], version: parts.length > 1 ? parts[parts.length-1] : "?", source: "aur", size: "" })
                            }
                        }
                    }
                }
                service._aurResult = pkgs
                service._aurDone = true
                service._maybeFinishRefresh()
            }
        }
    }

    // ── Flatpak check ────────────────────────────────────────
    Process {
        id: checkFlatpak
        command: ["flatpak", "remote-ls", "--updates", "flathub"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim()
                var pkgs = []
                if (lines.length > 0) {
                    var items = lines.split("\n")
                    for (var i = 0; i < items.length; i++) {
                        var line = items[i].trim()
                        if (line.length === 0 || line.startsWith("Ref")) continue
                        var parts = line.split(/\s+/)
                        if (parts.length >= 1) {
                            pkgs.push({ name: parts[0], version: parts.length > 1 ? parts[1] : "?", source: "flatpak", size: "" })
                        }
                    }
                }
                service._flatpakResult = pkgs
                service._flatpakDone = true
                service._maybeFinishRefresh()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Refresh logic
    // ═══════════════════════════════════════════════════════════
    property var _pacmanResult: []
    property var _aurResult: []
    property var _flatpakResult: []
    property bool _pacmanDone: false
    property bool _aurDone: false
    property bool _flatpakDone: false

    function refresh() {
        if (service.isRefreshing) return
        service.isRefreshing = true
        service.statusMessage = "Checking for updates…"

        service._pacmanResult = []
        service._aurResult = []
        service._flatpakResult = []
        service._pacmanDone = !service.showPacman
        service._aurDone = !service.showAur
        service._flatpakDone = !service.showFlatpak

        // If nothing to check
        if (service._pacmanDone && service._aurDone && service._flatpakDone) {
            service.isRefreshing = false
            service.statusMessage = "No sources enabled"
            return
        }

        // Fire off checks
        if (service.showPacman)  checkPacman.running = true
        if (service.showAur)     checkAur.running = true
        if (service.showFlatpak) checkFlatpak.running = true

        // If all sources are disabled, finish immediately
        service._maybeFinishRefresh()
    }

    function _maybeFinishRefresh() {
        if (!service._pacmanDone || !service._aurDone || !service._flatpakDone) return

        var allPkgs = []
        var pacCount = 0, aCount = 0, flatCount = 0

        for (var i = 0; i < service._pacmanResult.length; i++) {
            allPkgs.push(service._pacmanResult[i])
            pacCount++
        }
        for (var i = 0; i < service._aurResult.length; i++) {
            allPkgs.push(service._aurResult[i])
            aCount++
        }
        for (var i = 0; i < service._flatpakResult.length; i++) {
            allPkgs.push(service._flatpakResult[i])
            flatCount++
        }

        // Filter excluded
        var excludedList = service.excludedPkgs || []
        var filtered = []
        for (var i = 0; i < allPkgs.length; i++) {
            var isExcluded = false
            for (var j = 0; j < excludedList.length; j++) {
                if (allPkgs[i].name === excludedList[j]) {
                    isExcluded = true
                    break
                }
            }
            if (!isExcluded) filtered.push(allPkgs[i])
        }

        // Sort: pacman → aur → flatpak, alphabetical within
        filtered.sort(function(a, b) {
            var order = { pacman: 0, aur: 1, flatpak: 2 }
            var diff = (order[a.source] || 0) - (order[b.source] || 0)
            if (diff !== 0) return diff
            return a.name.localeCompare(b.name)
        })

        service.pendingPackages = filtered
        service.pacmanCount = pacCount
        service.aurCount = aCount
        service.flatpakCount = flatCount
        service.isRefreshing = false

        var total = pacCount + aCount + flatCount
        service.statusMessage = total > 0 ? total + " update(s) available" : "System is up to date"

        // Desktop notification
        if (total > 0) {
            notifyUpdates(total, pacCount, aCount, flatCount)
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  Update All
    // ═══════════════════════════════════════════════════════════
    Process {
        id: updatePacman
        command: ["pkexec", "pacman", "-Syu", "--noconfirm"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            if (code !== 0) service.statusMessage = "Pacman update failed (exit " + code + ")"
            service._runNextUpdateCommand()
        }
    }

    Process {
        id: updateAur
        command: {
            var helper = service.effectiveAurHelper()
            var args = [helper, "-Syu", "--noconfirm"]
            if (service.skipPkgbuild) args.push("--noconfirm")
            if (service.removeBuildDeps) args.push("--removemake")
            return args
        }
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            if (code !== 0) service.statusMessage = "AUR update failed (exit " + code + ")"
            service._runNextUpdateCommand()
        }
    }

    Process {
        id: updateFlatpak
        command: ["flatpak", "update", "-y"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            if (code !== 0) service.statusMessage = "Flatpak update failed (exit " + code + ")"
            service._runNextUpdateCommand()
        }
    }

    property var _updateQueue: []
    property int _updateQueueIndex: 0

    function updateAll() {
        if (service.isUpdating || service.isRefreshing) return
        service.isUpdating = true
        service.updateProgress = 0
        service.statusMessage = "Updating all packages…"

        var queue = []
        if (service.pacmanCount > 0)  queue.push("pacman")
        if (service.aurCount > 0)     queue.push("aur")
        if (service.flatpakCount > 0) queue.push("flatpak")

        if (queue.length === 0) {
            service.isUpdating = false
            service.statusMessage = "Nothing to update"
            return
        }

        service._updateQueue = queue
        service._updateQueueIndex = 0
        service._runNextUpdateCommand()
    }

    function _runNextUpdateCommand() {
        if (service._updateQueueIndex >= service._updateQueue.length) {
            // All done
            service.isUpdating = false
            service.updateProgress = 1.0
            service.statusMessage = "Update complete"
            resetProgressTimer.start()
            service.refresh()
            return
        }

        var current = service._updateQueue[service._updateQueueIndex]
        service.statusMessage = "Updating " + current + "…"
        service.updateProgress = service._updateQueueIndex / service._updateQueue.length

        if (current === "pacman") {
            updatePacman.running = true
        } else if (current === "aur") {
            updateAur.running = true
        } else if (current === "flatpak") {
            updateFlatpak.running = true
        }

        service._updateQueueIndex++
    }

    // ── Category update ──────────────────────────────────────
    Process {
        id: updateCategoryPacman
        command: ["pkexec", "pacman", "-Syu", "--noconfirm"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            service.isUpdating = false
            service.statusMessage = code === 0 ? "Pacman updated" : "Pacman update failed"
            resetProgressTimer.start()
            service.refresh()
        }
    }

    Process {
        id: updateCategoryAur
        command: {
            var helper = service.effectiveAurHelper()
            var args = [helper, "-Syu", "--noconfirm"]
            if (service.skipPkgbuild) args.push("--noconfirm")
            if (service.removeBuildDeps) args.push("--removemake")
            return args
        }
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            service.isUpdating = false
            service.statusMessage = code === 0 ? "AUR updated" : "AUR update failed"
            resetProgressTimer.start()
            service.refresh()
        }
    }

    Process {
        id: updateCategoryFlatpak
        command: ["flatpak", "update", "-y"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            service.isUpdating = false
            service.statusMessage = code === 0 ? "Flatpak updated" : "Flatpak update failed"
            resetProgressTimer.start()
            service.refresh()
        }
    }

    function updateCategory(category: string) {
        if (service.isUpdating || service.isRefreshing) return
        service.isUpdating = true
        service.updateProgress = 0
        service.statusMessage = "Updating " + category + "…"

        if (category === "pacman")       updateCategoryPacman.running = true
        else if (category === "aur")     updateCategoryAur.running = true
        else if (category === "flatpak") updateCategoryFlatpak.running = true
    }

    // ── Single package update ────────────────────────────────
    Process {
        id: updateSinglePkg
        property string pkgName: ""
        property string pkgSource: ""
        command: {
            if (pkgSource === "pacman")       return ["pkexec", "pacman", "-S", pkgName, "--noconfirm"]
            else if (pkgSource === "aur")     {
                var helper = service.effectiveAurHelper()
                var args = [helper, "-S", pkgName, "--noconfirm"]
                if (service.skipPkgbuild) args.push("--noconfirm")
                if (service.removeBuildDeps) args.push("--removemake")
                return args
            }
            else                              return ["flatpak", "update", "-y", pkgName]
        }
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            service.isUpdating = false
            service.statusMessage = code === 0 ? pkgName + " updated" : pkgName + " failed"
            service.refresh()
        }
    }

    function updatePackage(pkgName: string, source: string) {
        if (service.isUpdating || service.isRefreshing) return
        service.isUpdating = true
        service.updateProgress = 0
        service.statusMessage = "Updating " + pkgName + "…"
        updateSinglePkg.pkgName = pkgName
        updateSinglePkg.pkgSource = source
        updateSinglePkg.running = true
    }

    // ═══════════════════════════════════════════════════════════
    //  Remove Pacman Lock
    // ═══════════════════════════════════════════════════════════
    Process {
        id: removeLockProc
        command: ["pkexec", "rm", "-f", "/var/lib/pacman/db.lck"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: function(code) {
            service.statusMessage = code === 0 ? "Lock removed" : "Failed to remove lock"
        }
    }

    function removeLock() {
        service.statusMessage = "Removing pacman lock…"
        removeLockProc.running = true
    }

    // ═══════════════════════════════════════════════════════════
    //  Desktop notification
    // ═══════════════════════════════════════════════════════════
    Process {
        id: notifyProc
        property string summary: ""
        property string body: ""
        command: ["notify-send", "-a", "Alisupen", "-i", "system-software-update", "-u", "normal", summary, body]
        stdout: StdioCollector { onStreamFinished: {} }
    }

    function notifyUpdates(total: int, pac: int, aur: int, flat: int) {
        var body = ""
        if (pac > 0)  body += pac + " Pacman"
        if (aur > 0)  body += (body ? ", " : "") + aur + " AUR"
        if (flat > 0) body += (body ? ", " : "") + flat + " Flatpak"

        notifyProc.summary = total + " updates available"
        notifyProc.body = body
        notifyProc.running = true
    }

    // ═══════════════════════════════════════════════════════════
    //  Timers
    // ═══════════════════════════════════════════════════════════
    Timer {
        id: resetProgressTimer
        interval: 2000
        onTriggered: {
            service.updateProgress = 0
        }
    }

    Timer {
        id: initialDelay
        interval: 3000
        onTriggered: service.refresh()
    }

    // ═══════════════════════════════════════════════════════════
    //  Initialization
    // ═══════════════════════════════════════════════════════════
    Component.onCompleted: {
        detectParu.running = true
        initialDelay.start()
    }
}
