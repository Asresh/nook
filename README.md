# Nook

A quiet corner to talk. Nook is an audio-only voice room app built with Flutter and LiveKit.

This is the MVP: enter a name, browse open rooms, open your own, and talk. No feed, no followers, no video.

Want to rebuild or extend it? See [`BUILD_PROMPT.md`](BUILD_PROMPT.md) for a complete, copy-pasteable build prompt covering the product spec, stack, architecture, data model, and acceptance criteria.

## What is in the box

- Flutter app (web, iOS, Android, macOS targets generated)
- LiveKit voice rooms with mute/unmute and speaking indicators
- Demo mode: local room list, no account needed
- Supabase mode: anonymous auth, Postgres-backed room list, RLS in `supabase/schema.sql`
- Local dev token server in Dart (`tool/dev_token_server.dart`)
- Production token endpoint as a Supabase Edge Function (`supabase/functions/livekit-token`)

## Run it locally (demo mode)

Prerequisites installed on this machine:

- Flutter 3.47+
- Chrome
- `livekit-server` at `~/.local/bin/livekit-server`
- Dart (ships with Flutter)

One command:

```bash
./scripts/dev.sh
```

That starts:

| Service | URL |
| --- | --- |
| LiveKit dev server | `ws://127.0.0.1:7880` |
| Token server | `http://127.0.0.1:8787` |
| Flutter app | `http://localhost:5173` |

Then open the app in Chrome, enter a name, and join a room. To test two people,
open a second Chrome window (or an incognito window) with `http://localhost:5173`,
enter a different name, and join the same room. Use headphones to avoid feedback.

The LiveKit dev server uses `devkey` / `secret`, which only the local token
server knows. Tokens are generated on demand and expire after 6 hours.

## Configuration

Defaults work for local demo mode. Override with `--dart-define`:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-key \
  --dart-define=LIVEKIT_URL=wss://your-livekit-host \
  --dart-define=TOKEN_ENDPOINT=https://your-project.supabase.co/functions/v1/livekit-token
```

If `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set, Nook switches from demo mode
to Supabase mode automatically.

## Supabase mode

1. Create a Supabase project.
2. Enable **Authentication → Providers → Anonymous sign-ins**.
3. Run `supabase/schema.sql` in the SQL editor.
4. Deploy the token function:

```bash
supabase functions deploy livekit-token
supabase secrets set \
  LIVEKIT_API_KEY=... \
  LIVEKIT_API_SECRET=... \
  LIVEKIT_URL=wss://...
```

5. Run the app with the `--dart-define` values above.

The LiveKit API secret must stay server-side. Never ship it in the Flutter app.

## Voice rooms

Rooms are identified by their database ID, which is also the LiveKit room name.
Joining a room:

1. The app asks the token endpoint for a short-lived JWT.
2. It connects to LiveKit with that token.
3. The microphone is enabled after connecting. Mute/unmute is instant.

The token endpoint returns `{ "token": "...", "url": "wss://..." }`.

## Local LiveKit server

The binary was compiled from `livekit/livekit` v1.13.11 with Go. To rebuild:

```bash
git clone --depth 1 --branch v1.13.11 https://github.com/livekit/livekit.git
cd livekit
go build -o ~/.local/bin/livekit-server ./cmd/server
```

Start it manually with:

```bash
./scripts/start_livekit.sh
```

## Project layout

```text
lib/
  app.dart                     app shell and session routing
  main.dart                    Supabase init + session restore
  config/app_config.dart       --dart-define configuration
  data/rooms_repository.dart   demo + Supabase room repositories
  models/nook_room.dart        room model
  screens/                     welcome, home, voice room
  services/token_service.dart  LiveKit token client
  state/session.dart           anonymous identity + display name
  theme/nook_theme.dart        dark lavender theme
  widgets/room_card.dart       room list card
tool/dev_token_server.dart     local JWT issuer for LiveKit dev mode
supabase/schema.sql            rooms table + RLS
supabase/functions/             production token endpoint
scripts/dev.sh                 start the whole local stack
```

## iOS / Android

The platform folders are generated, but this machine does not have a full Xcode
install or Android SDK yet.

- iOS: install Xcode from the App Store, then
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`,
  `sudo xcodebuild -runFirstLaunch`, and `sudo gem install cocoapods` (or use
  the Homebrew CocoaPods already installed). Then `flutter run -d ios`.
- Android: install Android Studio and the SDK, then `flutter run -d android`.
- Physical devices cannot reach `127.0.0.1`; point `LIVEKIT_URL` and
  `TOKEN_ENDPOINT` at your laptop's LAN IP or a hosted deployment. Browsers on
  phones also require HTTPS for microphone access, so use LiveKit Cloud or a
  tunnel for device testing.

## Next steps

- Push-to-talk and room-level mute-all
- Participant counts from LiveKit webhooks or room metadata
- Reporting/blocking and room expiry
- LiveKit Cloud for production voice (free tier)
- Push notifications for "someone opened a room"
