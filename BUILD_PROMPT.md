# Build Prompt: Nook — Audio-Only Voice Rooms MVP

You are a senior Flutter engineer and product-minded builder. Build a complete, runnable MVP called **Nook**: an audio-only social voice-room app. The feeling is a quiet third place — no feed, no followers, no video, no agenda. Someone opens a room, people pull up, and they talk.

Deliver production-quality code, not pseudocode. Every file must compile, and the app must run locally on macOS in Chrome without paid services.

---

## 1. Product requirements

### Core loop
1. User opens the app and enters a display name (no email/password).
2. User sees a list of open voice rooms.
3. User joins a room with one tap. Microphone connects automatically.
4. User can mute/unmute and leave.
5. User can create a room with a name and optional topic, and it appears in the list.

### Product principles
- Audio only. No video, no camera permissions, no avatars uploads.
- One screen, one decision: which room to enter.
- Dark, quiet, minimal. Less UI means less pressure to talk.
- No feed, no likes, no follower counts, no fake activity.
- Room names feel human: "Late Night Talks", "Study With Me", "Venting Circle".

### MVP scope (build all of these)
- Welcome/onboarding screen with display-name capture.
- Persistent display name and guest identity across launches.
- Home screen with room list, pull-to-refresh, empty state, and error state.
- Create-room bottom sheet with validation.
- Voice room screen with connection states, participant list, speaking indicator, mute toggle, leave button.
- Demo mode that works with zero external accounts.
- Supabase mode for auth + persistence.
- Supabase Edge Function that issues LiveKit tokens in production.
- Local Dart token server for development.
- Scripts to start LiveKit, the token server, and Flutter together.
- README with setup, architecture, and troubleshooting.

### Explicit non-goals
- No video, screen share, chat, DMs, profiles, social graph, or notifications in v1.
- No custom WebRTC implementation. Use LiveKit.
- No custom backend framework. Use Supabase.
- No fake participant counts or fabricated "live now" numbers.

---

## 2. Tech stack (use these exact choices)

| Layer | Choice | Version/notes |
| --- | --- | --- |
| App framework | Flutter | 3.47+ stable, Dart 3.13+ |
| Language | Dart | null safety, material 3 |
| Voice | LiveKit | `livekit_client: ^2.13.2`, server v1.13.x |
| Auth/DB | Supabase | `supabase_flutter: ^2.18.3`, Postgres, RLS |
| Token server (prod) | Supabase Edge Functions | Deno + `npm:livekit-server-sdk` |
| Token server (local) | Dart CLI | `dart:io` HttpServer + `crypto` HMAC-SHA256 |
| HTTP client | `http` | `^1.x` |
| Local persistence | `shared_preferences` | display name + guest identity |
| State management | Built-in | `StatefulWidget`, `ChangeNotifier`, `ListenableBuilder` |
| First target | Flutter web (Chrome) | localhost is a secure context for mic |
| Later targets | iOS, Android, macOS | platform folders generated |

Do not add Riverpod, Bloc, GetX, Firebase, Node, or Docker for the MVP. Keep the dependency surface small.

---

## 3. Architecture and file layout

```text
lib/
  main.dart                       init Supabase (if configured), restore session, runApp
  app.dart                        session routing between welcome and home
  config/app_config.dart          --dart-define configuration + hasSupabase
  models/nook_room.dart           immutable room model + fromMap
  data/rooms_repository.dart      abstract RoomsRepository
                                  DemoRoomsRepository (in-memory, seeded)
                                  SupabaseRoomsRepository (Postgres)
  services/token_service.dart     POST token endpoint -> { token, url }
  state/session.dart              Session value object + SessionStore
  screens/welcome_screen.dart     name capture, anonymous sign-in
  screens/home_screen.dart        room list, refresh, create sheet, menu
  screens/voice_room_screen.dart  LiveKit connect, participants, controls
  theme/nook_theme.dart           colors + ThemeData
  widgets/room_card.dart          room list card
tool/
  dev_token_server.dart           local JWT issuer on :8787
scripts/
  dev.sh                          start LiveKit + token server + flutter web
  start_livekit.sh                start LiveKit dev server only
supabase/
  schema.sql                      rooms table, indexes, RLS policies
  functions/livekit-token/index.ts production token endpoint
test/
  nook_room_test.dart             model unit tests
```

### Data flow
- `main()` initializes Supabase only if `SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided.
- `SessionStore.restore()` returns a session if a name and identity are persisted. Supabase anonymous sessions are restored by the SDK.
- `NookApp` chooses the repository once: Supabase if configured, otherwise demo.
- `HomeScreen` reads rooms from the repository.
- `VoiceRoomScreen` requests a token, connects to LiveKit, then enables the mic.
- LiveKit `Room` is a `ChangeNotifier`; rebuild the participant stage from its events.

---

## 4. Configuration

Use compile-time `--dart-define` values with safe defaults:

| Define | Default | Meaning |
| --- | --- | --- |
| `SUPABASE_URL` | empty | Supabase project URL |
| `SUPABASE_ANON_KEY` | empty | Supabase publishable/anon key |
| `LIVEKIT_URL` | `ws://127.0.0.1:7880` | LiveKit websocket URL |
| `TOKEN_ENDPOINT` | `http://127.0.0.1:8787/token` | Token issuer |

`hasSupabase` is true only when both Supabase values are non-empty. In `Supabase.initialize`, use `publishableKey` (not the deprecated `anonKey`).

---

## 5. Data model and RLS

```sql
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  topic text not null default '' check (char_length(topic) <= 80),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;

create policy "rooms are readable by authenticated users"
  on public.rooms for select to authenticated using (true);

create policy "authenticated users can create rooms"
  on public.rooms for insert to authenticated
  with check (auth.uid() = created_by);

create index if not exists rooms_created_at_idx
  on public.rooms (created_at desc);
```

The room `id` doubles as the LiveKit room name. Do not expose room rows to `anon`; anonymous sign-in produces the `authenticated` role.

---

## 6. Auth and session

- If Supabase is configured, use **anonymous sign-in** (`signInAnonymously`). Document that the Supabase project must enable Authentication → Providers → Anonymous.
- If Supabase is not configured, demo mode generates a persistent guest identity like `guest-a1b2c3`.
- Persist `nook.displayName` and `nook.identity` in `shared_preferences`.
- "Change name" clears the stored name, signs out of Supabase, and returns to welcome.
- Show a friendly error if anonymous sign-ins are disabled.

---

## 7. LiveKit token flow

### Local development token server (`tool/dev_token_server.dart`)
- Bind `127.0.0.1:8787`.
- `GET /health` returns `{"ok":true}`.
- `POST /token` accepts `{ "room": "...", "identity": "...", "name": "..." }`.
- Validate `room` and `identity` are non-empty.
- Build an HS256 JWT manually with `package:crypto`:
  - header: `{"alg":"HS256","typ":"JWT"}`
  - payload: `iss` = API key, `sub` = identity, `name`, `nbf` = now-10, `exp` = now+6h,
    `video` grant: `{ room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true }`
  - base64url without padding; HMAC-SHA256 with the API secret.
- Return `{ "token": "...", "url": "ws://127.0.0.1:7880" }`.
- Add permissive CORS (`Access-Control-Allow-Origin: *`, allow `Content-Type`, `Authorization`, methods `POST, GET, OPTIONS`) and handle `OPTIONS` with 204.
- Default credentials `devkey` / `secret` match `livekit-server --dev`; allow `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL`, `PORT` overrides.

### Production edge function (`supabase/functions/livekit-token/index.ts`)
- Deno + `AccessToken` from `npm:livekit-server-sdk@2.13.0`.
- Read `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_URL` from secrets.
- Require `Authorization: Bearer <supabase access token>` and call `auth.getUser()`.
- Accept `{ room, name }`; use the authenticated user id as the LiveKit identity.
- Issue a 6-hour token with the same video grant.
- Return `{ token, url }`. Handle CORS and `OPTIONS`.
- Never ship the LiveKit secret in the app.

---

## 8. Screens and UX

### Welcome
- Dark background `#09090F`, centered content, max width 420.
- Rounded-square logo tile with lowercase `n` in lavender.
- Wordmark `nook` (56px, weight 700, letter-spacing -2).
- Tagline: "A quiet corner to talk. Pull up, no agenda needed."
- Text field label: "What should people call you?" with hint "First name or nickname".
- Primary button: "Enter Nook".
- Validation: at least 2 characters. Inline error text.
- Footer: "No feed. No followers. Just a room and a voice."
- Busy state shows a small spinner inside the button.

### Home
- App bar: `nook` wordmark plus a small "voice rooms" pill; overflow menu shows the current name and "Change name".
- Greeting: "Hey, <first name>" (30px) and "Find a quiet corner and pull up."
- Demo mode banner explaining local rooms and local LiveKit.
- Section label "Rooms open now", with a small loading spinner.
- Room cards: rounded 24, surface `#15151F`, 54px initial tile, name, 1-2 line topic, lavender "Join" pill.
- Floating "New room" extended FAB.
- Pull-to-refresh. Empty state: "No rooms yet. Open the first one and see who shows up."
- Error state with a "Try again" action.

### Create room sheet
- Modal bottom sheet, rounded top corners.
- Fields: room name (required, max 40), topic (optional, max 80).
- Button: "Create room". On success, refresh the list.
- Keyboard-aware bottom padding via `MediaQuery.viewInsetsOf(context).bottom`.

### Voice room
- App bar: room name and topic.
- Status pill: "Connecting…", "You are here alone for now", "N people in this room", or "Not connected" with red dot.
- Participant stage: centered `Wrap` of circular tiles, 86px, initial letter, name, "(you)" suffix for local user.
- Speaking state: 3px green `#7BE3B0` border + soft green glow, animated 200ms.
- Local muted state: small mic-off icon next to the name.
- Controls: large circular mute/unmute button and a red leave button, each with a label underneath.
- Hint: "Headphones recommended while testing on one machine."
- On join error show a card with the message, "Local dev: ./scripts/dev.sh", and "Try again".
- Leaving disconnects the room and disposes it. Dispose must not leak listeners.

### Behavior rules
- Request token, connect to LiveKit, then enable the microphone. A mic failure must not tear down a successful connection; show a snackbar instead.
- Toggling mute calls `localParticipant.setMicrophoneEnabled(next)`.
- Rebuild participants from `room.localParticipant` plus `room.remoteParticipants.values`.
- Use `Room(roomOptions: RoomOptions(adaptiveStream: true, dynacast: true))`.
- Always remove the room listener and disconnect/dispose on teardown.

---

## 9. Design system

| Token | Value |
| --- | --- |
| Background | `#09090F` |
| Surface | `#15151F` |
| Surface high | `#1F1F2E` |
| Accent | `#B9A6FF` |
| Accent soft | `#2A2440` |
| Text | `#F2F0FF` |
| Muted | `#9C98B4` |
| Live/speaking | `#7BE3B0` |
| Danger | `#FF7A8B` |
| On accent | `#161022` |

Material 3 dark theme, transparent app bar, 16px input radius, 24px card radius, 999px pills, 54px primary button height. System font. Use `withValues(alpha:)`, not deprecated `withOpacity`.

---

## 10. Local development

### Check tools first
Provide `scripts/setup.sh`, which checks Homebrew, Flutter/Dart, Google Chrome, Go, `livekit-server`, `git`, `curl`, and `lsof`. It must ask before installing anything. If the user declines an install, print the exact manual command and exit non-zero so the build stops. Support `--check`, `--yes`, `--build`, and `--quiet`.

### Install manually (if preferred)
```bash
brew install --cask flutter
brew install cocoapods
brew install --cask google-chrome
```

### Build the LiveKit server (macOS arm64, no Docker)
```bash
git clone --depth 1 --branch v1.13.11 https://github.com/livekit/livekit.git
cd livekit
go build -o ~/.local/bin/livekit-server ./cmd/server
```

### Run everything
```bash
./scripts/dev.sh
```

This starts:
- LiveKit dev server on `ws://127.0.0.1:7880` (log `/tmp/nook-livekit.log`)
- Dart token server on `http://127.0.0.1:8787` (log `/tmp/nook-token.log`)
- Flutter web app on `http://localhost:5173` via `flutter run -d chrome --web-port=5173`

If `flutter run -d chrome` cannot launch a browser, use:
```bash
flutter run -d web-server --web-port=5173 --web-hostname=127.0.0.1
```
and open `http://localhost:5173` manually.

### Test with two people
Open two Chrome windows (one incognito), use different names, join the same room. Use headphones to avoid feedback.

### Verify without a browser
```bash
curl -s http://127.0.0.1:7880
curl -s http://127.0.0.1:8787/health
curl -s -X POST http://127.0.0.1:8787/token \
  -H 'Content-Type: application/json' \
  -d '{"room":"demo-study","identity":"guest-abc123","name":"Aditi"}'
```

---

## 11. Acceptance criteria

1. `flutter analyze` reports zero issues.
2. `flutter test` passes.
3. `flutter build web` succeeds.
4. The app boots with no Supabase configuration and enters demo mode.
5. A name survives app reload.
6. The four seeded demo rooms appear.
7. Creating a room adds it to the top of the list.
8. Joining a room obtains a token and connects to LiveKit.
9. Two browser windows with different identities hear each other in the same room.
10. Mute stops publishing audio; unmute resumes it.
11. Leaving disconnects and returns to the room list.
12. Stopping LiveKit or the token server produces a readable error with a `./scripts/dev.sh` hint, not a crash.
13. No API secret is present in client code or committed files.
14. Supabase mode works after running `schema.sql`, enabling anonymous sign-ins, and deploying the edge function.

---

## 12. Deliverables

Produce:
- Full Flutter project with the file layout above.
- `pubspec.yaml` with the exact dependencies.
- Local token server and shell scripts, executable.
- Supabase schema and edge function.
- Unit tests for the room model.
- README covering setup, config, architecture, iOS/Android notes, and troubleshooting.
- This build prompt as documentation.

## 13. Implementation order

1. Scaffold Flutter (`flutter create --org ... --project-name nook`).
2. Add dependencies.
3. Build config, model, theme.
4. Build session store and welcome flow.
5. Build repositories and home screen.
6. Build create-room sheet.
7. Build the voice room screen against LiveKit.
8. Add the local token server and run the stack.
9. Add Supabase schema and edge function.
10. Run analyze, tests, web build, and a two-tab voice test.

## 14. Hard constraints

- No secrets in the client. Token issuance is always server-side.
- No custom WebRTC/SFU code. LiveKit handles transport.
- No fake data, no fake participant counts, no fake "live" badges.
- Do not silently swallow microphone or connection errors; surface actionable messages.
- Keep the MVP small: one repo, one app, one voice feature done well.

Start by creating the project, then implement every file above, then run the acceptance checks and report the results.
