# GamePad Mobile Protocol

## Binary Protocol Specification v2.0

### General

- **Transport:** UDP
- **Format:** Binary (big-endian)
- **Default port:** 42_420
- **Max packet size:** 512 bytes
- **Protocol version:** 0x01

### Packet Structure v2

```
┌──────────────┬──────────────────────────────────────┐
│ Byte offset  │  Field                               │
├──────────────┼──────────────────────────────────────┤
│ 0            │  ProtocolVersion (uint8)              │
│ 1            │  MessageType (uint8)                  │
│ 2..3         │  SequenceNumber (uint16 BE)           │
│ 4..7         │  Timestamp (uint32 BE)                │
│ 8..n-3       │  Payload (depends on type)            │
│ n-2..n-1     │  CRC16 (uint16 BE)                    │
└──────────────┴──────────────────────────────────────┘
```

**Header: 8 bytes | CRC16: 2 bytes | Minimum total: 10 bytes**

### Fields

| Field            | Size | Description                                    |
|------------------|------|------------------------------------------------|
| ProtocolVersion  | 1    | Current version: 0x01                          |
| MessageType      | 1    | See Message Types                              |
| SequenceNumber   | 2    | Monotonic counter (per-sender), wraps at 65535 |
| Timestamp        | 4    | Milliseconds since session start               |
| Payload          | var  | Message-specific data                          |
| CRC16            | 2    | CRC16-CCITT over header + payload              |

### Message Types

| Value | Name          | Description          | Payload size |
|-------|---------------|----------------------|-------------|
| 0x01  | BUTTON_EVENT  | Button press/release | 2 bytes     |
| 0x02  | DISCOVERY     | Auto-discovery       | 0 bytes     |
| 0x03  | DISCOVERY_RESP| Discovery response   | 4+ bytes    |
| 0x04  | AXIS_EVENT    | Analog axis          | 5 bytes     |
| 0x05  | VIBRATION     | Vibration command    | 2+ bytes    |
| 0x06  | MACRO_EVENT   | Macro trigger        | 1+ bytes    |
| 0x07  | PING          | Latency measurement  | 0 bytes     |
| 0x08  | PONG          | Latency response     | 0 bytes     |
| 0x09  | TRIGGER_EVENT | Analog trigger       | 2 bytes     |

### BUTTON_EVENT Payload (0x01)

```
┌──────────┬──────────────┬───────────────────────────┐
│ Byte     │ Field        │ Values                    │
├──────────┼──────────────┼───────────────────────────┤
│ 0        │ ButtonId     │ See Button IDs            │
│ 1        │ ButtonState  │ 0x00 = Released / 0x01 = Pressed │
└──────────┴──────────────┴───────────────────────────┘
```

### DISCOVERY Payload (0x02)

No payload (header only). Sent as UDP broadcast to `255.255.255.255:42420`.

### DISCOVERY_RESP Payload (0x03)

```
┌──────────┬──────────────────────────────────────────┐
│ Byte     │ Field                                    │
├──────────┼──────────────────────────────────────────┤
│ 0        │ NameLength (uint8)                       │
│ 1..N     │ Server name (UTF-8, N = NameLength)      │
│ N+1      │ ProtocolVersion (uint8)                  │
└──────────┴──────────────────────────────────────────┘
```

### CRC16-CCITT

- Polynomial: `0x1021`
- Initial value: `0xFFFF`
- No XOR out
- Computed over: header (bytes 0-7) + payload (bytes 8..n-3)
- Storage: big-endian at the end of the packet

### Sequence Number

- Starts at 0, incremented for each sent packet
- Wraps at 65535 back to 0
- The receiver detects gaps to estimate packet loss

### Timestamp

- Milliseconds elapsed since the sender started the session
- Resets on app restart / new connection
- Used by the receiver to calculate one-way latency (requires time sync) or jitter

### TRIGGER_EVENT Payload (0x09)

```
┌──────────┬──────────────────────────────────────┐
│ Byte     │ Field                                │
├──────────┼──────────────────────────────────────┤
│ 0        │ TriggerId (0x01 = L2, 0x02 = R2)    │
│ 1        │ Value (uint8, 0–255)                 │
└──────────┴──────────────────────────────────────┘
```

### Performance Metrics (derived on receiver)

| Metric        | How                                          |
|---------------|----------------------------------------------|
| Packet rate   | Packets received per second (rolling 1s)     |
| Bitrate       | Bytes × 8 per second (rolling 1s)           |
| Loss rate     | Gaps in SequenceNumber / total expected      |
| Jitter        | Std dev of inter-arrival times               |

### Button IDs

| ID    | Button      |
|-------|-------------|
| 0x01  | A           |
| 0x02  | B           |
| 0x03  | X           |
| 0x04  | Y           |
| 0x05  | LB          |
| 0x06  | RB          |
| 0x07  | LT          |
| 0x08  | RT          |
| 0x09  | Start       |
| 0x0A  | Select      |
| 0x0B  | Guide       |
| 0x0C  | DPad_Up     |
| 0x0D  | DPad_Down   |
| 0x0E  | DPad_Left   |
| 0x0F  | DPad_Right  |
| 0x10  | L3          |
| 0x11  | R3          |
