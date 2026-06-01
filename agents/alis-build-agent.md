---
kind: remote
name: alis-build-agent
agent_card_url: https://agent.alis.build/.well-known/agent-card.json
auth:
  type: oauth
  client_id: $ALIS_BUILD_OIDC_CLIENT_ID
  client_secret: $ALIS_BUILD_OIDC_CLIENT_SECRET
  scopes:
    - build:read
    - build:write
    - ideas:read
    - ideas:write
  authorization_url: https://identity.alisx.com/authorize
  token_url: https://identity.alisx.com/token
  redirect_uri: http://localhost:7777/oauth/callback
---
