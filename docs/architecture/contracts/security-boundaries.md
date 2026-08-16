# Security Boundary Contracts

## ActorContext

The identity adapter produces `ActorContext(actor_id, workspace_id, policy_keys, session_id,
authenticated_at)`. Only server middleware creates it. Application use cases require it explicitly.
Browser-supplied actor, workspace, policy, or ownership fields are ignored for access decisions.

The role and identity products remain open. Until they are selected, the policy engine defaults to
deny and tests use explicit fixture policies for view navigation, manage connections, edit Memory,
build pages, and view page context.

## SecretVault

`SecretVault` supports store, use-with-provider-operation, rotate, and delete. Store returns an opaque
reference. Read is not a general public operation. Only provider adapter execution can request that a
secret be used, and it supplies workspace, provider, connection, operation, and trace context.

Vault audit records contain secret reference digest, actor or worker identity, operation, provider,
outcome, and time. They never contain secret values. Production requires managed key rotation,
least-privilege service identity, backup or reauthorization strategy, and tested emergency revoke.

## Secret scanning and redaction

Every chat or Memory message passes through one shared scanner before persistence. The scanner finds
known token formats, authorization codes, private keys, credential phrases, and values that match
currently stored secret fingerprints without retrieving the secrets. It replaces the value with a
typed marker and records only redaction class and count.

The same boundary protects model prompts, agent output, logs, events, provider diagnostic capture,
screenshots, and test evidence. Redaction is fail-closed for persistence and export. A false positive
can be reviewed through a privileged process, but raw candidate text is not copied into normal logs.

## External content

User text, Memory text, provider labels, provider data, and model output are untrusted. They are data,
not instructions to the server. They pass through size limits, encoding, typed parsing, and content
security controls. Provider URLs come from adapter configuration, not provider payloads or generated
definitions.

## Browser boundary

The browser holds only secure, HTTP-only session cookies and non-secret view data. The server uses
request-forgery tokens, strict origin checks, content security policy, frame restrictions, safe output
encoding, and bounded uploads. OAuth callback state is single-use, short-lived, bound to the session
and workspace, and compared in constant time.

## Generated-page boundary

Generated pages run through the fixed application renderer. They cannot inject scripts, HTML,
stylesheets, network requests, SQL, filesystem paths, or new component implementations. All data
requests use typed canonical metrics and connection IDs already owned by the workspace. The server
rechecks ownership and capability at execution time.

## Required threat tests

- Cross-workspace ID substitution on every resource route.
- Authorization callback replay, state mismatch, wrong workspace, and expired attempt.
- Secret paste into both conversations, provider payloads, model output, and logs.
- Prompt injection through every untrusted text source.
- Agent output with script, network URL, SQL, huge payload, unknown component, or secret-like value.
- Forged event-stream cursor and access to another workspace's event.
- Worker job payload substitution and secret-reference substitution.
- Published-page query after connection removal or permission downgrade.
