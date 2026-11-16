# Android device acceptance test plan — Walker app

Status: manual test plan and implementation gap register; execution evidence has not yet been recorded.

## Current implementation boundary
The current app implements mobile-only OTP sign-in with a separate OTP screen, automatic Firebase phone verification when Android can complete it, and manual OTP fallback. Existing Firebase phone accounts resolve to their original UID; first-time numbers proceed to the worker application form. Email is optional only during worker application and is not a login method. Walker application submission and pending/approved states, availability-window creation, an assigned/upcoming walk dashboard, and backend-authorized start/complete actions. The backend enforces active approved walker status, assignment ownership, walk timing, and a minimum five-minute in-progress period before completion. These are implemented flows that still require device acceptance testing. Production identity/document verification, incident reporting, owner handover capture, location tracking, and payout workflows are **not implemented**. The Android main manifest does not declare location permissions or a location/background service. Do not represent any of those missing capabilities as available.

Do not request location permission from walkers until a clear, consent-based location feature and its retention/access policy are implemented.

## Preconditions for a future device test
- Dedicated non-production Firebase project and test accounts.
- Android physical device(s), including one recent Android release and one supported older release.
- Backend test data with assigned walk jobs and known schedule boundaries.
- Documented walker onboarding/identity review and customer handover procedures.
- If location is later implemented: a documented purpose, foreground-service design, runtime permission flow, visible notification, stop controls, retention policy, and backend access rules.

## A. Install, authentication, and account isolation
1. Install and launch the candidate build; verify no crash on cold start and relaunch.
2. Sign in with an approved walker account using mobile OTP; verify customer/admin accounts cannot enter walker-only workflows.
3. Submit a new walker application and verify it remains pending/inactive until admin approval; verify an approved account reaches the dashboard.
4. Verify the legacy email/password account can be linked to a verified mobile number without silently merging a different existing account.
5. Sign out and switch accounts; verify prior walk/customer data is cleared from the visible session.
6. Test invalid OTP, expired session, offline launch, and server permission errors.
7. Verify no sensitive customer or dog information is exposed outside an assigned job.

## B. Assignment and schedule integrity
1. Verify only jobs assigned to the signed-in walker are visible.
2. Verify date, local time (Asia/Kolkata), duration, service address, and dog-care instructions match backend data.
3. Verify overlapping jobs cannot both be accepted or started.
4. Verify availability windows cannot overlap and that leave/unavailability and travel/rest buffers are respected by backend assignment; document any missing leave-editing controls.
5. Verify a changed or withdrawn assignment is reflected after refresh; stale cached data must not authorize a walk.
6. Verify a backup walker cannot see or accept a job unless the backend has explicitly assigned it with the required customer consent.

## C. Walk lifecycle and safety
1. Confirm owner handover instructions and emergency contact details are not yet captured/displayed in the current app; block live operations until an approved operational handover process exists.
2. Verify start/complete actions are authenticated, authorized for that walker, and idempotent on repeated taps.
3. Verify a second start/completion request does not create duplicate events or payout entries.
4. Verify the app does not offer off-leash or multi-household handling as a default.
5. Confirm in-app incident reporting is not implemented; block live operations until walkers have a tested incident escalation channel to DOJO WALK operations.
6. Verify a walk cannot be marked complete before its valid assignment/start state according to backend rules.
7. Verify offline actions are not shown as server-confirmed until synchronized and acknowledged.

## D. Location — blocked pending implementation
When a location feature is designed and implemented, test separately:
1. Explain the purpose and obtain explicit in-app consent before requesting Android location permission.
2. Test approximate vs precise permission, deny, deny permanently, and permission revocation in Settings.
3. Test foreground-only permission and background permission only if genuinely required and justified.
4. If using a foreground service, verify its persistent Android notification, user-visible stop control, and correct start/stop lifecycle.
5. Verify tracking stops immediately at walk completion, cancellation, sign-out, and permission revocation.
6. Verify no tracking occurs outside an active, authorized walk; verify battery/network behavior and recovery after process death.
7. Verify location access is restricted to authorized operations, retention is limited, and customer-facing sharing is explicit.
8. Verify location data is not used as sole proof of walk completion or as an undisclosed worker-surveillance mechanism.

These are future acceptance criteria, not currently available app behavior.

## E. Release evidence required
- [ ] Android build/install evidence on physical devices.
- [ ] Sections A–C executed with pass/fail, device/OS, build SHA, and redacted job IDs.
- [ ] Location feature implemented, reviewed for privacy, and separately tested before any location permissions are added.
- [ ] Assignment and walk-state backend authorization tests pass.
- [ ] No unresolved Critical/High safety or privacy defects.
- [ ] Product/operations sign-off before production credentials or deployment.

This plan is not evidence that any manual device test has passed.