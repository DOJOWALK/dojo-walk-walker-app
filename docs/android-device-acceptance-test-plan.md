# Android device acceptance test plan — Walker app

Status: manual test plan and implementation gap register; execution evidence has not yet been recorded.

## Current implementation boundary
The current Walker app repository is a Flutter starter with Firebase Core, Firebase Authentication, and Cloud Functions dependencies. Its README identifies profile/availability, assigned walks, and walk status as initial scope, but explicitly says production identity checks, location tracking, and payout workflows remain to be implemented. The current Android main manifest does not declare location permissions or a location/background service. Therefore location tracking and background walk monitoring must be treated as **not implemented**, not as test-passing features.

Do not request location permission from walkers until a clear, consent-based location feature and its retention/access policy are implemented.

## Preconditions for a future device test
- Dedicated non-production Firebase project and test accounts.
- Android physical device(s), including one recent Android release and one supported older release.
- Backend test data with assigned walk jobs and known schedule boundaries.
- Documented walker onboarding/identity review and customer handover procedures.
- If location is later implemented: a documented purpose, foreground-service design, runtime permission flow, visible notification, stop controls, retention policy, and backend access rules.

## A. Install, authentication, and account isolation
1. Install and launch the candidate build; verify no crash on cold start and relaunch.
2. Sign in with an approved walker account; verify customer/admin accounts cannot enter walker-only workflows.
3. Sign out and switch accounts; verify prior walk/customer data is cleared from the visible session.
4. Test invalid credentials, expired session, offline launch, and server permission errors.
5. Verify no sensitive customer or dog information is exposed outside an assigned job.

## B. Assignment and schedule integrity
1. Verify only jobs assigned to the signed-in walker are visible.
2. Verify date, local time (Asia/Kolkata), duration, service address, and dog-care instructions match backend data.
3. Verify overlapping jobs cannot both be accepted or started.
4. Verify leave/unavailability and travel/rest buffers are respected by backend assignment.
5. Verify a changed or withdrawn assignment is reflected after refresh; stale cached data must not authorize a walk.
6. Verify a backup walker cannot see or accept a job unless the backend has explicitly assigned it with the required customer consent.

## C. Walk lifecycle and safety
1. Verify the walker can see the required owner handover and emergency contact instructions for an assigned walk.
2. Verify start/complete actions are authenticated, authorized for that walker, and idempotent on repeated taps.
3. Verify a second start/completion request does not create duplicate events or payout entries.
4. Verify the app does not offer off-leash or multi-household handling as a default.
5. Verify incident reporting captures the minimum necessary details and routes the issue to DOJO WALK operations.
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