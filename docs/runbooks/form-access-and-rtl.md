# TalentAI Form Access and RTL Runbook

## Current links

The current workflow boundary intentionally separates operators and candidates:

- `/form/talentai-hr-resume-assessment` is the authenticated HR assessment
  form in TAI-01. It shows assessment detail and displays the secure invitation
  action only when the deterministic decision is `MEETS_TARGET`.
- `/form/talentai-secure-interview-invitation` is the authenticated HR
  invitation issue/revoke form in TAI-05.
- `/form/talentai-candidate-interview` is the public, token-protected interview
  entry in TAI-04.

TAI-01 and TAI-05 use `n8nUserAuth` and require project execute access. Their
production URLs must additionally be restricted to the trusted HR network at
the reverse proxy, ingress, VPN, or firewall boundary. n8n Form Trigger also
supports an IP allowlist, but the committed workflow does not guess a company
CIDR or accept a fail-open environment value.

## Positive assessment action

TAI-01 adds an invitation action only for `MEETS_TARGET`. The action opens
TAI-05 with `action=ISSUE`, `extractionId`, and the default TTL pre-filled.
TAI-05 still requires an authenticated HR operator to submit the operation;
TAI-01 never creates or exposes a raw invitation token.

`REVIEW_REQUIRED` displays an HR review message. `BELOW_TARGET` does not show
an invitation action.

## Candidate resume submission

A future public candidate resume link must be a separate workflow rather than
a second Form Trigger in TAI-01. It should persist a pending submission, show a
generic acknowledgement, and expose no score, decision, correlation ID, or HR
action. HR approval then starts the existing internal assessment/invitation
flow.

## RTL styling

All committed Form Trigger and Form nodes embed the shared stylesheet from
`workflows/shared/talentai-form-rtl.css`. Persian content is right-to-left;
UUID, token, email, URL, code, and preformatted values remain left-to-right.

Edit the shared stylesheet and rerun the workflow generators. Do not edit CSS
only in the n8n UI because the next package import will replace that drift.
