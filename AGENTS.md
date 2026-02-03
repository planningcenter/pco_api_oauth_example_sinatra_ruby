# AGENTS.md

## Overview

This is a Sinatra-based Ruby example application demonstrating OAuth 2.0, OpenID Connect (OIDC), and PKCE authentication flows with the Planning Center API. It serves both as a reference implementation and a working demo.

## Running the Application

### Install Dependencies
```bash
bundle install
```

### Configure Environment Variables
Required environment variables:
- `OAUTH_APP_ID` - OAuth application ID (confidential client)
- `OAUTH_SECRET` - OAuth secret (confidential client)
- `PUBLIC_OAUTH_APP_ID` - Public OAuth application ID (for PKCE flow)
- `SESSION_SECRET` - Session encryption secret (must be at least 64 characters)

Optional environment variables:
- `SCOPE` - OAuth scopes (default: `openid people services`)
- `DOMAIN` - App domain (default: `http://localhost:4567`)
- `API_URL` - Planning Center API URL (default: `https://api.planningcenteronline.com`)

### Start the Server
```bash
ruby app.rb
```

Or using rackup:
```bash
rackup config.ru
```

The app will be available at http://localhost:4567.

## Architecture

### OAuth Flows

This app demonstrates **two distinct OAuth implementations**:

1. **Server-side OAuth (Confidential Client)**: Implemented in `app.rb` using the `oauth2` gem
   - Uses authorization code flow with PKCE
   - Token and refresh token stored in server-side session
   - Automatic token refresh before expiration (300 second padding)
   - Endpoints: `/auth`, `/auth/complete`, `/auth/logout`

2. **Client-side PKCE (Public Client)**: Implemented in JavaScript within `views/login.erb`
   - Pure client-side implementation using browser APIs
   - Tokens stored in `sessionStorage`
   - Demonstrates public client pattern for SPAs/mobile apps
   - Uses `PUBLIC_OAUTH_APP_ID` (different from server-side flow)

### Application Structure

- `app.rb` - Main Sinatra application class (`ExampleApp`)
  - OAuth client setup and token management
  - API interaction via `pco_api` gem
  - Session-based authentication

- `config.ru` - Rack configuration for deployment

- `views/` - ERB templates
  - `layout.erb` - Main layout with navigation
  - `login.erb` - Login page with both OAuth flows (contains PKCE JavaScript)
  - `people.erb` - Displays People API data
  - `profile.erb` - Shows OpenID Connect user info and ID token claims

### Key Implementation Details

**Token Management** (app.rb:44-57):
- Tokens automatically refresh when within 300 seconds of expiration
- OAuth2::Error exceptions clear invalid session tokens
- Refresh token flow preserves user session without re-authentication

**ID Token Handling** (app.rb:71-85):
- JWT decoding without signature verification (demo purposes only)
- Production apps should verify JWT signatures using JWKS endpoint
- User info fetched from `/oauth/userinfo` endpoint

**API Client** (app.rb:59-61):
- `PCO::API` gem handles Planning Center API requests
- Initialized with current OAuth access token
- Automatically includes proper headers and URL construction

**PKCE Implementation**:
- Server-side: Uses `SecureRandom.urlsafe_base64(48)` for code verifier
- Client-side: Uses browser `crypto` API for code challenge generation
- Both use SHA-256 code challenge method

### OAuth Application Setup

Create OAuth applications at https://api.planningcenteronline.com/oauth/applications:
- Confidential client for server-side flow (requires OAUTH_APP_ID + OAUTH_SECRET)
- Public client for PKCE flow (requires PUBLIC_OAUTH_APP_ID)
- Set callback URL to `http://localhost:4567/auth/complete` for server-side flow
- Set callback URL to `http://localhost:4567` for PKCE flow
