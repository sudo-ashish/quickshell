// Helper functions for Launcher search and mode management

function normalizeText(text) {
    return String(text || "").toLowerCase().trim();
}

var KNOWN_ICON_MAP = {
    "whatsapp": "file:///home/pear/.local/share/icons/hicolor/256x256/apps/whatsapp.png",
    "antigravity": "file:///usr/share/pixmaps/antigravity.png",
    "antigravity-ide": "file:///usr/share/pixmaps/antigravity-ide.png",
    "antigravity-ide-url-handler": "file:///usr/share/pixmaps/antigravity-ide.png",
    "nwg-look": "file:///usr/share/pixmaps/nwg-look.svg",
    "pinentry": "file:///usr/share/pixmaps/pinentry.png",
    "spotify-launcher": "file:///usr/share/pixmaps/spotify-launcher.png",
    "network-wired": "file:///usr/share/icons/Adwaita/symbolic/devices/network-wired-symbolic.svg",
    "multimedia-photo-viewer": "file:///usr/share/icons/Adwaita/symbolic/categories/applications-multimedia-symbolic.svg"
};

function resolveIcon(icon) {
    if (!icon || icon === "") return "";
    var s = String(icon).trim();
    if (s.startsWith("file://") || s.startsWith("image://")) return s;
    if (s.startsWith("/")) return "file://" + s;

    var cleaned = s.replace(/\.(png|svg|xpm|ico)$/i, "");
    var lower = cleaned.toLowerCase();
    if (KNOWN_ICON_MAP[lower]) {
        return KNOWN_ICON_MAP[lower];
    }
    if (KNOWN_ICON_MAP[cleaned]) {
        return KNOWN_ICON_MAP[cleaned];
    }

    return "image://icon/" + cleaned;
}

// Apps mode filtering and sorting
function filterApps(apps, query) {
    var q = normalizeText(query);
    var results = [];
    if (!apps || !apps.length) return results;

    for (var i = 0; i < apps.length; i++) {
        var app = apps[i];
        if (!app || app.noDisplay) continue;

        var name = String(app.name || app.id || "").trim();
        if (!name) continue;

        var generic = String(app.genericName || "").trim();
        var comment = String(app.comment || "").trim();
        var id = String(app.id || "").trim();
        var keywords = "";
        try {
            if (app.keywords && Array.isArray(app.keywords)) {
                keywords = app.keywords.join(" ");
            }
        } catch (e) {}

        var score = 0;
        if (!q) {
            score = 1;
        } else {
            var nameLower = name.toLowerCase();
            var idLower = id.toLowerCase();
            var genericLower = generic.toLowerCase();
            var commentLower = comment.toLowerCase();
            var keywordsLower = keywords.toLowerCase();

            if (nameLower === q) score += 1000;
            else if (nameLower.startsWith(q)) score += 500;
            else if (nameLower.indexOf(q) !== -1) score += 200;
            else if (idLower.startsWith(q)) score += 150;
            else if (idLower.indexOf(q) !== -1) score += 100;
            else if (genericLower.indexOf(q) !== -1) score += 80;
            else if (keywordsLower.indexOf(q) !== -1) score += 50;
            else if (commentLower.indexOf(q) !== -1) score += 30;
            else {
                // Acronym search (e.g. "ide" matches "Antigravity IDE")
                var words = nameLower.split(/[\s\-_]+/);
                var acronym = "";
                for (var w = 0; w < words.length; w++) {
                    if (words[w]) acronym += words[w].charAt(0);
                }
                if (acronym.indexOf(q) !== -1) score += 40;
            }
        }

        if (score > 0) {
            results.push({
                type: "app",
                id: id,
                name: name,
                generic: generic,
                icon: resolveIcon(app.icon),
                score: score,
                entry: app
            });
        }
    }

    results.sort(function(a, b) {
        if (q) {
            if (b.score !== a.score) return b.score - a.score;
        }
        return a.name.localeCompare(b.name);
    });

    return results;
}

// Windows mode parsing
function parseWindows(rawJson, query) {
    var q = normalizeText(query);
    var results = [];
    if (!rawJson) return results;

    var list = [];
    try {
        list = JSON.parse(rawJson);
    } catch (e) {
        return results;
    }

    if (!Array.isArray(list)) return results;

    for (var i = 0; i < list.length; i++) {
        var w = list[i];
        if (!w || !w.mapped || w.hidden) continue;

        var title = String(w.title || "").trim();
        var winClass = String(w.class || w.initialClass || "").trim();
        var wsName = w.workspace ? String(w.workspace.name || w.workspace.id || "") : "";
        var addr = String(w.address || "");

        var name = title || winClass || "Window";
        var generic = winClass + (wsName ? " · WS " + wsName : "");

        var match = !q || name.toLowerCase().indexOf(q) !== -1 || winClass.toLowerCase().indexOf(q) !== -1 || wsName.toLowerCase().indexOf(q) !== -1;
        if (match) {
            results.push({
                type: "window",
                id: addr,
                address: addr,
                name: name,
                generic: generic,
                icon: resolveIcon(winClass.toLowerCase()),
                workspaceId: w.workspace ? w.workspace.id : 1
            });
        }
    }

    return results;
}

// Run commands filtering
function filterCommands(binaries, query) {
    var q = normalizeText(query);
    var results = [];

    // Always put typed query as first "Run" action if non-empty
    if (query && query.trim().length > 0) {
        results.push({
            type: "command",
            id: "cmd-custom",
            name: query.trim(),
            generic: "Run Command",
            icon: resolveIcon("system-run"),
            cmd: query.trim()
        });
    }

    if (!binaries || !binaries.length) return results;

    for (var i = 0; i < binaries.length; i++) {
        var b = binaries[i];
        if (!b) continue;
        if (!q || b.toLowerCase().indexOf(q) !== -1) {
            // Avoid duplicate with custom query
            if (query && b.toLowerCase() === q) continue;
            results.push({
                type: "command",
                id: "cmd-" + b,
                name: b,
                generic: "Command",
                icon: resolveIcon("utilities-terminal"),
                cmd: b
            });
            if (results.length >= 50) break;
        }
    }

    return results;
}

// Files mode parsing
function parseFiles(rawLines, query) {
    var q = normalizeText(query);
    var results = [];
    if (!rawLines) return results;

    var home = "";
    try {
        if (typeof Quickshell !== "undefined" && Quickshell.env) {
            home = Quickshell.env("HOME") || "";
        }
    } catch (e) {}

    var lines = String(rawLines).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) continue;
        var parts = line.split("\t");
        var filename = parts[0] || "";
        var fullpath = parts[1] || line;
        var isDir = parts[2] === "d";

        if (!filename && fullpath) {
            var slashIdx = fullpath.lastIndexOf("/");
            filename = slashIdx >= 0 ? fullpath.substring(slashIdx + 1) : fullpath;
        }

        if (!filename) continue;

        if (!q || filename.toLowerCase().indexOf(q) !== -1 || fullpath.toLowerCase().indexOf(q) !== -1) {
            var displayPath = home ? fullpath.replace(home, "~") : fullpath.replace(/^\/home\/[^\/]+/, "~");
            results.push({
                type: "file",
                id: fullpath,
                name: filename,
                generic: displayPath,
                icon: isDir ? resolveIcon("folder") : resolveIcon("text-x-generic"),
                path: fullpath,
                isDir: isDir
            });
            if (results.length >= 50) break;
        }
    }

    return results;
}

if (typeof module !== "undefined") {
    module.exports = {
        normalizeText: normalizeText,
        resolveIcon: resolveIcon,
        filterApps: filterApps,
        parseWindows: parseWindows,
        filterCommands: filterCommands,
        parseFiles: parseFiles
    };
}
