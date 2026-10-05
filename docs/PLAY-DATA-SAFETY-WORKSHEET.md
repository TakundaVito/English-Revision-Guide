# Google Play Data Safety worksheet

Complete this from the exact production build and enabled Supabase/AI
configuration. This worksheet is evidence for the Console form, not a
substitute for the form or legal advice.

| Data category | Collected? | Shared? | Purpose | Required? | Retention/evidence |
|---|---:|---:|---|---:|---|
| Name/display name | Confirm | Confirm | Account and learner experience | Confirm | Supabase schema/retention schedule |
| Email address | Confirm | Confirm | Authentication and support | Confirm | Supabase Auth policy |
| Account/device identifiers | Confirm | Confirm | Authentication, security and events | Confirm | Auth/event schema |
| App activity/progress | Confirm | Confirm | Revision progress and personalisation | Confirm | Local storage and server schema |
| User-generated prompts | Confirm | Confirm | AI coach response | Optional | Provider contract and logs |
| Photos/documents | Confirm | Confirm | Question scanning or coach attachment | Optional | Transient-processing test |
| Diagnostics/crash data | Confirm | Confirm | Reliability and security | Confirm | Hosting/log retention |
| Location, contacts, SMS, call logs | No | No | Not used by current app | No | Manifest and dependency audit |

Before submission, answer these questions with the privacy reviewer:

- Is each collected category disclosed in the public privacy policy?
- Is each shared category and every processor named or described accurately?
- Is data encrypted in transit and access-controlled at rest?
- Can a learner or guardian request deletion from inside and outside the app?
- Is the target audience declaration accurate for school-age learners?
- Are AI prompts/images excluded from provider training where required by the
  production contract?
- Are the answers still true for the exact uploaded bundle?

Approval: `[reviewer]`, `[role]`, `[date]`, `[bundle checksum]`.
