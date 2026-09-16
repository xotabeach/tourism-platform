# Beta AI access and Travel+ purchase lock

Status: implemented and locally verified on 2026-09-16.

## Outcome

- DeepSeek uses the official V4.1 Flash API identifier `deepseek-flash`.
- AI route planning is available to every authenticated user during beta.
- Every user receives the same beta AI limits: 5 successful route generations
  and 30 assistant replies per UTC day.
- Travel+ remains visible as a preview marked «Скоро», but self-service purchase
  never activates a subscription. The app explains that purchase is unavailable
  during beta.
- Existing active subscriptions remain unchanged. Admin grants and cancellation
  remain available.
- The Android release build uses CI-safe Gradle memory settings.

## Scope

### Backend

1. Apply the shared beta AI entitlement to free and Travel+ users.
2. Enforce generation quota transactionally through the existing per-user lock.
3. Enforce a cross-session daily assistant-reply quota, also serialized per user.
4. Reject `mock_checkout` activation independently of `APP_ENV`; direct API calls
   must not bypass the mobile UI.
5. Keep existing subscription rows and the admin activation path intact.

### Mobile

1. Gate AI entry by the server-provided `ai_chat_enabled` capability rather than
   `travel_plus_active`.
2. Present AI selection as available to everyone in beta.
3. Mark Travel+ as «Скоро» and replace checkout activation with the notice:
   «В бета-версии покупка подписки недоступна».
4. Do not call the activation API or mutate local subscription state from checkout.

### CI

Reduce Gradle heap/metaspace pressure and worker concurrency so the shared runner
does not lose the daemon while assembling the release APK.

## Red-team findings and mitigations

- **Direct activation bypass:** production currently identifies as `test`, so an
  environment-based mock guard is not a security boundary. The public and service
  activation paths must fail closed for `mock_checkout`.
- **New-session quota bypass:** the existing message limit is per session. The new
  daily reply quota counts assistant messages across all sessions owned by the user.
- **Concurrent requests:** quota checks use a `FOR UPDATE` lock on the user row so
  parallel requests cannot exceed the configured allowance.
- **Existing subscribers:** no migration or revocation is performed.

## Acceptance criteria

- A non-subscriber can create, reopen and use an AI planning session.
- The sixth route-generation attempt in one UTC day returns HTTP 429.
- The thirty-first assistant-reply attempt in one UTC day returns HTTP 429 even
  when a new chat session is created.
- POST `/me/travel-plus/activate` cannot create a subscription in any environment.
- Tapping checkout shows the beta notice and leaves subscription state unchanged.
- Existing active subscriptions still render as active and can be cancelled.
- Backend tests, Flutter analysis/tests and an Android release build pass.

## Required post-beta rollback

Before enabling paid Travel+, replace the shared beta AI entitlement with the
approved free/paid matrix, connect verified store/server billing, restore accurate
paywall copy, and remove the beta-only purchase notice. Track this explicitly as
`POST_BETA: restore Travel+ billing and tiered AI limits`; do not silently remove
the limits or reopen `mock_checkout`.
