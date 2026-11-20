# EveryMango2

An iPhone productivity app that looks and feels like an audio plugin. The interface is a native SwiftUI
redraw of the Surge XT design language (panels, sliders, knobs, multi-switches, LCD wells, meters), and
the ideas come from EveryMango: capture first, sort later, and be gentle about it.

## Open it

1. Open `EveryMango2.xcodeproj` in Xcode 16 or later.
2. Pick an iPhone simulator or your phone and press Run.

Signing is set to team `H7CJSVP2JC` with bundle identifier `com.eldrin.EveryMango2`. Minimum iOS is 17.

## What is where

| Tab | Synth idea | What it does |
| --- | --- | --- |
| MAIN | front panel | Day scope, three focus slots, energy knob and "pick one for me", today's tasks, filter, board mixer, wins |
| DUMP | modulation routing | Brain-dump inbox with one-tap routing (Today, a board, Someday, a note), plus notes |
| SEQ | step sequencer | Time blocking. Hold a block to drag it, pull its bottom edge to stretch it, tap empty time to add one |
| BOARDS | mixer channels | One board per topic or thread, with tasks by status and notes |
| CAL | | Month, week and agenda views of device calendars, blocks and due tasks |

Always on screen: the scene switch (A, B, A+B), the day browser, the load meter, and the REC capture bar.

## Layout

- `EveryMango2/Core`: models, the store, scheduling, recurrence, the focus timer. No UI imports.
- `EveryMango2/DesignSystem`: the skin (Classic and Dark) and the controls.
- `EveryMango2/Features`: one file per screen.
- `EveryMango2/Services`: EventKit calendar access, notifications.
- `CoreTests` and `Package.swift`: unit tests for the core. Run them with `swift test` from this folder.

Data is saved as JSON in the app's Application Support folder. Lato is bundled under the SIL Open Font License.
