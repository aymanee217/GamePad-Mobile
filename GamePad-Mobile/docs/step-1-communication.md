# Step 1 – UDP Communication

## Goal

Establish real-time binary communication between the Flutter mobile app and the C# PC server over a local Wi-Fi network.

## Choices

| Decision              | Rationale                                                                 |
|-----------------------|---------------------------------------------------------------------------|
| UDP instead of TCP    | Lowest latency; no retransmission delays. Gaming tolerates packet loss.   |
| Binary instead of JSON| Smaller packets (3 bytes vs ~60+ bytes for JSON). Less CPU to parse.      |
| Riverpod              | Modern, testable state management for Flutter.                            |
| Clean Architecture    | Separation of concerns: core/network, core/protocol, features/controller. |

## Binary Protocol

Each packet is 3 bytes:

```
Byte 0: MessageType (0x01 = ButtonEvent)
Byte 1: ButtonId    (0x01 = A)
Byte 2: ButtonState (0x00 = Released, 0x01 = Pressed)
```

## Files Created

### Flutter (mobile/)

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point with Material 3 theme |
| `lib/core/config/app_config.dart` | Port, host, socket settings |
| `lib/core/network/udp_client.dart` | Raw UDP send via `RawDatagramSocket` |
| `lib/core/protocol/enums.dart` | `MessageType`, `ButtonId`, `ButtonState` enums |
| `lib/core/protocol/packet.dart` | Packet model + serialization |
| `lib/core/protocol/packet_encoder.dart` | High-level encode helpers |
| `lib/features/controller/providers/connection_provider.dart` | Riverpod state for connection |
| `lib/features/controller/providers/button_provider.dart` | Riverpod state for button events |
| `lib/features/controller/presentation/screens/controller_screen.dart` | Main UI |
| `lib/features/controller/presentation/widgets/game_button.dart` | Pressable button widget |

### C# (pc-server/)

| File | Purpose |
|------|---------|
| `Program.cs` | Entry point, wires server to console |
| `Core/Configuration.cs` | Port, buffer sizes |
| `Core/Logger.cs` | Thread-safe logger with ms timestamps |
| `Network/UdpServer.cs` | Async UDP listener with cancellation |
| `Protocol/Enums.cs` | MessageType, ButtonId, ButtonState enums |
| `Protocol/Packet.cs` | Decoded packet model |
| `Protocol/PacketDecoder.cs` | Byte array → Packet |

## Testing

1. Start the PC server: `cd pc-server && dotnet run`
2. Find the PC's local IP (`ipconfig`)
3. Update `AppConfig.defaultHost` with that IP
4. Run the Flutter app: `cd mobile && flutter run`
5. Tap **Connect**, then tap **A**

Expected server output:

```
[15:30:01.234] [INFO] UDP server listening on port 42420
[15:30:05.123] [RX] 3 bytes from 192.168.1.42:54321: 01 01 01
[15:30:05.123] [INFO] Decoded: ButtonEvent: A = Pressed
[15:30:05.456] [RX] 3 bytes from 192.168.1.42:54321: 01 01 00
[15:30:05.456] [INFO] Decoded: ButtonEvent: A = Released
```
