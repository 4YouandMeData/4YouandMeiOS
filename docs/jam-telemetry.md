# Jam Telemetry

Source-of-truth doc for the unified event/telemetry layer that fans out to JamLog, Firebase Analytics, and (where applicable) Firebase Crashlytics. Owners: iOS framework maintainers. Update this doc in the same PR that introduces a new emit-point.

Substrate ticket: [FUAM-3053](https://bdx.atlassian.net/browse/FUAM-3053). Epic: [FUAM-3073](https://bdx.atlassian.net/browse/FUAM-3073). Analysis & first implementation: [FUAM-3075](https://bdx.atlassian.net/browse/FUAM-3075).

---

## Architecture

```
caller code
    │
    ▼
Telemetry.track(event)          ← single API for all emit-points
    │
    ▼
 Redactor.scrub(payload)        ← every payload passes through here
    │
    ▼
 ┌──────────┬───────────┬──────────────┐
 ▼          ▼           ▼              ▼
JamLog    Analytics    Crashlytics    (future: Mixpanel, Amplitude, …)
Sink      ServiceSink  Sink
```

### Sinks
- `JamLogSink` — every event, routed through `FYAMLog.{debug,info,warn,error}` (which fans to `os.Logger` + `JamLog`).
- `AnalyticsServiceSink` — only events with an existing `AnalyticsEvent` mapping. Wraps the unchanged `AnalyticsService`. Firebase Analytics dashboards keep working unchanged.
- `CrashlyticsSink` — only `level == .error` events. Reuses the existing `FirebaseAnalyticsPlatform.reportNonFatalError` path.

### Events
`TelemetryEvent` is a struct with category + name + level + payload + trace. Convenience builders live under `Telemetry.{nav,action,net,error,lifecycle}` so call sites stay short and the redaction rules are enforced before the payload reaches the facade.

---

## Event taxonomy

Naming convention: `<category>:<dotted.subname>` (e.g. `nav:tab.switch`, `net:request`, `error:handled`).

### `lifecycle` — framework / app lifecycle
| Event | Hook | Level |
|---|---|---|
| `lifecycle:framework.start` | `FYAMManager.startup` after `makeKeyAndVisible` | `info` |
| `lifecycle:user.session.start` | login success | `info` |
| `lifecycle:user.session.end` | logout / token expiry | `info` |

### `nav` — Navigation (user journey)
| Event | Hook | Level |
|---|---|---|
| `nav:appear` | `BaseViewController.viewDidAppear` (single override, all 81 VCs) | `info` |
| `nav:disappear` | `BaseViewController.viewDidDisappear` (existing override) | `debug` |
| `nav:tab.switch` | `AppNavigator` tab handler | `info` |

### `net` — Client-server
Single source: `TelemetryPlugin` (Moya `PluginType`) registered in `NetworkApiGateway.setupDefaultProvider()`. Replaces stock `NetworkLoggerPlugin`.

| Event | When | Level |
|---|---|---|
| `net:request` | `willSend` plugin hook | `info` |
| `net:response` | `didReceive` plugin hook | `info` (2xx) / `warn` (4xx) / `error` (5xx, network) |

Payload always includes `method`, `path`, `status` (response only), `duration_ms` (response only), `correlation_id`.

Body capture is configurable per host app via `FYAMManager.startup(..., networkBodyCaptureMode:)`:
- `.none` — never capture bodies.
- `.errorsOnly` — non-2xx response bodies only, redacted.
- `.truncated` (default) — request bodies up to 1 KB, response bodies up to 4 KB on 2xx, full on non-2xx; all redacted.

Sensitive endpoints (auth/token/OTP) are marked at the `DefaultService` level via `var isSensitive: Bool` and **always suppress bodies**, regardless of mode. Currently sensitive: `.emailLogin`, `.submitPhoneNumber`, `.verifyPhoneNumber`, `.sendPushToken`, `.getTerraToken`.

### `error` — Non-crash errors
| Event | Hook | Level |
|---|---|---|
| `error:handled` | `AppNavigator.handleError` (single chokepoint, ~20 call sites) | `error` |
| `error:reachability` | `ReachabilityManager` transitions | `warn` (lost) / `info` (restored) |

### `action` — State-mutating user actions
Convenience namespace `Telemetry.action.*` is available for instrumenting coordinator `submit()` / `save()` sites. Sites are added incrementally in follow-up commits — each site MUST consult the redaction policy below.

---

## Redaction policy

`Redactor.scrub(_:)` runs over every payload before it reaches any sink. Key match is case-insensitive.

### Always allowed in payloads
- Internal study identifiers in full: `User.id`, `study_id`, diary note IDs, survey IDs, question IDs, task IDs, integration IDs.
- Counts, durations, sizes, status codes, error codes.
- HTTP method, path (after secret-query-key scrub), Content-Type, response size.
- Enum values (tab name, dose type, integration type, permission type).
- Boolean flags (success, completed, granted).
- App / pod version, host bundle ID, OS version.

### NEVER allowed in payloads
- **Tokens**: `accessToken`, `refresh_token`, `firebase_token`, `oauth_token`, OAuth `code`, OAuth `state`, `Authorization` header value, `Set-Cookie` value.
- **Credentials**: passwords (real or placeholder), PINs, OTPs, `validationCode`, `email_confirmation_token`.
- **Contact PII**: `User.email`, `User.phoneNumber`, user name (any field), `User.identities`.
- **PHI / health data**: diary note bodies (text/audio/video transcript), food values (calories, carbs, mealType detail), dose values (units, type detail), survey answers, all `HealthSample` values, all `SensorKitSample` values, hot flash details.
- **Custom data**: `User.customData` schema unknown — treat as PHI by default.

### Redaction rule list
Case-insensitive substring match against:

```
password, pin, pinCode, pin_code,
token, accessToken, access_token, refreshToken, refresh_token,
firebase_token, firebaseToken,
secret, key, apiKey, api_key,
auth, authorization, authToken, auth_token,
cookie, setCookie, set_cookie, session,
otp, code, validationCode, validation_code,
email, phone, phoneNumber, phone_number,
firstName, lastName, fullName, name,
content, body, transcription,
mealType, calories, carbs,
units, doseType,
answer, answers
```

Matched key → value replaced with `"[redacted]"`.

### Code-review checklist for new emit-points

Every PR that adds a new `Telemetry.track(...)` call site must answer:
- [ ] Is every payload key in the **Always allowed** list above?
- [ ] If payload comes from an entity (User, DiaryNote, SurveyAnswer, HealthSample), is it routed through a typed `Redactor.<entity>` builder?
- [ ] If this hooks into a network endpoint that handles secrets, is `isSensitive: true` set on its `DefaultService` case?

---

## Adding new sinks

Future analytics integrations (Mixpanel, Amplitude, Datadog, …) implement `TelemetrySink`:

```swift
public protocol TelemetrySink: AnyObject {
    func receive(_ event: TelemetryEvent)
}
```

and register at startup:

```swift
Telemetry.register(MixpanelSink())
```

Sinks are independent — no event routing rules at the facade. Each sink decides (via the `category` and `level` fields on the event) which events it cares about.

---

## Operational notes

- **No measurable runtime cost when no Jam recording is active**: `JamLog.Logger` short-circuits on `.unreachable`. Verified via FUAM-3074.
- **`mirrorPrintToJam` flag (FUAM-3053)**: kept for now as an escape hatch. Once full Telemetry coverage exists across the framework, mark it deprecated and remove in a future major.
- **Crash logs**: `didCrashDuringPreviousExecution` mirroring into JamLog on next launch is a **stretch goal** filed as a follow-up under FUAM-3073.
