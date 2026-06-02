# Alis Build Gemini CLI Extension

Gemini CLI extension for Alis Build. It bundles:

- Remote MCP server configuration for `https://mcp.alis.build`
- Remote Alis Build sub-agent at `https://agent.alis.build`
- Alis Build context in `GEMINI.md`

This extension is Gemini CLI only.

This first release does not include custom slash commands or Agent Skills.

## Prerequisites

- Gemini CLI
- Network access to `https://mcp.alis.build`
- Network access to `https://agent.alis.build`
- Network access to the OIDC identity provider at `https://identity.alisx.com`
- OAuth client `cac878c2-ae88-47d4-89dc-3815ff556821` registered for loopback redirect URIs, including `http://localhost:*`
- An Alis Build account that can grant these OIDC scopes:
  - `build:read`
  - `build:write`

## Install

```sh
gemini extensions install https://github.com/alis-build/gemini-cli-extension
```

Restart Gemini CLI after installing.

## Local Development

From this repository:

```sh
gemini extensions link .
```

Restart Gemini CLI after linking or changing extension files.

## OAuth Setup

The MCP server and remote agent both use OAuth/OIDC through `https://identity.alisx.com`.

The OAuth client must allow loopback redirect URIs:

```text
http://localhost:*
```

The extension uses this public OAuth client ID:

```text
cac878c2-ae88-47d4-89dc-3815ff556821
```

## Verify

From the terminal:

```sh
gemini mcp list
```

Inside Gemini CLI:

```text
/extensions list
/mcp
/mcp auth alis-build
/agents list
```

Expected results:

- Extension list shows `alis-build`.
- MCP list shows `alis-build` configured for `https://mcp.alis.build/mcp`.
- Agent list shows `alis-build-agent`.
- First MCP use triggers or reuses OIDC login through `https://identity.alisx.com`.
- Agent use also triggers OIDC login through the same public OAuth client.
- The MCP server and remote agent use the same Alis Build scopes.

If authentication does not start automatically, run this inside Gemini CLI:

```text
/mcp auth alis-build
```

## Remote Agent

```text
@alis-build-agent Review my active Alis Build workspace and suggest the next build or deploy action.
```

## Update

```sh
gemini extensions update alis-build
```

Restart Gemini CLI after updating.

## Notes

The extension exposes all tools advertised by the Alis Build MCP server. It does not filter or exclude MCP tools.

Gemini CLI OAuth takeaways for this extension:

- `httpUrl` selects Streamable HTTP transport.
- `authProviderType: "dynamic_discovery"` lets Gemini discover OAuth/OIDC metadata from the remote MCP server.
- `oauth.enabled: true` makes the auth requirement explicit.
- `oauth.clientId` is required because `https://mcp.alis.build/mcp` does not support dynamic client registration.
- The OAuth client allows loopback redirects, so Gemini can use its default localhost callback port.
- `oauth.scopes` declares the required Alis Build scopes: `build:read` and `build:write`.
- The remote agent auth block uses the same public client ID and scopes.
- Users can trigger or repair auth with `/mcp auth alis-build`.
- OAuth needs local browser access and a localhost callback receiver.
- Gemini stores MCP OAuth tokens under `~/.gemini/mcp-oauth-tokens.json`.

This extension uses PKCE and does not require a client secret.
