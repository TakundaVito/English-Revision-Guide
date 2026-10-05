# English Prep account-deletion procedure

This is an implementation and operations specification. It is not complete
until the owner supplies a monitored public URL and the deletion path is tested
against the production Supabase project.

## User-facing requirement

Provide both:

1. an in-app, clearly labelled “Delete account” or “Request account deletion”
   action for signed-in learners; and
2. a public HTTPS page linked from the Play listing where a learner or guardian
   can submit a deletion request without installing the app.

The public page must identify English Prep, explain verification, show the
support/privacy contact and state the expected completion time. Do not ask a
requester to email a password, authentication token or identity document unless
the privacy adviser has approved a secure verification process.

## Deletion workflow

1. Verify that the requester controls the account or is its authorised guardian.
2. Record a request ID, received time and verification result without storing
   unnecessary sensitive material.
3. Disable access while the request is processed.
4. Delete the Supabase Auth user and cascading learner profile.
5. Delete server-side progress, uploaded material, coach/scanner records and
   support records associated with the account.
6. Remove or anonymise operational events whose actor reference remains.
7. Clear local data on the learner’s device at the next authenticated session,
   and tell the learner how to uninstall or clear app storage immediately.
8. Send a completion notice and retain only a minimal compliance record.

## Acceptance tests

- A signed-in learner can find and start deletion in at most three taps.
- The public URL works without an app install and on a phone browser.
- Invalid requests cannot delete another account.
- Deletion is idempotent and leaves no learner profile or auth account.
- The process does not log passwords, tokens, prompts, images or question text.
- A second reviewer verifies the production result before launch.

## Owner fields

- Public URL: `https://takunda.vito.co.zw/emmaprep/delete-account` *(publish after review)*
- Support address: `takunda@vito.co.zw`
- Maximum completion time: `[time period]`
- Production deletion function/migration: `[commit or deployment ID]`
- Privacy/legal approval: `[reviewer, date, evidence link]`
