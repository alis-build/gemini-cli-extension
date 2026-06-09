# Build It Skill Plan

## Goal

Create a single entry-point skill for developing on the Alis Build Platform, positioned around the phrase **Build It**.

The interaction should feel like the user is asking:

> Alis, please build it.

The skill should route users from an initial build request to the right Alis Build platform workflow by using the Alis Build MCP server as the source of truth for available skills.

## Inspiration

Use the Gemini CLI Conductor extension as a structural reference:

- Keep a clear top-level context file that explains how agents should behave.
- Define a repeatable protocol instead of relying on ad hoc agent judgment.
- Resolve workflow intent through an index-like discovery step before executing.
- Make the agent verify context and present next steps clearly before taking action.

Reference: https://github.com/gemini-cli-extensions/conductor/blob/main/GEMINI.md

## Proposed Skill

### Name

`build-it`

### User-Facing Phrase

`build it`

### Purpose

Guide an agent through discovering, selecting, and running the right Alis Build skill for a user's desired platform task.

The skill should not assume which build workflow is needed. It should first clarify the user's intent, then search Alis Build's skill registry through MCP, then present matching options.

## Core Protocol

### 1. Establish Build Intent

When invoked, the skill should first determine what the user wants to build.

The agent should use available context before asking the user, including:

- The user's latest request.
- Current repository files.
- Existing Alis Build product, neuron, and environment context if available.
- Prior conversation context.
- Current command or skill invocation.

If the target is still ambiguous, ask one concise question:

> What exactly should Alis build?

The answer should be converted into a short search query that describes the intended outcome.

### 2. Search Alis Build Skills

Once the build intent is clear, the skill should instruct the agent to call the Alis Build MCP server's `SearchSkills` tool.

Input should be the user's clarified build intent, not just the phrase `build it`.

Example:

```text
SearchSkills(query: "create an ADK Go agent with a tool and deploy it")
```

The MCP server returns a list of semantically relevant skills. These are currently sourced from:

```text
https://github.com/alis-build/skills
```

The response shape is defined in:

```text
/Users/jankrynauw/alis.build/alis/define/alis/os/mcp/v1/skills.proto
```

Relevant fields:

```proto
message SearchSkillsResponse {
  repeated QueriedSkill queried_skills = 1;
}

message QueriedSkill {
  string id = 1;
  string description = 2;
}
```

The SkillTools service contract says `SearchSkills` must be the first SkillTools method used for discovery. If it returns no results, the agent should call `ListSkills` as the backup so the user can choose from all available skills.

### 3. Present Skill Matches

The agent should present the retrieved skills in a structured table before executing any specific skill.

Recommended table columns:

| # | Skill | What it helps with | When to choose it |
|---|---|---|---|
| 1 | `<skill id>` | `<summary>` | `<selection guidance>` |

The table should be followed by a concise prompt:

> Which skill should I use?

The user may choose by number, skill id, or natural-language preference.

### 4. Load and Execute the Selected Skill

After the user selects a skill, the agent should load the selected skill instructions and follow that workflow.

The selected skill should remain responsible for its own detailed steps, including:

- Required MCP calls.
- Repository setup.
- Product or landing zone discovery.
- Code generation.
- Build, define, or deploy actions.
- Verification.

The `build-it` skill is an entry-point router, not a replacement for specialized Alis Build skills.

### 5. Missing Skill Flow

If `SearchSkills` returns no results, the agent should call `ListSkills` as the backup and present the available skills to the user.

If neither `SearchSkills` nor `ListSkills` contains a relevant skill for the use case, the agent should offer the user an option to request a new Alis Build skill.

Suggested prompt:

> I do not see a matching Alis Build skill for this use case. Do you want me to request one?

If the user agrees, the agent should call the Alis Build MCP server's `RequestSkill` method with:

- `display_name`: short human-readable name for the requested skill.
- `description`: what the skill should help agents do.
- `use_case`: the workflow, task, or user problem the skill should cover.
- `notes`: implementation guidance, links, examples, acceptance criteria, and the reason existing skills did not fit.

The Alis Build MCP server exposes `RequestSkill` for this purpose.

For the current version, `RequestSkill` simply sends an email to the Alis Build team for review. It does not need to create tickets, MCP records, GitHub issues, or any other durable artifact yet.

Relevant proto shape:

```proto
message RequestSkillRequest {
  string display_name = 1;
  string description = 2;
  string use_case = 3;
  string notes = 4;
}

message RequestSkillResponse {
  string notes = 1;
}
```

## Interaction Modes

### Default: Interactive

`build it` should be interactive by default.

Reasons:

- The phrase `build it` is intentionally broad.
- Skill search can return multiple plausible workflows.
- The user should confirm which specialized workflow owns the next step.
- Some selected skills may eventually lead to code changes, builds, defines, or deploys.

Interactive mode should always:

- Clarify build intent when needed.
- Call `SearchSkills`.
- Call `ListSkills` as a backup if `SearchSkills` returns no results.
- Present matching skills in a table.
- Ask the user to select a skill before loading and executing it.

### Optional: Non-Interactive

Support non-interactive mode only as an explicit opt-in.

Possible triggers:

- `build it --yes`
- `build it --auto`
- `Alis, build it using the best matching skill`

Non-interactive mode may auto-select the top search result only when:

- The user has clearly opted in.
- The top result is an obvious match for the clarified intent.
- The selected skill can start with non-destructive discovery or planning.
- The agent will not trigger builds, defines, deploys, commits, or code edits without a later explicit instruction from the selected skill workflow or user.

If confidence is low, or if multiple skills are close matches, fall back to the normal interactive table selection.

## Skill Behavior Requirements

- Always prefer Alis Build MCP skill discovery over hard-coded local assumptions.
- Do not trigger builds, defines, deploys, or code changes from the router skill itself.
- Keep user prompts short and specific.
- Present choices before executing a specialized workflow.
- Treat the MCP skill registry as authoritative.
- If search results are weak, say so plainly and ask whether to request a new skill.
- If search returns no results, call `ListSkills` before offering `RequestSkill`.
- Use interactive selection by default.
- Allow non-interactive auto-selection only when the user explicitly asks for it and the top match is clearly suitable.

## Repo Changes To Consider

### Skill Files

Add a skill file for the new entry point, for example:

```text
skills/build-it/SKILL.md
```

or, if this extension keeps runtime skills elsewhere:

```text
commands/alis-build/build-it.toml
```

The exact location should follow the extension's existing command and skill packaging conventions.

### Command Alias

Add a command or phrase trigger for:

```text
build it
```

Potential aliases:

- `fix it`
- `build-it`
- `alis-build-it`
- `please-build-it`

### GEMINI.md Update

Update `GEMINI.md` to make `build it` the preferred entry point for ambiguous Alis Build development requests.

Suggested behavior:

- If the user says `build it`, invoke the `build-it` skill.
- If the user says `fix it`, invoke the same `build-it` skill as an alias.
- If the user asks to develop something on Alis Build but does not name a specific workflow, route through `build-it`.
- If the user names a precise existing skill or command, use that directly.

## Open Questions

- Where should packaged skills live in this extension: `skills/`, `commands/alis-build/`, or both?

## Implementation Checklist

- [x] Confirm the extension's command and skill packaging convention.
- [x] Inspect the current `SearchSkills` response shape.
- [x] Inspect the current `RequestSkill` request and response shape.
- [x] Create the `build-it` skill instructions.
- [x] Add command aliases for `build it`.
- [x] Update `GEMINI.md` with the routing protocol.
- [ ] Test the flow with a concrete prompt such as: `Alis, please build an ADK Go agent with a tool`.
- [ ] Verify the agent presents matching skills in a table before execution.
- [ ] Verify the missing-skill request flow.
- [ ] Verify optional non-interactive mode falls back to interactive selection when confidence is low.
