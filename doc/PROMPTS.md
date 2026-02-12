# Historical Prompts

## BUG: Avoid URL-incompatible characters in filenames

Using [@PLAN.md](file:///home/steven/work/deobald/kaya-firefox/doc/plan/PLAN.md), draft a plan to prevent the sync daemon from syncing files to/from `~/.kaya/anga` which contain URL-incompatible characters, like spaces. The daemon should ensure that files which are downloaded are URL-encoded. If they aren't, a warning should be logged. If `~/.kaya/anga` contains a filename that isn't URL-encoded (for example, if it contains a space), the daemon shouldn't uploaded it and instead log a warning.

To assist with debugging (and for more useful log output), include the filenames being sync'd, one per line, prior to the 'Sync complete:' log line.
