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

1. Review the HTML pages at `docs/emmaprep/privacy/` and
   `docs/emmaprep/delete-account/` with the privacy adviser.
2. Enable GitHub Pages for the repository using the `docs/` folder, or deploy
   those two folders to the existing `takunda.vito.co.zw` host.
3. If using GitHub Pages, point the `takunda.vito.co.zw` DNS record at the
   GitHub Pages target shown by GitHub and wait for HTTPS issuance.
4. Confirm the two URLs from a private browser session.
5. Replace the provisional markers in the release evidence with the deployment
   date, policy version and reviewer approval.
6. Only then paste the URLs into Play Console.
