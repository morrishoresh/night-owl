# NightOwl

Menu bar indicator and switch for keeping a Mac awake (e.g. while AI agents run).

- Yellow owl: NightOwl's **Keep Mac Awake** switch is on.
- White owl (black on a light menu bar): the switch is off, but another source is keeping the Mac from idle sleep.
- Gray owl: the Mac can sleep normally.

Sources that count as keeping the Mac awake:

- System Settings sleep set to "never" for the current power source (Battery > Options > "Prevent automatic sleeping on power adapter when the display is off")
- Any process holding a sleep-prevention power assertion: `caffeinate`, Claude Code (which runs `caffeinate` while working), the Claude desktop app "Keep computer awake" switch, video calls, audio playback, etc.

The menu lists what is currently keeping the Mac awake.

Ignored: powerd's built-in "prevent sleep while display is on" assertion, runningboardd background-task completions, and assertions younger than 3 seconds.

## Build

```sh
./build.sh            # builds build/NightOwl.app
./build.sh install    # also copies it to /Applications
```

Requires the Xcode command line tools. macOS 13+.

## Limits

- Closing the lid still sleeps the Mac unless it is in clamshell mode (power + external display).
- NightOwl can only release its own assertion. Other sources are shown but must be turned off where they were turned on.
