# Historical Prompts

## BUG: Avoid URL-incompatible characters in filenames

Using [@PLAN.md](file:///home/steven/work/deobald/kaya-firefox/doc/plan/PLAN.md), draft a plan to prevent the sync daemon from syncing files to/from `~/.kaya/anga` which contain URL-incompatible characters, like spaces. The daemon should ensure that files which are downloaded are URL-encoded. If they aren't, a warning should be logged. If `~/.kaya/anga` contains a filename that isn't URL-encoded (for example, if it contains a space), the daemon shouldn't uploaded it and instead log a warning.

To assist with debugging (and for more useful log output), include the filenames being sync'd, one per line, prior to the 'Sync complete:' log line.

## Make it obvious when the password is set

Currently, even if the password is set, the password field is always empty unless the user has just typed a password into it. This is confusing, since it always looks as though the password hasn't been set, even if it has. Using [@PLAN.md](file:///home/steven/work/deobald/kaya-firefox/doc/plan/PLAN.md), draft a plan to render bullets or asterisks in the password field if the password is set.

The goal of [@2026-02-13-password-set-indicator.md](file:///home/steven/work/deobald/kaya-firefox/doc/plan/2026-02-13-password-set-indicator.md) is not to adjust the content of the placeholder. Rather, the password field should display bullets (`"••••••••"`) instead of the actual password. If the user has a password set and visits the Preferences tab, it should be apparent that the password is set and clicking the "Test Connection" button should succeed (assuming the saved email and password successfully connect to the API). If the user wants to click the "Test Connection" button, they should not need to re-enter their password every time to do so. Adjust the plan according to these instructions and execute if you don't have any questions.

## BUG: Downloaded anga/meta/words filenames should not contain spaces

When the Rust daemon downloads files with URL-encoded characters, it should retain that URL-encoding for the filenames stored on disk locally in `~/.kaya/anga`, `~/.kaya/meta`, and `~/.kaya/words`. For example, if Kaya Server lists an anga file named `2025-01-01T120000-India%20Income%20Tax.pdf`, this should not become `~/.kaya/anga/2025-01-01T120000-India Income Tax.pdf`.

Write a failing unit test to assert this behaviour is currently saving files with spaces. Then make the test pass. Follow the instructions in [@PLAN.md](file:///home/steven/work/deobald/kaya-firefox/doc/plan/PLAN.md).
