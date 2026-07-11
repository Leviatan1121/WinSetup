# Windows installation

To skip a Microsoft account during OOBE, open a console with `Shift + F10`:

```cmd
OOBE\BYPASSNRO
```

or:

```cmd
start ms-cxh:localonly
```

**Update Windows after installing** (before running WinSetup, if possible).

---

# WinSetup — documentation and checklist

## How to run

**Option A — BAT** (double-click or cmd). Downloads `WinSetup.ps1` from the release and launches it. Add `-local` to run from a cloned repo without downloading scripts:

[WinSetup.bat](https://github.com/Leviatan1121/WinSetup/releases/latest/download/WinSetup.bat)

**Option B — PowerShell** (one-liner, same flow and UAC as the `.bat`):

```powershell
irm "https://github.com/Leviatan1121/WinSetup/releases/latest/download/WinSetup.ps1" | iex
```

Requires PowerShell 5+ with internet access. If you deny UAC, limited mode runs (no administrator steps).

**Local development:** run `.\WinSetup.ps1 -Local` (or `WinSetup.bat -local`) from the repo so step 3 copies local scripts instead of downloading the GitHub release.

When WinSetup.ps1 finishes, press **Enter** once to close the main window. Sign out or **reboot** so the performance preset appears correctly in `sysdm.cpl`. After the **first real reboot**, these open automatically:

1. **Settings → Mouse pointer** (pick a color).
2. **InstallApps** (graphical software selector).

---

## Execution order (WinSetup.ps1)

**Single UAC at start:** if you approve it, the bootstrap window closes and elevated `WinSetup.ps1` is the only main window. Each child script opens its **own window** and closes when it finishes (no per-script pause). One **Press Enter to continue** at the very end of the orchestrator.

**Visible steps (admin):** 11. **Limited mode (UAC denied):** 7 visible steps; admin-only steps are skipped silently (banner lists what was skipped).

| # | Phase | Admin | Script / action |
|---|------|-------|-----------------|
| 1 | Windows Update Pauser | No | Downloads and runs [WindowsUpdatePauser](https://github.com/Leviatan1121/WindowsUpdatePauser) |
| 2 | User PATH helpers | No | Creates `%USERPROFILE%\bin`, adds to PATH, `AllowFile.bat` / `AllowProcess.bat` |
| 3 | Download release assets | No | Scripts needed for this run (limited: 8 files; admin: +5 more; cached files skipped) |
| 4 | Configure | No | `Configure.ps1` |
| 5 | Privacy | No | `Privacy.ps1` |
| 6 | Performance (user) | No | `Performance.ps1` |
| 7 | Winget upgrade | **Yes** | `WinSetup-WingetUpgrade.ps1` |
| 8 | Debloat | **Yes** | `Debloat.ps1 -WinSetupElevated` |
| 9 | Performance (system) | **Yes** | `Performance.ps1 -SystemOnly` |
| 10 | Shell refresh | No | Restarts Explorer + Start (orchestrator inline step) |
| 11 | Remote support | **Yes** | `RemoteSupport.ps1` (optional, interactive) |

**Silent (no step header):** post-reboot hooks — `Install-MousePointerPrompt.ps1` and `Install-AppsPrompt.ps1` run hidden (`-Register`) after step 9 in admin mode, or after step 6 in limited mode.

### Limited mode (UAC denied)

If you deny UAC, the main window continues in **Limited** mode and runs visible steps **1–6** and **10** (Shell refresh). Steps **7–9** and **11** are skipped; post-reboot hooks still register silently. Re-run WinSetup (`.bat` or the PowerShell one-liner) and approve UAC to complete admin steps — step 3 then downloads only the missing admin scripts (already cached files are skipped).

**Errors:** non-zero step results and `Write-Warning` output from child scripts are appended to `%TEMP%\WinSetup\WinSetup-errors.log` (cleared at each run). If anything was logged, the final banner is **red** and prints the log path and contents; otherwise the yellow “Baseline complete” banner is shown.

The `%TEMP%\WinSetup` folder (setup downloads) is deleted on the **first reboot**, when `Open-MousePointerSettings.ps1` runs — so cleanup is not lost if Remote Support prompts for a reboot before WinSetup finishes.

---

## 1. Windows Update Pauser

Pauses Windows updates during setup (external tool).

**Verify:** updates do not install on their own while you configure the PC.

---

## 2. Environment helpers (`%USERPROFILE%\bin`)

| Item | Purpose |
|------|---------|
| `%USERPROFILE%\bin` | User PATH folder |
| `AllowFile.bat` | Runs a `.ps1` with execution policy bypass |
| `AllowProcess.bat` | Opens interactive PowerShell with bypass |

---

## 3. Configure (`Configure.ps1`) — HKCU, no admin

### Accessibility → Mouse pointer and movement
- Pointer size: **3** (large).
- `CursorBaseSize` = 64.
- **No mouse acceleration** (`MouseSpeed` and thresholds set to 0).
- **Pointer color** is not set here; you choose it after reboot (post-reboot hook).

### Personalization → Themes
- Applies **dark** theme (`dark.theme`).

### System → Developer options
- **End task** on the taskbar: enabled.

### Multitasking → Alt + Tab
- **Open windows only** (no browser tabs as separate entries).

### File Explorer → View
- **File name extensions visible**.
- **Hidden files visible**.
- Open to **This PC** (not Quick access).
- **Unpin Home and Gallery** from the navigation pane.
- **Removes profile folders** if present: `Contacts`, `Favorites`, `Links`, `Saved Games`, `Searches`.

### Taskbar
- **No search box** on the taskbar.
- Bing / Cortana in search: disabled.
- Location in search: disabled.
- On **multiple monitors**: icons only on the monitor where the window is.
- **Automatically hide the taskbar** (all monitors).

### Start
- All apps view.
- No recent / frequent list.
- Folders next to the power button: **Settings**, **File Explorer**, **Personal folder**.
- No Iris / program / recent document recommendations.
- Content Delivery Manager: disables suggestions, preinstalled apps, Spotlight on lock screen, etc.
- Start search: **local only** (no MSA/AAD cloud).

### System → Power
- Turn off display: **3 minutes** (plugged in and on battery).
- Sleep: **never** (plugged in and on battery).

**Verify in Settings:** Appearance, Explorer, Taskbar, Start, Power, Pointer (size; color after reboot).

---

## 4. Privacy (`Privacy.ps1`) — HKCU, no admin

### Privacy → General
- Personalized offers: **Off**.
- Personalized experiences with diagnostic data: **Off**.
- Do not share language list with websites.
- Account notifications in Settings: **Off**.
- Advertising ID: **Off**.

### Privacy → Location (user)
- Location consent: **Deny** (packaged and desktop apps).
- No global location prompts.
- *System-level location is turned off in Debloat (admin).*

### System → Clipboard
- Local history: **On**.
- Cloud sync: **Off**.

### Diagnostics and activity (user)
- Do not publish user activities.
- No experience surveys (SIUF).
- No implicit ink/text collection.
- No contact harvesting for input personalization.

**Verify in Settings:** Privacy & security → General, Location, Clipboard, Diagnostics.

---

## 5. Performance (`Performance.ps1`) — HKCU + HKLM

### User part (no admin) — `sysdm.cpl` + Accessibility

**Custom** preset equivalent to:
- **Best performance** base.
- **Thumbnails** in Explorer: On.
- **ClearType** (font smoothing): On.
- **Transparency effects**: Off.
- **Animation effects**: Off.
- No taskbar animations, list shadows, Aero Peek, etc.

### Gaming (user)
- **Game DVR / background capture**: Off.
- **Automatic game mode**: Off.
- **Game Bar (Win+G)**: remains available.

### System part (admin, step 9 of WinSetup.ps1)
- Foreground priority: `Win32PrioritySeparation` = 38 (favors programs).
- MMCSS `SystemResponsiveness` = 0, `NetworkThrottlingIndex` = maximum.
- Game DVR policy (HKLM): disabled.

**Verify:** `sysdm.cpl` → Advanced → Performance → **Custom** (after **sign out**). Accessibility → Visual effects. Settings → Gaming → background capture Off.

---

## 6. Debloat (`Debloat.ps1`) — admin

### Power
- **Fast startup (hiberboot)**: disabled.

### Location (system)
- Location services **Off** via `SystemSettingsAdminFlows`, HKLM policies, and consent store.
- Clears Capability Access Manager SQLite caches and restarts `lfsvc` / `camsvc`.

### Taskbar → Widgets
- Widgets hidden (`TaskbarDa` = 0).
- Policy: no News and Interests.
- Uninstalls **Web Experience Pack** and **Widgets Platform Runtime**.

### Copilot, Recall, and integrated AI
- Copilot button on taskbar: hidden; Copilot/Recall pins disabled.
- HKLM/HKCU policies: Copilot off, remove Copilot app, no AI data analysis, Click to Do, Settings Agent, Agent Connectors/Workspaces.
- Consent: no app access to generative AI or system models.
- Shell/runtime: `IsCopilotAvailable`, `AllowCopilotRuntime`, Taskbar Companion off.
- `IntegratedServicesRegionPolicySet.json` and `VisualAssistActions.json`: generative AI disabled.
- Recall: policies off, optional feature disabled via DISM, no snapshot storage.
- Appx/CBS: AIX, CoreAI, Copilot.Provider, aimgr, WritingAssistant, WindowsWorkload.*, AIFabric.CBS*.
- Tasks `\Microsoft\Windows\WindowsAI\*` and services `MicrosoftCopilotElevationService`, `WSAIFabricSvc`, `AarSvc`.
- Store policy to block Copilot/AI package reinstallation.
- Uninstalls Copilot packages (winget/Appx) and `%USERPROFILE%\.copilot` folder.
- **Anti-AI** (single script [`WinSetup-AI-UpdateCleanup.ps1`](WinSetup-AI-UpdateCleanup.ps1)): Copilot, Recall, policies, Appx/CBS, Notepad/Paint/Photos/Voice Access/Gaming Copilot, file cleanup, anti-reinstall `.cab`, and post-update task. `Debloat.ps1` invokes it once.

### OneDrive
- Uninstalls OneDrive (winget + official setup).
- Policy: block sync / reinstallation.
- Removes `%USERPROFILE%\OneDrive` folder if present.

### Preinstalled apps removed

Feedback Hub, Weather, Phone Link, Family Safety, Get Started, Journal, Microsoft 365 Copilot (Office Hub), Clipchamp, Teams (all variants), To Do, Whiteboard, Sticky Notes, News, Bing Search, Dev Home, Power Automate Desktop, Outlook, Mobile Plans, Solitaire, **WhatsApp** (all paths), Bing app, and other associated winget IDs.

### Apps that are **NOT** removed (intentional)
- **Xbox** ecosystem: Game Bar (Win+G), Xbox app, Identity Provider, Gaming Services, etc.

### Taskbar
- **Unpins all pinned apps** (all profiles, including `Default`).

### Start menu
- **Empty `start2.bin`** for all users (clean layout; HKCU preferences in Configure).

### Search (system)
- No web/Bing results in search (HKLM policies).

### Consumer experience / Spotlight
- No Store app suggestions, Spotlight on lock/action/settings, third-party suggestions.

### Microsoft Store Python aliases
- Removes `python.exe` and `python3.exe` from `WindowsApps` (reparse points) in **all profiles**.
- Prevents `python` from opening the Store instead of mise/Python.

### Telemetry (system)
- `AllowTelemetry` / `MaxTelemetryAllowed` = 0.
- No OneSettings downloads, no feedback notifications.
- Activity feed / activity upload: off.
- **DiagTrack** and **dmwappushservice** services: disabled and stopped.

### Windows Update → Delivery Optimization
- HTTP only; no P2P cache or upload to other PCs.

During Debloat, Explorer is stopped briefly for taskbar/start layout changes. A **single shell refresh** runs later in the orchestrator (step 10), not at the end of `Debloat.ps1`.

**Verify:** debloated apps do not appear in Start; no widgets; no Copilot; no OneDrive; search without web; `python` does not open Store; minimal telemetry in Policies.

---

## 7. Remote support (`RemoteSupport.ps1`) — admin, interactive

Prompts **Enter = Yes** to uninstall:

| Tool | Notes |
|------|-------|
| **Quick Assist** | Appx + Windows capability |
| **Remote Desktop Connection** (`mstsc`) | May prompt for **reboot** when finished |

Any other key skips.

---

## 8. After WinSetup — before reboot

**Success:** yellow banner — baseline complete; reboot for mouse pointer + InstallApps.

**Errors:** red banner — `%TEMP%\WinSetup\WinSetup-errors.log` path and full log printed in the console. Execution continues step-by-step; reboot post-reboot prompts may still run.

Persistent files until post-reboot:

| Path | Purpose |
|------|---------|
| `%TEMP%\WinSetup\` | Setup downloads + error log (deleted on first reboot) |
| `%LOCALAPPDATA%\WinSetup\` | Post-reboot scripts and markers |
| `HKCU\...\Run\WinSetup-MousePointerSettings` | Opens pointer settings after reboot |
| `HKCU\...\Run\WinSetup-InstallApps` | Launches InstallApps after reboot |
| `%ProgramData%\WinSetup\` | Anti-AI cleanup script + scheduled task (if Debloat ran) |

---

## 9. Post-reboot — Mouse pointer

1. Compares `LastBootUpTime` with the `.open-mouse-after-reboot` marker (real reboot, not just Explorer restart).
2. Deletes `%TEMP%\WinSetup` (setup downloads; deferred in case Remote Support reboots before WinSetup finishes).
3. Opens `ms-settings:easeofaccess-mousepointer`.
4. Removes hook, marker, and copied script.

**Verify:** choose the **pointer color** you want.

---

## 10. Post-reboot — InstallApps (`InstallApps.ps1`)

### Winget (self-contained)
- Checks App Installer before the GUI; on failure, elevates once to repair (pinning bypass + upgrade), same pattern as WinSetup step 7 but **implemented inside `InstallApps.ps1`** (no dependency on `WinSetup-WingetHelpers.ps1`).

### Interface
- Dark WPF window with categories, name search, and selection counter.
- Requires **winget** (see above).

### Installation types

| Type | Behavior |
|------|----------|
| **winget** | `winget install -e --silent` (or `-s msstore` when applicable) |
| **Direct download** | URL + silent arguments (Cursor, Pretzel, C++ Build Tools, etc.) |
| **mise** | `jdx.mise` via winget; languages with `mise use --global` |
| **Node.js (mise)** | `node@lts` |
| **Python (mise)** | `python@latest` |
| **Go (mise)** | `go@latest` |

After installing mise or a mise language:
- Adds mise binary and `%LOCALAPPDATA%\mise\shims` to user PATH.
- Runs `mise reshim`.

If you select a language without mise installed, `jdx.mise` is installed automatically.

### Categories (not an exhaustive package list)
Communication, Browsers, Gaming, Streaming, Design, AI, Utilities, Graphics, Development.

### When finished
- Summary: `Installed X of Y app(s)`.
- **Press Enter to close** the console.

After running, `Open-InstallApps.ps1` deletes `InstallApps.ps1`, the marker, the Run hook, itself, and `%TEMP%\WinSetup-Install\` (direct-download cache). `InstallApps.ps1` does not remove itself.

**Verify:** chosen apps installed; `node -v`, `python --version`, `go version` if you selected mise (Python should not open the Store thanks to Debloat).

---

## Quick checklist for a new PC

Use this in order:

- [ ] Windows updated before or after OOBE as you prefer
- [ ] WinSetup completed without critical errors (`.bat` or `irm | iex`)
- [ ] Dark theme, Explorer (extensions, hidden files, This PC)
- [ ] Taskbar hidden, no search, no widgets
- [ ] Start without recommendations; empty layout
- [ ] Power: display 3 min, no sleep
- [ ] Privacy: offers off, location off, clipboard without cloud
- [ ] `sysdm.cpl`: custom performance preset + thumbnails + ClearType (after sign out)
- [ ] No Copilot, no OneDrive, no debloated apps
- [ ] `python` does not open Microsoft Store
- [ ] Reboot → pointer color
- [ ] Reboot → InstallApps → desired software
- [ ] mise / node / python / go if you selected them

---

## Project files

| File | Role |
|------|------|
| `WinSetup.bat` | Stub: downloads `WinSetup.ps1` from release and runs it; `-local` runs from repo |
| `WinSetup.ps1` | Main orchestrator (1 UAC, single main window); also via PowerShell one-liner (`irm` / `iex`) |
| `WinSetup-WingetHelpers.ps1` | Shared winget helpers for Setup / Debloat / AI cleanup |
| `WinSetup-WingetUpgrade.ps1` | Upgrades App Installer (admin step 7) |
| `WinSetup-AI-UpdateCleanup.ps1` | Anti-AI removal + post-update task (via Debloat) |
| `Configure.ps1` | Appearance and shell (HKCU) |
| `Privacy.ps1` | User privacy (HKCU) |
| `Performance.ps1` | Visual performance + gaming (HKCU / HKLM) |
| `Debloat.ps1` | System removals and policies |
| `RemoteSupport.ps1` | Optional Quick Assist / RDP |
| `Install-MousePointerPrompt.ps1` | Registers pointer hook (silent) |
| `Open-MousePointerSettings.ps1` | Post-reboot pointer runner; cleans `%TEMP%\WinSetup` (fault-tolerant) |
| `Install-AppsPrompt.ps1` | Registers InstallApps hook (silent) |
| `Open-InstallApps.ps1` | Post-reboot InstallApps runner; removes `InstallApps.ps1` + cache after exit |
| `InstallApps.ps1` | Software selector and installer (self-contained winget logic) |

**Adding a new script:** add it to the step manifest in `WinSetup.ps1` (and to `Get-WinSetupScriptDependencies` / `Get-WinSetupHookPayloads` if it is dot-sourced or copied by a hook). Step 3 derives its download list from that manifest — the GitHub workflow still publishes all `*.ps1` in the repo.
