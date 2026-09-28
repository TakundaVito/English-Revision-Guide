# Company evaluation package

The company build lets a prospective buyer or education partner evaluate
EmmaPrep without receiving production credentials or access to real student
records.

## What evaluators receive

- `EmmaPrep-Company-Demo.apk` for an Android phone or tablet.
- `EmmaPrep-Web-Demo.zip` for deployment to any static web host.
- This evaluation guide and the in-app five-step product checklist.

The build is visibly marked **Company evaluation build**, works without an
account, uses bundled demonstration content, and stores progress only on the
evaluator's device.

## Personalize a build

Copy `config.company-demo.json`, change `EMMAPREP_EVALUATOR_NAME` to the
company name, and optionally set `EMMAPREP_FEEDBACK_URL` to a survey or booking
form. Do not add production Supabase or AI credentials.

Build Android:

```powershell
flutter build apk --debug --dart-define-from-file=config.company-demo.json
```

Build the browser demo:

```powershell
flutter build web --release --dart-define-from-file=config.company-demo.json
```

## Suggested evaluation flow

Give each company seven days and ask one product owner, one English teacher,
and two learners to complete the in-app checklist. Ask them to score:

1. Curriculum relevance and accuracy.
2. Ease of navigation for learners.
3. Quality of explanations and practical examples.
4. Offline usefulness and perceived performance.
5. Accessibility and suitability for school devices.
6. Likelihood of piloting or purchasing the product.

Do not collect real learner information in the evaluation build. A production
pilot should use a separately configured backend, named data controller,
privacy notice, support contact, and written pilot terms.
