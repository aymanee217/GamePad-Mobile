# Step 3 – Auto-discovery

## Goal

Eliminate manual IP entry: the mobile app finds the PC server automatically.

## How it works

```
Mobile                          PC
  │                              │
  │── DISCOVERY (broadcast) ────>│
  │                              │
  │<── DISCOVERY_RESP ──────────│
  │                              │
  │  (IP saved to                │
  │   SharedPreferences)         │
  │                              │
  │── connect (known IP) ───────>│
```

1. Mobile sends a `DISCOVERY` (0x02) packet to UDP broadcast `255.255.255.255:42420`
2. PC receives it and replies with `DISCOVERY_RESP` (0x03) containing the machine name + protocol version
3. Mobile saves the discovered IP to `SharedPreferences`
4. Mobile connects directly on subsequent attempts (auto-reconnect)

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `mobile/lib/core/service/discovery_service.dart` | Broadcast DISCOVERY, listen for DISCOVERY_RESP, parse response |

### Modified files (C#)

| File | Change |
|------|--------|
| `Network/UdpServer.cs` | New `HandleDiscovery()` method: responds with machine name + version |

### Modified files (Flutter)

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `shared_preferences: ^2.3.4` |
| `lib/core/config/app_config.dart` | Added discovery timeout, retries, SharedPreference keys, autoReconnect flag |
| `lib/core/protocol/packet_encoder.dart` | Added `encodeDiscovery()` |
| `lib/features/controller/providers/connection_provider.dart` | Added `ConnectionPhase` enum, discovery flow, `tryAutoReconnect()`, persistence with SharedPreferences |
| `lib/features/controller/presentation/screens/controller_screen.dart` | Updated UI to show all phases: disconnected, discovering, discovered, connecting, connected, failed |

## Connection phases

| Phase | UI state |
|-------|----------|
| `disconnected` | Red "Disconnected" + "Discover & Connect" button |
| `discovering` | Spinner + "Scanning..." |
| `discovered` | "Found PC-Name" + "Connect" button |
| `connecting` | Spinner + "Connecting..." |
| `connected` | Green "Connected to PC-Name" + "Disconnect" button |
| `failed` | Red "No server found" + "Retry" button |

## Persistence

- `SharedPreferences` key `discovered_host` stores the last discovered IP
- `SharedPreferences` key `discovered_port` stores the port
- On app start, `tryAutoReconnect()` reads saved values and connects automatically
