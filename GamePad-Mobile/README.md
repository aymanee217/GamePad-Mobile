# GamePad Mobile

Transform your Android/iPhone into a low-latency game controller for Windows.

## Architecture

```
GamePad-Mobile/
├── mobile/           # Flutter app (Android + iOS)
│   └── lib/
│       ├── core/           # Shared infrastructure
│       │   ├── config/     # App configuration
│       │   ├── network/    # UDP client
│       │   └── protocol/   # Binary packet encoder/decoder
│       └── features/
│           └── controller/ # Controller UI
│               ├── providers/    # Riverpod state
│               └── presentation/ # Screens & widgets
├── pc-server/        # C# .NET 9 server
│   ├── Core/         # Config, Logger
│   ├── Network/      # UDP server
│   └── Protocol/     # Binary packet decoder
├── protocol/         # Binary protocol specification
└── docs/             # Documentation
```

## Quick Start

### Prerequisites

- Flutter SDK 3.7+
- .NET 9 SDK
- Android/iOS device + PC on the same Wi-Fi network

### Run the PC Server

```bash
cd pc-server
dotnet run
```

### Run the Mobile App

```bash
cd mobile
flutter run
```

## Roadmap

| Step | Feature                    |
|------|----------------------------|
| 1    | UDP communication (this)   |
| 2    | Auto-discovery of PC       |
| 3    | Button layout              |
| 4    | Analog joysticks           |
| 5    | Virtual Xbox controller    |
| 6    | Vibration feedback         |
| 7    | Custom profiles            |
| 8    | Macros                     |
| 9    | USB connection             |
| 10   | Bluetooth connection       |

## License

MIT
