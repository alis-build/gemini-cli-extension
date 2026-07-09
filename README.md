# Alis Build Gemini CLI Extension

<p align="center">
  <img src="assets/connectivity.svg" alt="Gemini CLI connected to Alis Build" width="760">
</p>

<p align="center">
  <strong>Connect Gemini CLI to Alis Build.</strong>
</p>

Use this extension to let Gemini CLI inspect Alis Build organisations, products, neurons, builds, deploys, and related workspace context.

## What You Get

- A preconfigured Gemini CLI MCP server for `https://mcp.alis.build`
- A remote Alis Build agent at `https://agent.alis.build`
- OAuth/OIDC sign-in through `https://identity.alisx.com`
- The standing Alis Build Define-Build-Deploy primer (mental model + skill-routing contract + CLI-first execution) always loaded from `GEMINI.md`
- A `BeforeTool` hook that passes your session context to Alis `LoadSkill` calls for context-aware skills

## Before You Start

You need:

- Gemini CLI installed
- An Alis Build account with access to the organisations and products you want to use
- Network access to `https://mcp.alis.build`, `https://agent.alis.build`, and `https://identity.alisx.com`

## Install

Install the extension:

```sh
gemini extensions install https://github.com/alis-build/gemini-cli-extension
```

Restart Gemini CLI after installing.

## Sign In

Inside Gemini CLI, run:

```text
/mcp auth alis-build
```

You can also inspect the configured integration:

```text
/extensions list
/mcp
/agents list
```

You should see:

- extension `alis-build`
- MCP server `alis-build` configured for `https://mcp.alis.build`
- agent `alis-build-agent`

The sign-in flow opens `https://identity.alisx.com` in your browser.

## Use It

After sign-in, ask Gemini CLI to use Alis Build:

```text
build it
```

```text
fix it
```

```text
Use Alis Build to list the organisations I can access.
```

```text
Show recent builds for product os in organisation alis.
```

```text
@alis-build-agent Review my active Alis Build workspace and suggest the next build or deploy action.
```

## Commands

This extension includes Alis Build workflow shortcuts:

```text
/alis-build:build-it
/alis-build:fix-it
/alis-build:getting-started
```

Type `build it` to discover the right Alis Build skill for the thing you want to build. Type `fix it` to use the same discovery flow when the goal is framed as a fix. `/alis-build:build-it` and `/alis-build:fix-it` are slash-command shortcuts for the same router. `/alis-build:getting-started` uses the Alis Build `getting-started` skill for the platform workflow and simpleapi quickstart. After updating a linked extension, run `/commands reload` or restart Gemini CLI.

## Hooks

This extension bundles hooks (in `hooks/hooks.json`) that run automatically — no setup required:

- **Skill session context (`BeforeTool`)** — before an Alis `LoadSkill` call runs, your Gemini `session_id` is merged into the request so the Alis Build server can return context-aware skill instructions.
- **Service context (`SessionStart`)** — when a session opens inside an Alis Build service folder (`~/alis.build/<org>/build|define/…`), the package id and a pointer to the matching definitions ⇄ implementation counterpart are injected via `additionalContext`. Silent outside a workspace; requires `jq`.

The DBD primer and skill-routing contract are no longer injected by a hook — they live in `GEMINI.md`, which Gemini loads as standing context every session. The `BeforeTool` hook requires `jq` on your `PATH`; if `jq` is unavailable it exits cleanly and the CLI proceeds unmodified.

## Update

Update the extension:

```sh
gemini extensions update alis-build
```

Restart Gemini CLI after updating.

## Troubleshooting

If the extension does not appear in `/extensions list`, install it again:

```sh
gemini extensions install https://github.com/alis-build/gemini-cli-extension
```

If sign-in fails, confirm that you can reach `https://mcp.alis.build`, `https://agent.alis.build`, and `https://identity.alisx.com`, then run:

```text
/mcp auth alis-build
```
