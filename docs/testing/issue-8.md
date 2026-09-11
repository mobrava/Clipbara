# Issue #8: panel-local tab shortcuts

## Contract

- Command+1 selects History. Command+2 through Command+9 select the first eight pinboards in displayed tab order.
- The number row and numeric keypad use the same mapping. Caps Lock is ignored; Shift/Option/Control combinations are not tab shortcuts.
- Missing positions do nothing. Command+0 is not assigned.
- Shortcuts work only in the open panel or its Quick Look window, including while the search field has focus.
- A create/rename/delete dialog must retain its input. Settings and other applications must not trigger tab switching.
- Switching closes an old preview and invalidates the old keyboard target before the new tab renders. The search query is preserved.
- A selected tab outside the visible strip scrolls into view. Tooltips and Settings > Shortcuts explain the fixed mapping.
- No global hotkeys, Accessibility permission, or synthetic paste events are added.

## Automated checks

```sh
bash scripts/test-tab-shortcuts.sh
```

The script generates the project, runs the 11 unhosted XCTest methods, builds Debug, and relaunches Clipbara. Unit tests do not launch the app or access its data. Relaunching the Debug app uses its normal data store. Logs and an xcresult bundle are written to the printed output directory. A nonzero step stops the script.

The unit tests exercise the actual mapping source, not a duplicate implementation. They cover number-row/keypad keys, modifiers, missing tabs, boundaries, changed tab order, and tooltip numbering. They do not prove event delivery or SwiftUI/AppKit behavior.

## macOS UI verification (not covered by unit tests)

Use a separate empty TextEdit document as the foreground application. Keep the production nonactivating NSPanel style. Use existing pinboards when possible; never clear the user's history or remove their boards for a test.

1. Open the panel, then use Command+1, Command+2, and Command+3. Check the active tab and card contents, not just the tab highlight. Switch back with Command+1.
2. Repeat a switch into an empty board, the eighth board if available, and a nonexistent numbered position. The empty board must have no stale selectable card; a missing position does nothing. Command+0 and extra-modifier chords must not switch tabs.
3. Type into search and immediately press Command+2, before the 150ms debounce completes. Wait, then check that the pinboard's contents remain the keyboard targets. Switch to History and confirm the search query is preserved.
4. Open Quick Look with Space, then press Command+2. The old preview must close. Space/Return must never act on the previous tab's clip. Repeat tab switching rapidly, including an immediate Return.
5. While a create/rename/delete confirmation is open, press Command+1/2. The dialog must remain active without navigating the panel behind it. Cancel it without modifying user data.
6. In Settings and with the panel closed, use Command+1/2. Clipbara must not open or change tabs. Reopen the panel to check.
7. If there are enough tabs to overflow the strip, switch by keyboard and confirm that the selected tab becomes visible. Check History and pinboard tooltips and the Settings > Shortcuts explanation.
8. Regression: confirm Left/Right, Space, Escape, and mouse tab clicks still work. Search and dialog text input must retain normal behavior.
9. Paste regression, with two distinct uniquely identifiable test strings: confirm independently that clicking a card changes the system clipboard to that card, closes the panel, and a subsequent manual Command+V inserts it into the empty focused TextEdit document. Also check Return immediately after a tab switch. Do not test with a card already equal to the current clipboard.

Record pass/fail or unavailable for each case. If testing creates clipboard records, remove only those exact unique test records using SwiftData and call modelContext.save(); preserve all pre-existing user data. Never count an unavailable case as passed.

## Verification status

- 2026-09-11: `scripts/test-tab-shortcuts.sh` passed end to end. 11 unit tests, 0 failures, Debug build succeeded, Debug app relaunched.
- 2026-09-11: tab switching, switching while searching, switching with Quick Look open, and switching with a pinboard dialog open were checked by hand and behaved as specified.
- Not yet covered: the paste regression case in step 9 and multi-tab scroll-into-view with an overflowing tab strip.
