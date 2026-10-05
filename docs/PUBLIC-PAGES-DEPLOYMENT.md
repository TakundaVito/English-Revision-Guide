# Public privacy and deletion pages

Provisional URLs:

- Privacy: <https://takunda.vito.co.zw/emmaprep/privacy>
- Account deletion: <https://takunda.vito.co.zw/emmaprep/delete-account>

These URLs must not be entered into Play Console until they return live HTTPS
pages containing the approved policy and deletion instructions.

## Deployment acceptance checks

- Both URLs return HTTP 200 over HTTPS without authentication.
- The pages work on a phone browser and do not require the app to be installed.
- The privacy page names the same developer shown in Play Console.
- The deletion page identifies English Prep and explains verification and
  completion time.
- The support/privacy email is monitored and appears on both pages.
- No page requests a password, one-time code or private key.
- A second person verifies the deployed content and records the date, URL and
  policy version.

## Owner actions

1. Publish the reviewed pages on the existing `takunda.vito.co.zw` host.
2. Confirm the two URLs from a private browser session.
3. Replace the provisional markers in the release evidence with the deployment
   date, policy version and reviewer approval.
4. Only then paste the URLs into Play Console.
