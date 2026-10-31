# NightOwl

Menu bar indicator and switch for keeping a Mac awake.

- Yellow owl: NightOwl's **Keep Mac Awake** switch is on.
- White owl (black on a light menu bar): the switch is off, but another source is keeping the Mac from idle sleep.
- Gray owl: the Mac can sleep normally.

Sources that count as keeping the Mac awake:

- System Settings sleep set to "never" for the current power source (Battery > Options > "Prevent automatic sleeping on power adapter when the display is off")
- Any process holding a sleep-prevention power assertion: `caffeinate`, Claude Code (which runs `caffeinate` while working), the Claude desktop app "Keep computer awake" switch, video calls, audio playback, etc.

The menu lists what is currently keeping the Mac awake. Each process has a submenu with **Show in Activity Monitor**; processes you own also get **Quit** and **Force Quit** (after confirmation). For `caffeinate`, only `caffeinate` itself is ended, not the terminal or Claude Code that started it. Assertions a daemon holds on behalf of an app (e.g. `coreaudiod` for audio playback) are attributed to, and quit, that app.

Ignored: powerd's built-in "prevent sleep while display is on" assertion, runningboardd background-task completions, and assertions younger than 3 seconds.

## Build

```sh
./build.sh            # builds build/NightOwl.app
./build.sh install    # also copies it to /Applications
```

Requires the Xcode command line tools. macOS 13+.

Show in Activity Monitor filters Activity Monitor's list to the process when NightOwl has Accessibility permission (System Settings > Privacy & Security > Accessibility); otherwise it just opens Activity Monitor. NightOwl is ad-hoc signed, so the permission must be re-granted after each rebuild.

## Limits

- Closing the lid still sleeps the Mac unless it is in clamshell mode (power + external display).
- Processes owned by root or another user (e.g. `sudo caffeinate`) and the System Settings sleep timer cannot be ended from NightOwl; turn them off where they were turned on.
- Some sources come back: Claude Code starts a new `caffeinate` on its next working turn.
- Apps may refuse a normal Quit (e.g. unsaved documents); use Force Quit.
