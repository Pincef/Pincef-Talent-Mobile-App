# Pricing and subscription audit handoff

Saved 17 October 2026 for follow-up. This note records the supplied pricing proposal, the Flutter client findings, and the decisions needed before implementation. No billing code was changed during the audit.

## Reference pricing proposal

Source: `C:\Users\Ejinne\Downloads\PINCEF TALENTBRIDGE PRICING .docx`.

| Offer | Proposed price and unit | Included items in the document |
| --- | --- | --- |
| One-time trial | Free, no card; one recruitment process, with all features | Trial should run from job post through hiring |
| Free | ₦0 | 20–30 CV-download credits; job posts; no AI; recruiters review downloaded CVs themselves |
| Starter | Stakeholder-approved ₦15,000/job (suggested ₦19,900) | 1 job; 500 CVs/job; CV parsing, resume summaries, basic matching and ranking |
| Professional | Stakeholder-approved ₦35,000/job (suggested ₦39,900) | 1 active job; 1,500 CVs/job; CV-to-job matching, ranking, competency assessment, comparison, reports |
| Business | Stakeholder-approved ₦75,000/job (suggested ₦79,900) | 1 active job; 1,500+ CVs/job; advanced AI, job-description and assessment generation, interview scheduling, customizable pipeline, reports, team access, integrations, priority support |

The proposal positions TalentBridge as “More than a job board. An AI-powered recruitment workspace.” It also compares the prices to named competitors. Recheck those competitor prices before publishing because they may change.

## Findings in the Flutter client

1. **Billing unit and cadence conflict.** The proposal prices by job. `payment_screen.dart` presents monthly/annual billing and a 20% annual discount, while `post_job_screen.dart` gates job publication using `jobsPerMonth`. Decide whether customers pay per job or on a recurring subscription, then align the plan catalog, pricing copy, checkout interval, and usage rule. If it is per job, define what happens on close/reopen and remove recurring cadence language unless it is also an approved offer.
2. **CV allowances are not surfaced as structured usage.** The client has a generic `UserModel.limits` map, but no CV-credit/usage fields or matching UI were found. `DownloadCvButton` checks that a résumé URL exists and starts the download; it does not display or decrement a client-visible allowance. Add structured plan limits, keep enforcement server-authoritative, and show used/remaining CVs at the job and account level.
3. **Trial behavior is not modeled as specified.** The client can display a subscription status string, but the one-time, all-feature, one-process trial and its expiry/process limit are not represented in the user flow. Add an explicit server-backed trial state and UI for eligibility, process scope, expiry, and conversion.
4. **Entitlements need a single tier map.** Assessments check `hiring.stage.assessment`; the assessment creation screen describes access as Professional or Business. The interview calendar allows scheduling for Pro and Business, while the pricing proposal lists interview scheduling under Business. Candidate ranking is reachable and relies on a later locked response. Decide and document tier access for each capability (including manual assessment vs AI generation), then use the same entitlement data for navigation, feature controls, and server enforcement.
5. **Renewal, return, and status flows are incomplete or ambiguous in the client.** The screen starts hosted checkout and offers a management link/manual refresh. It parses `currentPeriodEnd` but does not show it; no explicit checkout return route or automatic refresh was found. It also treats any non-null subscription as active when blocking other plans, and treats a null subscription as Free/current. Handle active, trialing, past-due, cancelled, expired, and unresolved states explicitly; refresh subscription and entitlements on checkout return; show renewal/trial-end details and invoice/cancel/manage actions as supported by the server.
6. **Billing guidance conflicts.** The support FAQ describes monthly quota resets, but the pricing proposal describes per-job CV allowances and per-job pricing. Rewrite billing help after choosing the product model.

## Scope and verification limits

- The repository reviewed here contains the Flutter client billing files and API calls (`/payment/plans`, `/payment/subscription`, `/payment/checkout`, `/payment/manage`), but no matching payment server implementation. Webhook verification, checkout success/cancel URLs, server-side quota enforcement, and the actual deployed plan catalog remain unverified.
- No CV-credit balance or AI-token balance is available in the client code reviewed. The document’s “credits” are CV-download credits, not a visible model-token meter. I cannot inspect the user’s personal Codex token balance from this workspace.
- No account usage amount was provided, so whether the current account has enough CV credits cannot be determined.

## Resume here

First confirm the billing unit: **per job** or **recurring monthly/annual**. Then inspect the backend catalog and payment/webhook implementation, agree the entitlement/limit matrix for each tier, and update the pricing UI, server rules, trial flow, and billing help together. Add tests for checkout state transitions, tier gates, and quota boundaries before release.

Relevant Flutter files:

- `lib/features/payments/presentation/screens/payment_screen.dart`
- `lib/features/payments/data/payment_repository.dart`
- `lib/features/auth/data/models/user_model.dart`
- `lib/core/entitlements/module_codes.dart`
- `lib/features/jobs/presentation/screens/post_job_screen.dart`
- `lib/features/jobs/presentation/widgets/download_cv_button.dart`
- `lib/features/interviews/presentation/interview_calendar_screen.dart`
- `lib/features/assessment/presentation/assessment_list_screen.dart`
- `lib/features/jobs/presentation/screens/ai_candidate_ranking_screen.dart`
- `lib/features/support/presentation/support_center_screen.dart`
