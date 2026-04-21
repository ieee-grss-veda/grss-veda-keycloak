# VEDA Keycloak

Keycloak deployment for the GRSS VEDA project, managed via AWS CDK (Python) and configured with [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli).

## Project Structure

```
├── cdk/                          # AWS CDK infrastructure (Python)
│   ├── app.py                    # CDK app entry point
│   └── lib/                      # Stack definitions (ECS, RDS, etc.)
├── keycloak/
│   ├── Dockerfile                # Multi-stage build (Maven + Keycloak)
│   ├── providers/                # Custom Service Provider Interfaces (Java)
│   │   ├── email-whitelist-authenticator/
│   │   └── github-org-identity-provider/
│   └── themes/veda/              # Custom Keycloak theme
├── keycloak-config-cli/
│   ├── Dockerfile                # Config CLI image
│   └── config/                   # Realm configuration YAML files
│       ├── veda.yaml             # Base VEDA realm config
│       ├── veda.dev.yaml         # Dev overrides (GitHub OAuth IDP)
│       ├── veda.staging.yaml     # Staging overrides (SAML IDP)
│       ├── veda.prod.yaml        # Prod overrides (SAML IDP)
│       ├── veda.local.yaml       # Local testing overrides
│       ├── master.yaml           # Base master realm config
│       └── master.{env}.yaml     # Master realm env overrides
├── bin/apply-config.py           # Lambda invocation script for config deployment
├── set-email-whitelist.sh        # Email whitelist management utility
├── docker-compose.yaml           # Local development
└── .github/workflows/            # CI/CD pipelines
```

### Architecture

![Architecture Diagram](./.docs/architecture.excalidraw.svg)

## Local Development

### Prerequisites

- Python 3.13+ with [uv](https://docs.astral.sh/uv/)
- Docker & Docker Compose
- AWS CDK CLI (`npm install -g aws-cdk`)

### Running Locally

Start Keycloak with the default local configuration:

```sh
docker compose up --build
```

This starts Keycloak on `http://localhost:8080` (admin/admin) and applies the base + local config overlays.

To also start a Grafana instance for testing OAuth integration:

```sh
docker compose --profile grafana up --build
```

Grafana will be available at `http://localhost:3000` with Keycloak SSO enabled.

### Environment-Specific Config Overrides

Control which config files are loaded via `IMPORT_FILES_LOCATIONS`:

```sh
# Local (default)
IMPORT_FILES_LOCATIONS=/config/master.yaml,/config/master.local.yaml,/config/veda.yaml,/config/veda.local.yaml

# Dev (GitHub OAuth IDP)
IMPORT_FILES_LOCATIONS=/config/master.yaml,/config/master.dev.yaml,/config/veda.yaml,/config/veda.dev.yaml
```

## Configuration

We use [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli) to apply realm configuration at deployment time from YAML files in `keycloak-config-cli/config/`.

> [!IMPORTANT]
> At each deployment, keycloak-config-cli will overwrite changes made outside of the configuration stored in this repository for a given realm.

### Realms

The project manages two Keycloak realms:

- **master** — Admin console authentication. In dev, uses GitHub OAuth (with org check and auto-admin role assignment). In staging/prod, password-only.
- **veda** — User-facing applications (STAC, Ingest API, Airflow, JupyterHub, Monitoring/Grafana). In dev, uses GitHub OAuth. In staging/prod, uses SAML with a post-broker email whitelist check.

### Configuration Architecture

Configuration follows a **base + environment overlay** pattern:

- **Base files** (`veda.yaml`, `master.yaml`) define clients, roles, scopes, groups, and shared settings.
- **Environment files** (`veda.{env}.yaml`, `master.{env}.yaml`) add identity providers, authentication flows, and env-specific overrides.

> [!IMPORTANT]
> Do **not** put `authenticationFlows` in `veda.yaml`. Each environment file must declare all authentication flows it needs, because keycloak-config-cli deletes undeclared flows per file. Environment files are responsible for `browserFlow`, identity providers, auth flows, and `authenticatorConfig`.

### Authentication Flows

Each environment defines its own authentication flows:

| Environment | VEDA Realm Flow | Master Realm Flow |
|---|---|---|
| **Local** | "Browser with Whitelist" — password login + email whitelist check | Default browser flow |
| **Dev** | GitHub OAuth (github-org provider) | "Browser without Password" — auto-redirect to GitHub org check |
| **Staging/Prod** | "Browser with SAML" — SAML redirect + post-broker email whitelist check | Default browser flow (password-only) |

The email whitelist check runs as a **post-broker flow** in staging/prod, meaning it executes _after_ SAML authentication but before granting access. This ensures only whitelisted emails can log in even with valid SAML credentials.

### Service Accounts

The following service accounts are configured for automated API access:

- `service-account-airflow-stac-etl` — Admin role on the `stac` client, used by Airflow for STAC ETL operations.
- `service-account-airflow-ingest-api-etl` — Admin role on the `ingest-api` client, used by Airflow for ingest ETL operations.

### Creating Clients

#### Public Client

A minimum example of a public client (e.g. a single page application):

```yaml
clients:
  - clientId: grafana
    name: Grafana
    publicClient: true
    rootUrl: https://example.com
    redirectUris:
      - https://example.com/*
    webOrigins:
      - https://example.com
    protocol: openid-connect
    fullScopeAllowed: true
```

#### Private Client

For a private client, a secret is automatically created and injected into the configuration runtime environment at deployment. The secret is available via `$SLUG_CLIENT_SECRET`, where `$SLUG` is a slugified version of the `clientId` (e.g. `stac-api` becomes `STAC_API_CLIENT_SECRET`).

The generated client secret is stored in AWS Secrets Manager: `veda-keycloak-$stage-client-$clientId`. The secret contains:

* `id`: OAuth Client ID
* `secret`: OAuth Client Secret
* `auth_url`: OAuth [authorization endpoint](https://datatracker.ietf.org/doc/html/rfc6749#section-3.1)
* `token_url`: OAuth [token endpoint](https://datatracker.ietf.org/doc/html/rfc6749#section-3.2)
* `userinfo_url`: OIDC [user info endpoint](https://openid.net/specs/openid-connect-core-1_0.html#UserInfo)

A minimum example (note `publicClient: false` and `secret`):

```yaml
clients:
  - clientId: grafana
    name: Grafana
    publicClient: false
    secret: $(env:GRAFANA_CLIENT_SECRET)
    rootUrl: https://example.com
    redirectUris:
      - https://example.com/*
    webOrigins:
      - https://example.com
    protocol: openid-connect
    fullScopeAllowed: true
```

<details>

<summary>Consider also using an environment variable for URLs for greater flexibility</summary>


```yaml
clients:
  - clientId: grafana
    name: Grafana
    publicClient: false
    secret: $(env:GRAFANA_CLIENT_SECRET)
    rootUrl: $(env:GRAFANA_CLIENT_URL)$
    redirectUris:
      - $(env:GRAFANA_CLIENT_URL)$/*
    webOrigins:
      - $(env:GRAFANA_CLIENT_URL)$
    protocol: openid-connect
    fullScopeAllowed: true
```

> [!IMPORTANT]
> For the above example, we also must ensure that `GRAFANA_CLIENT_URL` is set within the Github Environment's variables via the Github settings console.

</details>

#### Scopes, Roles, and Groups

Clients will typically have associated Scopes, Roles, and Groups.

- Scopes can be thought of as individual permissions used by a client.
- Roles are collections of permissions that enable a typical function (e.g. system administration)
- Groups are collections of users that we want to grant with roles.

An example of a client with associated scopes, roles, & groups:

```yaml
clients:
  - clientId: grafana
    # ... omitted for brevity
    fullScopeAllowed: true
    defaultClientScopes:
      - web-origins
      - acr
      - profile
      - roles
      - basic
      - email
      - grafana:admin
      - grafana:editor
      - grafana:viewer

roles:
  client:
    grafana:
      - name: Administrator
        description: Grafana Administrator
      - name: Editor
        description: Grafana Editor
      - name: Viewer
        description: Grafana Viewer

clientScopeMappings:
  grafana:
    - clientScope: grafana:admin
      roles:
        - Administrator
    - clientScope: grafana:editor
      roles:
        - Editor
    - clientScope: grafana:viewer
      roles:
        - Viewer

clientScopes:
  - name: grafana:admin
    description: Admin access to Grafana
    protocol: openid-connect
  - name: grafana:editor
    description: Editor access to Grafana
    protocol: openid-connect
  - name: grafana:viewer
    description: Viewer access to Grafana
    protocol: openid-connect

groups:
  - name: System Administrators
    clientRoles:
      grafana:
        - Administrator

  - name: Developers
    clientRoles:
      grafana:
        - Editor

  - name: Data Editors
    clientRoles:
      grafana:
        - Viewer
```

> [!NOTE]
> To associate a client scope with a client, the scope must be referenced in either the `defaultClientScopes` or `optionalClientScopes` properties of the client.

### Identity Provider OAuth Clients

When a third party service operates as an Identity Provider (IdP, e.g. CILogon or GitHub) for Keycloak, we must register that IdP within the Keycloak configuration. This involves registering the IdP's OAuth client ID and client secret within Keycloak's configuration (along with additional information about the OAuth endpoints used within the login process).

At time of deployment, environment variables starting with `IDP_SECRET_ARN_` will be treated as ARNs to Secrets stored within AWS Secrets Manager. These secrets should be JSON objects containing both an `id` and `secret` key. These values will be injected into the docker instance running the Keycloak Config CLI, making them avaiable under `{CLIENTID}_CLIENT_ID` and `{CLIENTID}_CLIENT_SECRET` environment variables, allowing for their usage within a Keycloak configuration YAML file.

<details>

<summary>Example of injecting an IdP OAuth2 Client Secret</summary>

For this example, let's imagine we're attempting to insert the Client ID and Client Secret for a Github Identity Provider. To achieve this, we would take the following steps:

1. Submit these values to AWS Secrets Manager:

   ```sh
   $ aws secretsmanager \
      create-secret \
      --name veda-keycloak-github-idp-creds \
      --secret-string '{"id": "cl13nt1d", "secret": "cl13ntS3cr3t!"}'
   ```

   AWS will respond with the ARN of the newly created Secret.

1. Register the secret with the Github environment, named `IDP_SECRET_ARN_$CLIENTID`, where `$CLIENTID` is a unique identifier for that IDP (for this example, we'll use `GH`). This can be done via the Github CLI if run from within the project repo:

   ```sh
   # Add variable value for the current repository in an interactive prompt
   $ gh variable set IDP_SECRET_ARN_GH --env dev
   ```

1. Update the Github Actions workflow to inject this variable into the runtime environment when calling `cdk deploy`:

   ```diff
    - name: Deploy CDK to dev environment
      run: |
         cdk deploy --require-approval never --outputs-file outputs.json
      env:
         # ...
   +     IDP_SECRET_ARN_GH: ${{ vars.IDP_SECRET_ARN_GH }}
   ```

1. The `id` and `secret` will now be available when configuring Keycloak. We can add a section like the following to make use of these variables with `keycloak-config-cli/config/master.yaml`:

   ```yaml
   identityProviders:
   # GitHub with Org Check
   - alias: github-org-check # NOTE: this alias appears in the redirect_uri for the auth flow, update Github OAuth settings accordingly
      displayName: GitHub [NASA-IMPACT]
      providerId: github-org
      enabled: true
      updateProfileFirstLoginMode: on
      trustEmail: false
      storeToken: false
      addReadTokenRoleOnCreate: false
      authenticateByDefault: false
      linkOnly: false
      config:
         clientId: $(env:GH_CLIENT_ID)
         clientSecret: $(env:GH_CLIENT_SECRET)
         defaultScope: openid read:org user:email
         organization: nasa-impact
         caseSensitiveOriginalUsername: "false"
         syncMode: FORCE
   ```

</details>

## Service Provider Interfaces

Custom SPIs are Java/Maven projects in `keycloak/providers/`. They are compiled in a multi-stage Docker build and automatically loaded by Keycloak.

### Available Providers

| Provider | Description |
|---|---|
| `github-org-identity-provider` | Custom GitHub identity provider that validates organization and team membership |
| `email-whitelist-authenticator` | Authentication flow step that validates user emails against a whitelist stored in realm attributes (`ssoEmailWhitelist`). Supports exact emails and wildcard domains (e.g. `*@nasa.gov`) |

### Developing SPIs

- Target Java 11, Keycloak 26.0.0 dependencies (scope: `provided`)
- Package naming: `org.nasa.impact.keycloak.*`
- Each provider is a self-contained Maven project with SPI registration via `META-INF/services/`
- Build all providers locally: `keycloak/providers/build_and_collect_jars.sh`
- Follow patterns from existing providers

> [!TIP]
> See the Service Provider Interfaces section in the [Server Developer Guide](https://www.keycloak.org/docs/latest/server_development/#_providers) for more details.

## Themes

Custom themes live in `keycloak/themes/veda/` and extend the default Keycloak theme. Currently provides custom login messages for the email whitelist authenticator.

> [!TIP]
> See the theme section in the [Server Developer Guide](https://www.keycloak.org/docs/latest/server_development/#_themes) for more details about how to create custom themes.

## Email Whitelist Management

The email whitelist authenticator checks user emails against a comma-separated list stored in the `ssoEmailWhitelist` realm attribute. It supports exact email addresses and wildcard domain patterns (e.g. `*@nasa.gov`).

The `set-email-whitelist.sh` script manages this whitelist via the Keycloak Admin API. Requires `jq`.

```sh
# View current whitelist
./set-email-whitelist.sh --host https://keycloak.example.com --username admin --password secret

# Set whitelist from CSV
./set-email-whitelist.sh --host https://keycloak.example.com --username admin --password secret --emails "user@example.com,*@nasa.gov"

# Set whitelist from file (one email per line)
./set-email-whitelist.sh --host https://keycloak.example.com --username admin --password secret --file emails.txt
```

## Deployment

### CI/CD

Deployment is automated via GitHub Actions:

- **Push to `main`** triggers deployment to the **dev** environment.
- **Creating a release** triggers deployment to **prod**.

The deployment workflow:
1. Synthesizes and deploys the CDK stack (ECS + RDS infrastructure)
2. Invokes a Lambda function (`bin/apply-config.py`) to run keycloak-config-cli against the deployed Keycloak instance

### Manual Deployment

```sh
# Install dependencies
uv sync

# Synthesize CloudFormation template
uv run cdk synth

# Compare deployed stack with current state
uv run cdk diff

# Deploy
uv run cdk deploy
```

### Infrastructure

The CDK stack deploys:
- **ECS Fargate** service running the custom Keycloak Docker image (health check on port 9000)
- **RDS PostgreSQL** database for Keycloak persistence (supports snapshot restore via `rds_snapshot_identifier`)
- **Lambda** function to apply realm configuration via keycloak-config-cli
- **Secrets Manager** entries for client secrets and IdP credentials
- **Route53** DNS record for the Keycloak URL

Resource sizing (CPU, memory, RDS instance class) is configurable via environment variables in the GitHub environment settings. See `cdk/lib/settings.py` for available options and defaults.
