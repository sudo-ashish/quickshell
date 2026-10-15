# Quickshell Master Refactoring & Bugfix Prompt Suite
**Target Agent:** Antigravity IDE (3.8 Flash) + `quickshell-mcp`  
**Environment:** Arch Linux + Hyprland + Quickshell

You are tasked with executing a complete, four-part refactoring across this Quickshell repository. Because you have the **`quickshell-mcp`** server connected, you MUST use its source-grounding, static audit, live reload, and runtime assertion tools across all tasks. Do NOT skip files, hallucinate QML properties, or leave partial implementations.

---

## Global Pre-Flight: MCP Source Grounding & Discovery
Before modifying any files, invoke your `quickshell-mcp` tools to ground your implementation:
1. Run `quickshell_search` and `quickshell_get_implementation` to inspect how real-world Quickshell setups (such as Caelestia) structure `PanelWindow`, `WlrLayershell`, layer namespaces, theme singletons, and surface alpha tokens.
2. Run `quickshell_get_type` and `quickshell_get_qt_type` to verify exact property signatures for `PanelWindow`, `WlrLayershell`, `HyprlandFocusGrab`, `FileView`, and `Rectangle` so zero invalid QML properties are introduced.
3. Scan the entire workspace to build a complete inventory of all `.qml`, `.js`, `.toml`, and CLI bash scripts (`qs-osd`, `qs-dns`, etc.).

---

## Task 1: Strict Centralized Color System (`./theme/colors.toml`)

Audit and refactor the entire Quickshell project to enforce a strict, centralized color system driven exclusively by `./theme/colors.toml`.

### 1.1 Initialize `./theme/colors.toml` from `sample.toml`
- Copy the exact contents, color keys, and hex/RGBA values from `sample.toml` into `./theme/colors.toml`.
- **Strict Schema Constraint:** Do NOT invent, add, rename, or interpolate any extra color keys in `colors.toml`. Use the exact key names defined in `sample.toml`.

### 1.2 Single Source of Truth (`./theme/Theme.qml` Reference Singleton)
- Create or update a single QML singleton module (`./theme/Theme.qml` registered in `./theme/qmldir`) that acts as the ONLY file in the entire repository containing the file path to `./theme/colors.toml`.
- Parse `./theme/colors.toml` inside this single reference file and expose its exact color names as read-only properties.
- No other `.qml`, `.js`, or shell script in the project is permitted to reference the path `./theme/colors.toml` directly; every component must import `./theme` and read colors through this singleton so changing the path in the future requires editing only one line in one file.

### 1.3 Full-Project Color Audit & Dead Reference Purge
- Inspect **every single `.qml` and `.js` file** across the project (including `Osd.qml`, `Polkit.qml`, `AppLauncher.qml`, `Launcher.qml`, `ShellSurface.qml`, bar, panels, widgets, and models).
- **Eliminate Hardcoded Colors:** Find and replace all hardcoded hex strings (e.g., `"#fab387"`, `"#f38ba8"`, `"#efac82"`, `"#ffffff"`, `"#28ffffff"`, `"#66f38ba8"`) and raw `Qt.rgba(...)` / `Qt.darker(...)` / `Qt.lighter(...)` color hacks with the corresponding semantic properties from the `sample.toml` schema via the `Theme` singleton. (Only `"transparent"` is permitted for unstyled container backgrounds where required by Wayland layer-shell).
- **Remove Dead & Legacy Theme Properties:** Identify and delete any references to old or non-existent `Theme.*` properties (such as `Theme.overlayBackground`, `Theme.cardBackground`, `Theme.urgent`, etc.) that do not exist in `sample.toml`, remapping them strictly to the valid keys from `sample.toml`.
- **Remove Redundant Local Color Properties:** Strip out unnecessary intermediate color aliases on root items if they just duplicate or drift from the central theme.

---

## Task 2: Caelestia Two-Tier Blur Architecture Refactor

Refactor the codebase to use the **Caelestia two-tier alpha blur architecture** (`ignorealpha` compositor threshold masking) so blur dynamically follows floating cards, rounded corners, animations, and resizes without breaking.

### 2.1 Centralize Opacity Tiers in `./theme/Theme.qml`
While keeping `./theme/colors.toml` as the strict source for RGB values, add the Caelestia alpha tiers and helper method inside `Theme.qml`:
```qml
readonly property real baseOpacity: 0.82      // Tier 1 (> 0.57): Blurred primary cards, launcher, bar, OSD
readonly property real elevatedOpacity: 0.88  // Tier 1 (> 0.57): Blurred critical modals (Polkit)
readonly property real layerOpacity: 0.28     // Tier 2 (< 0.57): Unblurred inner inputs, wells, pills, list rows
readonly property real scrimOpacity: 0.35     // Tier 2 (< 0.57): Unblurred full-screen modal dimming backdrop

function withAlpha(colorVal, alphaVal) {
    return Qt.rgba(colorVal.r, colorVal.g, colorVal.b, alphaVal)
}
```

### 2.2 Purge Legacy / Broken Blur Logic
Across all `.qml` files, **delete**:
- Any QML shader blurs (`MultiEffect`, `FastBlur`, `GaussianBlur`, `ShaderEffectSource`, `layer.enabled` blur hacks).
- Any hardcoded blur `Region {}` masks or static width/height coordinate clipping intended for blur.
- Any `1.0` solid opaque backgrounds on surfaces meant to show compositor blur (solid paint blocks behind-window blur).
- Any full-screen backdrop scrims with effective alpha `> 0.45` (such as `Launcher.qml` setting `opacity: root.isOpen ? 1 : 0` on a full-screen `Rectangle`), which forces Hyprland to blur the entire monitor.

### 2.3 Apply Two-Tier Alpha Across All Shell Surfaces
Update every component so **Tier 1 (`>= 0.78`)** is used ONLY on the visual card/bar geometry you want blurred, and **Tier 2 (`<= 0.40`)** is used on everything else:
- **Every `PanelWindow` Root:**
  - Must have `color: "transparent"`.
  - Must have a consistent `WlrLayershell.namespace` prefixed with `quickshell-` (e.g., `"quickshell-launcher"`, `"quickshell-polkit"`, `"quickshell-osd"`, `"quickshell-bar"`, `"quickshell-notifications"`).
- **`ShellSurface.qml` (and shared card primitives):**
  - Default `surfaceColor` to `Theme.withAlpha(Theme.background, Theme.baseOpacity)`.
  - Ensure any outer shadow/glow layers stay strictly `<= 0.35` alpha so shadows never create rectangular blur halos around rounded corners.
- **`AppLauncher.qml` & `Launcher.qml`:**
  - Full-screen backdrop scrim: set `color: Theme.withAlpha(Theme.darker_background, Theme.scrimOpacity)` and animate `opacity` between `0.0` and `1.0` (max pixel alpha = `0.35`, preventing full-screen desktop blur).
  - Main launcher card (`ShellSurface` or `id: card`): set background to `Theme.withAlpha(Theme.background, Theme.baseOpacity)` (`0.82` -> blurred by Hyprland, automatically matching any width, height, or corner radius).
  - Search input bar, mode switcher pills (unselected), and list item rows (unselected/hovered): use `Theme.withAlpha(..., Theme.layerOpacity)` (`0.28`).
- **`Polkit.qml`:**
  - Full-screen scrim: cap pixel alpha at `Theme.scrimOpacity` (`0.35`).
  - Auth card (`id: card`): set `color: Theme.withAlpha(Theme.background, Theme.elevatedOpacity)` (`0.88`).
  - Password input box: use `Theme.withAlpha(..., Theme.layerOpacity)`.
- **`Osd.qml`:**
  - Pill card (`id: card`): set `color: Theme.withAlpha(Theme.background, Theme.baseOpacity)`.
  - Progress bar background track: keep alpha `<= 0.25`.

### 2.4 Configure Hyprland Compositor Layer Rules
Use your `quickshell-mcp` desktop environment tools (or update the project's Hyprland config files) to configure Caelestia's exact layer rules for `quickshell-.*`:
```ini
# Classic Hyprland syntax
layerrule = blur, ^(quickshell-.*)$
layerrule = blurpopups, ^(quickshell-.*)$
layerrule = ignorealpha 0.57, ^(quickshell-.*)$

# Hyprland v0.50+ layerrule v2 block syntax (use whichever matches the system's Hyprland version)
layerrule {
    name = quickshell-caelestia-blur
    match:namespace = ^quickshell-.*$
    blur = 1
    blur_popups = 1
    ignore_alpha = 0.57
}
```

---

## Task 3: Refactor `qs-dns` Script (Bugfixes, IPv6 Leaks & Conditional Polkit)

Refactor the `qs-dns` bash script for Arch Linux and Quickshell to eliminate silent failure traps, patch IPv6 leaks, and handle Polkit conditionally so an authentication prompt is only triggered if elevated permissions are strictly required.

### 3.1 Conditional Polkit Elevation (Prompt Only When Needed)
- Check if current user permissions allow modification without prompting (e.g., test via `pkcheck --action-id org.freedesktop.NetworkManager.settings.modify.system --process $$` or test the command directly).
- If executed as `root` or if Polkit rules already permit passwordless execution for the user's group (`wheel`), run the commands directly with zero prompts.
- If unprivileged and Polkit permissions are required, only invoke `pkexec` when authentication is genuinely necessary.
- For `systemd-resolved` (`resolvectl`), check if D-Bus policy allows user execution; do not blindly pass `--no-ask-password` unless handling failure gracefully.

### 3.2 Fix Network & DNS Traps
- **Patch IPv6 DNS Leaks & Respect `glibc` `MAXNS=3` Limit:** When applying Cloudflare or Google DNS, configure both IPv4 (`ipv4.ignore-auto-dns yes`) and IPv6 (`ipv6.ignore-auto-dns yes`, using `2606:4700:4700::1111 2606:4700:4700::1001` for Cloudflare and `2001:4860:4860::8888 2001:4860:4860::8844` for Google). Revert both IPv4 and IPv6 to automatic (`ignore-auto-dns no`, empty `dns ""`) for `DHCP`.
- **Remove Blind Muffling:** Stop using blanket `2>/dev/null || true` chains that cause the script to write the state file and claim success when NetworkManager or `resolvectl` actually failed. Only update `$DNS_STATE_FILE` after the DNS modification succeeds.
- **Dynamic Interface Reapplication:** Apply changes across active Ethernet/Wi-Fi devices via `nmcli dev reapply "$dev"`, falling back to `nmcli con up "$uuid"` if device reapply is unsupported.
- **Eliminate Subshell Overhead:** Replace `cat "$DNS_STATE_FILE" | tr` with built-in bash redirection (`tr -d '[:space:]' < "$DNS_STATE_FILE"`).
- Maintain strict `set -euo pipefail` without breaking on empty query results.
- Provide the optional `/etc/polkit-1/rules.d/50-nm-dns.rules` snippet for passwordless `wheel` group execution.

---

## Task 4: Harden `qs-osd` CLI Script & `OsdModel.js`

Refactor the `qs-osd` CLI script and verify its contract with `OsdModel.js`:
1. **Fix the `shift 2` Crash Trap:** Under `set -euo pipefail`, validate `[[ $# -ge 2 ]]` before executing `shift 2` on flags (`-i`, `-m`, `-p`, `--max`, `-d`) so missing arguments exit cleanly with an error message instead of crashing bash.
2. **Eliminate `jq` Subshell Overhead:** Replace `jq -cn` with a pure-bash `json_escape` function and `printf` serializer so rapid volume/brightness keybinds execute with zero external process forks.
3. **Add `--max` Flag Support:** Allow passing `--max <int>` from the CLI instead of hardcoding `max="100"`.
4. **Fix Message + Progress Conflict in `OsdModel.js`:** Ensure `OsdModel.js` does not wipe out `hasProgress` when both a `-p <progress>` value and `-m <message>` label are provided simultaneously if progress is valid.

---

## Final Phase: MCP Runtime Verification, Quality Audit & Visual QA (Mandatory Gate)

Do NOT mark the task complete until you execute these verification steps using `quickshell-mcp`:
1. **Static Regex & Quality Audit:**
   - Run the MCP quality audit tools across all modified `.qml` files to verify zero syntax errors and zero type mismatches.
   - Run a regex scan across the entire codebase to confirm zero remaining hardcoded hex codes (`#[0-9a-fA-F]{3,8}`) exist outside `./theme/colors.toml`, and confirm `./theme/Theme.qml` is the only file referencing the `colors.toml` path.
2. **Managed Runtime Reload:**
   - Trigger the MCP reload tool to hot-reload the running Quickshell instance and inspect runtime logs for any QML errors, undefined `Theme.*` property warnings, or binding loops.
3. **Runtime Assertions:**
   - Run MCP runtime assertion primitives (`object_exists`, `property_equals`, `visible`) against the active session to confirm:
     - Every `PanelWindow` root `color` is transparent (`#00000000`).
     - Every full-screen scrim effective alpha is `<= 0.40` (`< 0.57`).
     - Every main card (`surface` / `card`) effective alpha is `>= 0.78` (`> 0.57`).
4. **Visual QA (Region Screenshot):**
   - If an active display session is connected, open the launcher via IPC and use the MCP region-scoped screenshot capture tool around the launcher card bounds to visually confirm clean rounded-corner blur with no full-screen blur bleed and accurate `colors.toml` theming.