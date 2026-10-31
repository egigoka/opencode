# Fork patches for OpenCode dev

The fork tracks upstream `dev`. This port targets upstream commit
`6c24ec9532` (cli `2.2.5`). The fork's branch remains `dev`.

| Patch                            | Decision | Reason                                                                                                                                            |
| -------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 001: TUI launch update check     | Ported   | Dev still runs the updater immediately. Delay its first automatic check by ten minutes. Keep periodic checks and manual updates.                   |
| 002: Desktop launch update check | Removed  | Dev removed the desktop updater that this patch modified.                                                                                          |
| 003: TUI padding                 | Ported   | Dev still uses the wider spacing. Reduce horizontal padding and prompt chrome, and update width calculations and snapshots.                        |
| 004: MCP format warnings         | Ported   | The dev MCP SDK still bundles Ajv. Its default validator still prints warnings for `uint32`. Keep the tolerant validator with the new SDK imports. |

The padding patch retains vertical padding on user messages. Removing that padding
breaks one-line scrolling and the jump-to-latest indicator in dev's history tests.
Inline tool rendering moved into `packages/tui/src/routes/session/message-parts.tsx`;
the patch includes that file.

The MCP validator keeps the SDK's schema-dialect dispatch. Tests cover draft-07,
2019-09, and 2020-12, including required fields, integer types, email formats, and
preservation of the server's original schema.

## Apply and verify

Use the Bun version in the upstream root `packageManager` field, currently `1.4.4`.

Apply the patches in filename order to a clean upstream checkout:

```sh
for patch in /path/to/fork-patches/*.patch; do
  git apply --check "$patch"
  git apply "$patch"
done
bun install --frozen-lockfile
```

Run `bun typecheck` from each changed package: `packages/cli`, `packages/core`, and
`packages/tui`. Run tests from those package directories, never the repository root.

The daily-release workflow checks out upstream `dev`, applies these patches, and
builds `packages/cli`. It packages the resulting `cli-*` directories as
`opencode-*.zip` or `opencode-*.tar.gz`, preserving compatibility with `install.sh`.
The sync workflow merges upstream `dev` into the fork's default branch.

Dialogs moved to the shared `DialogLayout` component, which defaults to a
3-cell side inset with an optional `inset` prop. The padding patch passes
`inset={1}` to the fork-touched dialogs and replaces the list-inset constants
with `1` in the same spots; rows keep the experiment-gated new-designs values.
`DialogBleed` gained an optional `inset` prop so the band still spans the
narrowed padding. The select content-width budget is now a flat `- 7`.

Upstream retired `text.faint` in favor of `text.muted`; the padding patch keeps
upstream's colors and only changes insets. The retry-countdown test in
`app-lifecycle.test.tsx` collapses whitespace before matching, because the
narrower session padding wraps the message differently at 44 columns.

Known failures with these patches applied: `dialog-shell-output.test.tsx` times
out on upstream too, and the diff-viewer "selectable base" test fails because
the fork's non-new-designs rows put titles of the current row one cell right of
unmarked rows.
