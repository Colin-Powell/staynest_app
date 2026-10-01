# Become a Host: Existing Architecture and Gaps

## Existing Flow

- Authentication is backed by `users.role`; `backend/src/routes/auth.ts` and `google_auth.ts` put that single role in access tokens. Flutter copies it into `AppSession.currentRole`.
- `backend/src/middleware/auth.ts` authorizes protected routes from the JWT role. Property creation and landlord management routes use `authorize('landlord', 'host')`.
- KYC applications are stored in `verifications` (`backend/scripts/init-db.sql`). `POST /api/verifications` accepts documents and property data; `GET /api/verifications/me` returns the latest record. The Flutter flow is in `frontend/lib/screens/landlord/verification_flow.dart` and uses `VerificationApi`.
- Admin KYC decisions are exposed by both `/api/admin/kyc/:id` and `/api/verifications/:id`. Approval currently updates `users.verified` and sends email plus an in-app/push notification through `queueUserPush`.
- The tenant experience is `AppShell` in `frontend/lib/main.dart`; its profile menu renders `ProfileView`. The landlord experience is `/landlord` and `/portal`.
- Notification persistence is in `notifications`; `queueUserPush` writes the in-app record and then attempts Firebase delivery. Scheduled jobs are registered in `backend/src/services/cron.ts`.

## Gaps for Tenant-to-Host Upgrade

- `users.role` cannot represent both tenant and landlord access. `verified` is used by email OTP and KYC approval, so it is not a safe landlord-approval signal.
- The verification flow keeps uploaded-document progress in a widget session until final submission. There is no server-side verification draft or cancellation endpoint.
- Verification statuses do not include draft, more-information-required, or cancelled. Admin approval/rejection updates the verification and user in separate statements, not one transaction.
- Profile has no Become a Host entry, application-status card, reminder, or tenant/landlord portal switch.
- Existing property APIs are role-guarded, but the authorization middleware trusts a role copied into the access token and does not independently validate landlord approval.

## Implemented Design

- Added `users.roles` and `users.landlord_verified`; email OTP `verified` remains separate. Existing landlord approval is backfilled only when an approved verification record exists.
- Expanded verification records with server-saved drafts, submitted/cancelled timestamps, and reminder stage timestamps. The application supports draft, submitted, under review, more information required, approved, rejected, and cancelled.
- Approval locks and updates the verification plus the persisted landlord role in one transaction and writes an admin audit record. Approval requires identity and ownership/authorization documents.
- `authorize('landlord', 'host')` reads persisted roles and `landlord_verified`; the Flutter selected portal is not an authorization signal. Direct landlord/listing routes are guarded too.
- The existing Flutter verification components now resume server-stored document URLs and require ID front/back, selfie, and ownership/authorization proof. Submission returns to the tenant shell.
- Tenant profile includes Become a Host, application status/actions, submitted date, and approved portal switching. Active portal selection is persisted independently from account roles.
- Cron reminders use the existing notification queue at configurable `HOST_REMINDER_FIRST_HOURS` and `HOST_REMINDER_SECOND_HOURS` intervals (defaults: 24 and 72). Saves reset the schedule; submitted, cancelled, approved, or dismissed drafts are excluded.

## Validation

- Backend `npm test` compiles the service and passes the persisted-role authorization tests for pending, unapproved, approved dual-role, and approval-flag-only accounts.
- `flutter analyze` reports no compile errors in the touched frontend files; existing deprecation/context infos remain.
- A live database migration and end-to-end admin review/reminder test require configured database, Redis/notification, and test accounts and were not run here.