# Issue Labels

For issues, we speak in terms of canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Farseer Label              | Label in Tracker     | Meaning                                                                        |
| -------------------------- | -------------------- | ------------------------------------------------------------------------------ |
| `needs-triage`             | `needs-triage`       | Unreviewed; nobody has decided what this is or who takes it                    |
| `needs-info`               | `needs-info`         | Further information is requested, or waiting on reporter for more information  |
| `ready-for-agent`          | `ready-for-agent`    | Scoped for autonomous execution; clear acceptance criteria, no open questions  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation                                                  |
| `wontfix`                  | `wontfix`            | This will not be worked on                                                     |
| `bug`                      | `bug`                | Something is broken                                                            |
| `enhancement`              | `enhancement`        | New feature or improvement                                                     |

When a skill mentions a role (e.g. "apply the AFK-ready issue label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

`needs-triage` is the default for anything arriving un-reviewed.
`ready-for-agent` is an assertion that the issue is executable as written. Apply the label only when that is true.
