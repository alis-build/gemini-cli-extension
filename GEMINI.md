# Alis Build Extension Context

You are working with Alis Build through the `alis-build` MCP server and the optional `alis-build-agent` remote sub-agent.

When the user asks about Alis Build, prefer Alis Build MCP tools before guessing. Use the tools to inspect the active workspace, product, environment, build status, logs, deploy status, ideas, and related service context.

Prefer MCP tools for Alis Build workflows. Use `@alis-build-agent` only when the workflow benefits from the hosted Alis Build agent runtime.

When the user says `build it`, route through the Alis Build skill discovery flow:

1. Use existing context to determine what the user wants built. If the goal is still ambiguous, ask one concise question: "What exactly should Alis build?"
2. Call the Alis Build MCP `SearchSkills` tool with the clarified build goal as the query.
3. Present the returned skills in a concise table with number, skill id, description, and when to choose it.
4. Ask the user which skill to use before loading or executing a specialized workflow.
5. If `SearchSkills` returns no results, call `ListSkills` as the backup and present those options.
6. If no listed skill fits, ask whether the user wants to request a new skill. If they agree, call `RequestSkill`; the current implementation emails the Alis Build team for review.

Treat `fix it` as an alias for `build it`.

Do not trigger rebuilds or deploys unless the user asks.

Keep responses concise and action-oriented.
