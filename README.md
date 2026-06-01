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
- OAuth client credentials registered with redirect URI `http://localhost:7777/oauth/callback`
- An Alis Build account that can grant these OIDC scopes:
  - `build:read`
  - `build:write`
  - `ideas:read`
  - `ideas:write`

## Install

```sh
gemini extensions install https://github.com/alis-build/gemini-cli-extension
```

During install, Gemini CLI prompts for the extension settings:

- `Alis Build OAuth Client ID`
- `Alis Build OAuth Client Secret`

`gemini extensions install` does not currently support passing these values as command-line arguments. If you skipped settings during install, configure them afterwards:

```sh
gemini extensions config alis-build "Alis Build OAuth Client ID"
gemini extensions config alis-build "Alis Build OAuth Client Secret"
```

Restart Gemini CLI after installing.

## Local Development

From this repository:

```sh
gemini extensions link .
```

Configure OAuth credentials:

```sh
gemini extensions config alis-build "Alis Build OAuth Client ID"
gemini extensions config alis-build "Alis Build OAuth Client Secret"
```

Restart Gemini CLI after linking or changing extension files.

## OAuth Setup

The MCP server and remote agent both use OAuth/OIDC through `https://identity.alisx.com`.

The OAuth client must allow this redirect URI:

```text
http://localhost:7777/oauth/callback
```

The extension reads credentials from Gemini extension settings:

- `ALIS_BUILD_OIDC_CLIENT_ID`
- `ALIS_BUILD_OIDC_CLIENT_SECRET`

The client secret is marked sensitive in `gemini-extension.json`; do not commit concrete client secrets to this repository.

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
- First MCP or agent use triggers or reuses OIDC login through `https://identity.alisx.com`.
- The MCP server and remote agent use OAuth client credentials from extension settings and the same Alis Build scopes.

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
- `oauth.clientSecret` is read from the sensitive `Alis Build OAuth Client Secret` extension setting.
- `oauth.redirectUri` is fixed to `http://localhost:7777/oauth/callback` because `identity.alisx.com` rejected Gemini's default random localhost callback.
- `oauth.scopes` declares the required Alis Build scopes: `build:read`, `build:write`, `ideas:read`, and `ideas:write`.
- The remote agent auth block uses the same env-backed client credentials and scopes.
- Users can trigger or repair auth with `/mcp auth alis-build`.
- OAuth needs local browser access and a localhost callback receiver.
- Gemini stores MCP OAuth tokens under `~/.gemini/mcp-oauth-tokens.json`.

Do not commit private OIDC client secrets to this repository. OAuth credentials are provided through Gemini extension settings.
