# Source playbooks

The `but-why` skill spawns one investigator per available evidence category, each reading a single source-specific playbook below. The playbooks are concrete examples for common MCPs. Adapt them for a different MCP in the same category.

| Category                     | Playbook                                               | Example MCP documents                                     |
| ---------------------------- | ------------------------------------------------------ | --------------------------------------------------------- |
| Source control history       | [`code-archaeology.md`](./sources/code-archaeology.md) | git, `gh`                                                 |
| Issue / ticket tracker       | [`jira.md`](./sources/jira.md)                         | Jira (adapt for ZenDesk, GitHub Issues, Linear)           |
| Long-form documents          | [`confluence.md`](./sources/confluence.md)             | Confluence (adapt for Google Docs, Notion, Coda)          |
| Real-time team chat          | [`slack.md`](./sources/slack.md)                       | Slack (adapt for Discord, Microsoft Teams, Mattermost)    |
| Infrastructure observability |                                                        | Datadog (adapt for New Relic, Honeycomb, Grafana, Splunk) |
| Error / exception tracking   |                                                        | Sentry (adapt for Rollbar, Bugsnag, Airbrake)             |
| Product analytics warehouse  |                                                        | Databricks SQL (adapt for Snowflake, BigQuery)            |

Cross-cutting:

- [`incident-postmortem.md`](./sources/incident-postmortem.md). Add this if the target code looks defensive (null checks, retry, timeout, rate limit, feature flag, egress guard, OOM handler).
