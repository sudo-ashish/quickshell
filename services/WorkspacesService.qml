import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    readonly property var workspaceIds: {
        var ids = [1, 2, 3, 4, 5]
        var list = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < list.length; i++) {
            var id = list[i].id
            if (id > 0 && id <= 10 && ids.indexOf(id) === -1) {
                ids.push(id)
            }
        }
        ids.sort(function(a, b) { return a - b })
        return ids
    }

    readonly property var occupiedWorkspaces: {
        var occ = {}
        var list = Hyprland.workspaces ? Hyprland.workspaces.values : []
        for (var i = 0; i < list.length; i++) {
            var ws = list[i]
            if (ws && ws.id > 0) {
                occ[ws.id] = (ws.toplevels && ws.toplevels.values.length > 0)
            }
        }
        return occ
    }

    function switchTo(id) {
        if (!id) return
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
        } else {
            Hyprland.dispatch("workspace " + id)
        }
    }

    function next() {
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"+1\" })")
        } else {
            Hyprland.dispatch("workspace e+1")
        }
    }

    function prev() {
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"-1\" })")
        } else {
            Hyprland.dispatch("workspace e-1")
        }
    }
}
