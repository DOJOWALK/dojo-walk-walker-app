# DOJO WALK — Walker App

Flutter app for DOJO WALK walker onboarding and walk fulfilment.

## Implemented in the current feature branch

- Mobile-number-only sign-in with a separate OTP screen; Firebase Android auto-verification is used when available, with manual OTP fallback.
- Automatic Firebase phone-account resolution: an existing phone account returns to its existing UID/profile; a first-time phone number receives a new account and opens the worker application flow.
- Optional email collected only in the worker application form; email/password is not a login method.
- Walker application submission and pending/approved account states; email is optional on the application form only.
- Availability-window creation through the authenticated backend.
- Assigned upcoming and in-progress walk dashboard.
- Authenticated start/complete actions, with assignment ownership and timing checks enforced by backend callables.
- Firebase Authentication and Cloud Functions integration.

## Not yet implemented

- Production identity/document verification workflow.
- Owner handover checklist and emergency-contact capture.
- In-app incident reporting and operations escalation.
- Location tracking or background location service.
- Walker payout ledger and payout processing.

Do not treat the missing items above as available features. In particular, the app does not request location permissions and must not begin tracking walkers until a consent-based design, access controls, retention policy, and device tests are approved.

## Run

```bash
flutter pub get
flutter run
```

See [Android device acceptance test plan](docs/android-device-acceptance-test-plan.md) for device checks and release evidence requirements.
