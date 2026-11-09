# mimic-cli

Command-line client for Mimic.

Single static binary, no runtime dependencies.

## Install

On macOS and Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/Ubikron-Tech-Farm/mimic-cli/main/install.sh | sh
```

On Windows, download the zip for your architecture from
[the releases page](https://github.com/Ubikron-Tech-Farm/mimic-cli/releases).

## Updating

```bash
mimic update            # latest release, verified against a signed checksums.txt, replaced in place
mimic update --check    # only report whether a newer release exists
mimic update --version 0.8.0
```

`update` uses the same public releases as `install.sh`. `GH_TOKEN` (or
`GITHUB_TOKEN`) is sent when set, which raises GitHub's rate limit. If the binary's directory isn't
writable it exits 9; rerun with `sudo`, or reinstall into `~/.local/bin`. After
replacing the binary it refreshes any `mimic-cli` skill that `skills install`
put in `./.claude/skills` or `~/.claude/skills`.

At most once a day, an interactive command checks for a newer release and for
an installed skill older than the binary, and prints a one-line notice on
stderr. It never runs under `--agent`, `--quiet`, in CI (`CI` set), for
development builds, or when stderr isn't a terminal. Set
`MIMIC_NO_UPDATE_NOTIFIER=1` to turn it off. The last check is cached in
`update-check.json` beside the config file.

## Quick start

```bash
# log in: opens your browser and redirects back to the CLI
mimic login

# log in to a private server (https:// is assumed; the server is saved to the profile)
mimic login --server mimic.example.com/mimic

# headless machine: print the approval URL, approve it, then finish with the one-time code
mimic login --no-browser
mimic login --code <code>

mimic status
mimic providers list
```

`mimic login` uses a passwordless browser grant by default. Password login is
explicit: `mimic login --password`, or `mimic login --email you@example.com`
(`MIMIC_EMAIL` also implies it). The password is read from the terminal, never
from a flag. `mimic logout` and `mimic status` end and inspect the session.
`mimic auth login`, `auth logout` and `auth status` remain as aliases.

To point at a local server instead, create a profile:

```bash
mimic config set local --server http://127.0.0.1:8000 --allow-insecure-http
mimic config use local
```

A server URL may include a reverse-proxy prefix such as
`https://example.com/mimic`; API requests keep that prefix and health checks
use `/mimic/health`. URLs with embedded credentials, queries or fragments are
rejected. Config changes use owner-only atomic writes and serialize profile
updates so concurrent commands retain each other's changes.

## Two authentication schemes

This trips people up, so it is worth stating plainly.

| Routes | Credential | How |
|---|---|---|
| Everything under `providers`, `keys`, `credentials`, … | **session cookie** | `mimic login` |
| `mimic services *` | **Mimic API key** | `--secret-file`, `--secret-stdin`, or `MIMIC_API_KEY` |

Being logged in is *not* enough for `services`: the backend requires
`Authorization: Bearer <mimic-key>` on `/search` routes and ignores the session
cookie. Create a key with `mimic keys create --name discovery --uncapped
--secret-output PATH` and point `services` at the saved key with
`MIMIC_API_KEY` or `--secret-file`.

## Commands

Run `mimic <command> --help` for flags. `--help` is authoritative; this table is
a map, not a substitute.

Provider create and update accept `--file <path>` or `--file -` for a JSON
object. File fields use the API names such as `display_name` and `is_enabled`;
command flags remain available for simple inputs. A field cannot be set by both
the file and a flag. Unknown fields, duplicate JSON keys and trailing data are
rejected before the request. Explicit null, false, zero and empty arrays retain
their meaning in the request body.

For agent callers, add `--agent` to emit one JSON object with `version`,
`command`, `data`, `warnings` and `error` fields. Failures use stable error
codes and keep diagnostics on stderr. Without `--agent`, successful `-o json`
output retains its existing response shape.

### login, auth, config

| Command | Purpose |
|---|---|
| `login` · `logout` · `status` | Session lifecycle. `login` opens a browser and redirects back (default); `login --server <url>` targets a private server and saves it to the active profile on success; `login --no-browser` prints the approval URL and either waits for the one-time code (on a terminal or with `--secret-stdin`) or saves a pending login that `login --code <code>` finishes (the default without a terminal, with `--non-interactive` or `--agent`); `login --password` or `--email` logs in with a password. `status` aliases `whoami`. |
| `auth login` · `logout` · `status` | Aliases for the commands above, with identical flags. |
| `account get` | Show the signed-in account profile. |
| `config show` | Effective settings **and where each came from**. |
| `version` · `doctor` | Print the CLI version (add `--server` to check the server contract); `doctor` checks local configuration, credentials and server compatibility. |
| `config list` · `use` · `set` · `remove` | Profile management. |

### providers

| Command | Purpose |
|---|---|
| `providers list` [`--callable`] | List providers. |
| `providers get <provider>` | Show one. |
| `providers create --name <name>` | Create. |
| `providers update <provider>` | Update. |
| `providers delete <provider>` [`--force`] | Delete, with its endpoints. Refused while users have credentials, balances, key grants or usage on it; `--force` deletes those too. |
| `providers endpoints list` · `get` · `create` · `update` · `delete` · `test` | Endpoint definitions and upstream tests. Create and update accept complete endpoint JSON with `--file FILE|-`; `test <provider> --file FILE|-` tests an unsaved definition, while `test <provider> <endpoint> [--file FILE|-]` tests a saved endpoint with optional `test_inputs` and `secrets`. Protect regular input files from group/other access. Testing calls the upstream service and never supports dry-run. |
| `providers endpoints handlers get` · `put` · `delete` | Read, save, or remove endpoint-scoped MappingSpec v1 JSON. |
| `providers endpoints handlers validate <provider> <endpoint> --file FILE\|-` | Validate an unsaved `mapping_spec`: server-side checks, then a local compile. Both must pass. |
| `providers endpoints handlers evaluate` · `preview <provider> <endpoint> [--file FILE\|-] [--spec FILE \| --saved] [--data FILE \| --live] [--input name=value]... [--summary [--rows N]] [--error-detail]` | Evaluate or render a mapping against sample `data` (payload: `mapping_spec`, `data`, optional `input_values`), or take each part from a flag. `--live` calls the real upstream with the `--input` values and uses its response. `--summary` (preview only) prints a compact outline of sections, table rows and graph edges. `--error-detail` adds the engine's raw message to failures, which may quote the expression and sample data. Lint warnings print on stderr. Returns `result_present` and `result`. |
| `providers endpoints handlers expressions evaluate` · `references <provider> <endpoint> --file FILE\|-` | Evaluate one expression, or list what it references (payload: `expression`, `data`, optional `constants`, `input_values`). |
| `providers endpoints handlers graph project <provider> <endpoint> --file FILE\|- [--output-file PATH [--force]]` | Project evaluated scopes into a semantic graph (payload: `graph_out`, `scopes`, optional `input_values`, `rows`). Returns `graph` and `graph_sources`. |
| `providers modifiers list` · `create` · `update` · `delete` | Provider-owned modifiers, including scalar or multi-value defaults and options. Use `--file` for explicit empty arrays, null clears, or full replacements. Delete requires `--cascade` when templates reference the modifier; the server performs template cleanup. |
| `providers secrets update` | Change whether a provider secret definition is required; this does not change stored user credentials. |
| `credentials get` · `create` · `update` · `set` | Inspect configured/missing state and a masked preview; create requires a missing credential, update requires an existing one, and set upserts. Values use a dedicated secret file, stdin, environment variable, or hidden prompt. |
| `providers endpoints create <provider> --input <property>` | Declare each accepted entity property by repeating `--input`. For example: `--input domain --input country`. The old `key=property` form is rejected because the API accepts property names only. |
| `providers secrets list` · `create` · `delete` | Which secrets a provider *requires*. `update`/`delete` take the secret name (`api_key`), its label, or the definition ID. |

`providers secrets` declares what a provider needs; `credentials` stores *your*
values for it.

Endpoint payloads use `--file FILE|-`; `entity_type_inputs` entries use
`property_name`, and `request_config` remains typed JSON so nested values and
template braces are preserved. In an update payload, use `request_config: {}`
to clear the config, `entity_type_inputs: []` to clear inputs, and an empty
description to clear that field. A null `request_config` is ignored by the API.

`keys access <key> --file FILE|-` replaces endpoint grants and provider pools
from complete `endpoints` and `provider_pools` arrays. Each entry has an
`endpoint_id` or `provider_id` and an optional positive `call_limit`; use
`call_limit: null` for unlimited. Both arrays are required, and `[]` clears a
grant list. Flag form accepts endpoint grants, provider pools, or both. The
command resolves numeric IDs against resources callable by the current account
before sending the replacement. Entity property updates
replace the ordered list and require `--yes`; `--dry-run` previews the change.

### keys

| Command | Purpose |
|---|---|
| `keys list` · `get` · `update` · `delete` | Key lifecycle. |
| `keys create --name <name>` | Create with endpoint/provider grants and a reset schedule. Choose `--secret-output FILE` or `--show-secret`. |
| `keys rotate <key>` | New secret, old one dies immediately. |
| `keys providers add` · `remove` · `update` | Grant, revoke, or change active state and pool quota. `remove`/`update` take the provider reference or the grant's link ID; a bare number is always a link ID. |
| `keys endpoints add` · `remove` · `update` | Grant, revoke, or change active state and endpoint quota. `remove`/`update` take the endpoint reference or the grant's link ID; a bare number is always a link ID. A capped key whose endpoint has neither `--call-limit` nor a provider pool limit can call it without limit, and the CLI warns. |
| `keys access <key> --endpoint …` | **Replace** endpoint and provider-pool grants; previews include current/new scopes and quota boundaries. |

**Trap:** a capped key must name at least one endpoint. `keys create --name x`
alone always fails. Pass `--endpoint`, or `--uncapped` for no usage cap.

**Trap:** `keys access` replaces rather than adds. Use `keys endpoints add` to
grant one without disturbing the rest.

The secret is returned **once** on create and rotate and cannot be retrieved
again. Choose `--secret-output PATH` to save it to a new owner-only file, or
explicitly choose `--show-secret` to print it. Without either choice, create
and rotate stop before sending a request. `--yes` only confirms destructive
actions; it never opts into printing a secret. JSON/YAML and agent output
include the one-time value only when `--show-secret` is selected.

These mutations accept `--dry-run`: `keys create`, `keys delete`, `keys rotate`,
`keys access`, `keys providers add|remove`, `keys endpoints add|remove`,
`providers delete`, `providers endpoints create|update|delete`,
`providers endpoints handlers put|delete`, `links create|update|delete`,
`links categories create|update|delete`,
`providers secrets update|delete`, `credentials create|update|set|delete`,
`types secrets update|delete`, `types entities delete`,
`config remove`, and `auth logout`. A preview resolves targets and checks local
inputs, then reports the resource IDs, path, and redacted intended parameters.
It does not ask the server to validate the write. Target lookups may send read
requests, and a target can change between preview and execution. Other
commands reject `--dry-run` locally.

`providers delete`, `providers endpoints delete` and `types entities delete`
accept `--force`. Without it the server refuses when anything depends on the
item and says what does. Deleting an entity type with `--force` also deletes its
child types, and turns off the endpoints, handlers and links that use it until
their owners review them.

### credentials, types

| Command | Purpose |
|---|---|
| `credentials list [provider]` | Summary across providers, or one provider's secrets. |
| `credentials get <provider> --type <type>` | Show configured/missing state and a masked preview; raw secret values cannot be retrieved. |
| `credentials create|update|set <provider> --type <type>` | Create only, update only, or upsert a secret value. Use `--secret-file`, `--secret-stdin`, `MIMIC_SECRET_VALUE`, or the hidden prompt. |
| `credentials delete <provider> <secret-id>` | Remove one. |
| `types secrets list` · `get` · `create` · `update` · `delete` | Global secret types; create, update, and delete require an administrator. |
| `types entities list` · `get` · `create` · `update` · `delete` | Entity type authoring. Create and update accept all supported fields in `--file`, including parent, ordered properties, main property, color, icon, matching pattern, sample, and description. Use null for supported clears and `properties: []` to replace properties with an empty list. The server validates inheritance and dependent endpoint conflicts. |
| `types entities detect --file FILE|-` | Detect entity types in a `value`. The server supplies the detection catalog; matching runs locally with the same engine as the web UI. Returns `matches`, `rejected_patterns`, and `diagnostics_truncated`. |
| `types entities system --credential-kind client\|server` | Read system entity types using one explicit key lane. |
| `types entities catalog --credential-kind client\|server` | Merge callable and system entity types; requires `MIMIC_API_KEY` plus the selected `MIMIC_CLIENT_KEY` or `MIMIC_SERVER_KEY`. |

### Authoring a handler

Handler evaluation runs locally in the CLI with the same mapping engine as the
web UI. The server provides only the endpoint context and entity catalog (and
the saved mapping); sample `data` and expressions never leave your machine.

```sh
mimic providers endpoints handlers get acme charges > handler.json
# edit mapping_spec in handler.json, then keep only {"mapping_spec": ...}
mimic providers endpoints handlers validate acme charges --file handler.json
mimic providers endpoints handlers preview acme charges --spec handler.json --live --input name=Ada --summary
mimic providers endpoints handlers put acme charges --file handler.json
```

`preview.json` holds `mapping_spec`, `data` (a sample upstream response), and
optional `input_values`. Use `evaluate` for the evaluated structure and
`expressions evaluate` to test a single expression. Mapping failures exit with
code 6, time limits with code 11, and input or output size limits with code 1;
error messages never repeat your data or expressions.

### links

| Command | Purpose |
|---|---|
| `links list` · `get` · `create` · `update` · `delete` | Manage links by numeric ID, slug, scoped slug, or display name. URL templates support only `{{value}}`. `update`/`delete` refuse links the account cannot edit (exit 9). Create/update support multiple `--entity-type` bindings and category references. Responses retain owner state, `can_edit`, and server warnings. |
| `links categories list` · `create` · `update` · `delete` | Administer link categories; the server enforces admin roles, normalized-name uniqueness, and in-use delete rules. |

### services, catalog

| Command | Purpose |
|---|---|
| `services list` | Discoverable services. **Needs an API key.** |
| `services get <namespace/slug>` | Show one service's inputs. **Needs an API key.** |
| `services run <namespace/slug>` | Call a service with `--input k=v` or `--file FILE\|-`. Inputs cover the endpoint's entity properties and the provider's modifiers (repeat a key for a multi modifier; omitted modifiers take their defaults). **Needs an API key.** |
| `catalog get` | Browse the client-key catalog. |

### skills

| Command | Purpose |
|---|---|
| `skills install` | Write the bundled `mimic-cli` agent skill to `./.claude/skills/mimic-cli`, to `~/.claude/skills` with `--global`, or to any skills directory with `--dir`, with a `.cli-version` stamp of the version and file hashes. Files from an older install are replaced; files edited since mimic installed them need `--force` (exit 5 otherwise). `mimic update` refreshes stamped installs. |
| `skills show [file]` | Print `SKILL.md` or a reference such as `references/graph-spec.md`, for agents that can't load skills. |

The skill's `references/mapping-spec.md` and `references/graph-spec.md` are the
mapping and graph briefs the Mimic web editor gives its AI, so they always match
the engine this binary runs.

## Referring to things

Most commands accept three forms:

```bash
mimic providers get 42                 # numeric id
mimic providers get stripe             # slug, if unambiguous
mimic providers get acme/stripe        # namespace/slug — canonical
```

A bare slug that matches more than one provider is an **error listing every
candidate**, never a guess. Prefer `namespace/slug` in scripts.

Endpoints extend this: `acme/stripe/charges`, `acme/stripe.charges` (the form
`services list` prints), `stripe/charges`, or a bare slug scoped by the provider
argument. Entity and secret types also accept a bare slug (`person`) or their
`namespace.slug` type name (`ubikron.person`).

## Configuration

Settings resolve in a fixed order, highest first:

```
flag  >  MIMIC_* environment  >  active profile  >  built-in default
```

`mimic config show` prints each effective value **and where it came from**,
which is usually the fastest way to answer "why is it talking to that server".

Config lives at `~/.config/mimic/config.toml` (override with `MIMIC_CONFIG`):

```toml
default_profile = "local"

[profiles.local]
server_url = "http://127.0.0.1:8000"
output = "table"
timeout = 30
allow_insecure_http = true
```

### Environment variables

| Variable | Purpose |
|---|---|
| `MIMIC_PROFILE` | Active profile |
| `MIMIC_SERVER_URL` | Server URL |
| `MIMIC_OUTPUT` | Output format |
| `MIMIC_TIMEOUT` | Request timeout, seconds |
| `MIMIC_CONFIG` | Config file path |
| `MIMIC_SESSION_TOKEN` | Session token, bypassing stored credentials (CI) |
| `MIMIC_API_KEY` | Runtime Mimic key for `services` |
| `MIMIC_CLIENT_KEY` | Client key for client-key catalog requests |
| `MIMIC_SERVER_KEY` | Server key for server-key provisioning requests |
| `MIMIC_EMAIL` / `MIMIC_PASSWORD` | Non-interactive password login (`MIMIC_EMAIL` implies password login) |
| `MIMIC_SECRET_VALUE` | Non-interactive `credentials set` |
| `--secret-file PATH` / `--secret-stdin` | Read a password, credential, or API key without placing it in argv |
| `MIMIC_CREDENTIALS_FILE` | Bypass the OS keyring for this file (CI, tests) |
| `NO_COLOR` | Disable coloured output |

## Output formats

`--output table|json|yaml|plain` (default `table`).

`json` is a **verbatim passthrough** of the server response, so piping to `jq`
behaves exactly as with `curl`. Table and plain render a projection, which may
carry fewer fields.

`plain` emits a single field per line for shell pipelines:

```bash
mimic providers list -o plain --field slug | xargs -n1 mimic providers get
```

## Exit codes

Scripts can branch on the failure kind rather than parsing messages.

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Generic failure |
| 2 | Usage error — the command was wrong |
| 3 | Authentication required or rejected |
| 4 | Not found |
| 5 | Conflict |
| 6 | Server-side validation failed — the request was malformed |
| 7 | Network failure or timeout |
| 8 | Server error (5xx other than 502–504) |
| 9 | Permission denied |
| 10 | Rate or quota limited |
| 11 | Upstream execution failure (including HTTP 502–504) |
| 12 | Canceled |
| 13 | Unsupported server capability |
| 14 | Partial operation |

The client rejects redirects, limits response bodies to 8 MiB, and retains
response headers. Safe GET requests have at most two retries. `Retry-After`
delays above two seconds are returned to the caller without an early retry;
429 responses without `Retry-After` are also returned immediately. Writes and
runtime execution are never retried automatically. Ctrl-C or SIGTERM cancels
local requests; cancellation does not imply that a server write was rolled back.

## Security

- The session token is stored in the **OS keyring**. With no keyring the CLI
  **fails** rather than silently writing cleartext; `--insecure-storage` opts in,
  and every such use warns in a way `--quiet` cannot suppress.
- Credentials are scoped to `(profile, server URL)`, so repointing a profile
  cannot reuse the previous server's credential. Session, runtime, client and
  server credentials each use a separate versioned identity.
- On Windows, the explicit cleartext fallback file must remain inside the
  current user's home directory so its owner-only ACL can be enforced.
- Plain `http://` to a non-loopback host is refused unless explicitly allowed;
  the session cookie would otherwise cross the network in cleartext.
- **No `--password` or `--value` flags.** Flag values persist in shell history
  and in the process list. Use the hidden prompt, `--secret-file`,
  `--secret-stdin`, or `MIMIC_PASSWORD` / `MIMIC_SECRET_VALUE`. Use
  `--secret-file`, `--secret-stdin`, or `MIMIC_API_KEY` for API-key
  authenticated commands.
- Destructive commands never prompt when stdin is not a terminal. Pass
  `--yes` to confirm explicitly; `--non-interactive` disables prompts even in
  a terminal.
- On Windows, `--secret-output` destinations must be inside the current user's
  profile. The CLI rejects directories where another principal can replace the
  staged file.
- All output and error text passes a redaction filter stripping `mk_*` keys,
  bearer tokens, and sensitive field values.

## Shell completion

```bash
mimic completion zsh > "${fpath[1]}/_mimic"      # or bash / fish / powershell
```
