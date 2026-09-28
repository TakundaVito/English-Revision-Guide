# Buyer due-diligence status

This record separates repository evidence from claims that require an owner,
qualified reviewer, deployed environment, or real device. It is intended for a
school, publisher, investor, or acquirer evaluating EmmaPrep.

## Verified in the repository

- Automated learner, administrator, backend, formatting, analysis, coverage,
  dependency-audit, and build gates run in GitHub Actions.
- A credential-free company evaluation mode and structured evaluation guide are
  available without production access.
- AI provider secrets remain server-side; the mobile and admin apps consume only
  public backend configuration.
- The current product source and documentation contain no named private learner
  experience or relationship-specific messages.
- Dependabot monitors Flutter and npm dependency manifests.

## Evidence still required before a sale or production launch

| Area | Required evidence | Responsible party |
| --- | --- | --- |
| Curriculum | Written review of every bundled and remote lesson/question against the current ZIMSEC 4005 syllabus and permitted source materials | Qualified English teacher/curriculum specialist |
| Intellectual property | Contributor, image, logo, question, model-output, and source-material ownership/licence register | Owner and legal adviser |
| Privacy | Jurisdiction-specific privacy notice, retention schedule, processor/subprocessor list, child-data basis and deletion/export procedure | Owner and privacy/legal adviser |
| Security | Review of deployed Supabase configuration, secret rotation, abuse limits, RLS behaviour, logs, backups, and incident response | Backend operator/security reviewer |
| Product evidence | Moderated pilot results from representative learners and teachers, including accessibility and learning-outcome observations | Pilot lead |
| Android release | Production signing custody, clean release build, device matrix, upgrade/rollback rehearsal, checksums and store policy checks | Release owner |
| Commercial transfer | Asset schedule, accounts/domains/store listings, contracts, liabilities, support terms and handover acceptance | Seller, buyer and legal advisers |

Repository tests cannot certify teaching accuracy, legal compliance, market
demand, or a valuation. Do not describe any conditional item as complete until
the named evidence is attached to the exact release commit.

## Suggested data room

Keep sensitive evidence outside the public repository. A buyer-facing data room
should contain the signed curriculum report, IP register, privacy/security
reviews, pilot report, production architecture and cost history, analytics with
personal data removed, release evidence, and the proposed asset-transfer list.
