# M0LTE.Radio.Tait

> Tait TM8100/TM8200 mobile-radio control over CCDI: RSSI, hardware carrier-sense, PTT, telemetry, and a radio-native side channel.

A [`M0LTE.Radio`](https://www.nuget.org/packages/M0LTE.Radio) `IRadioControl` implementation for Tait TM8100/TM8200 radios over CCDI, the Computer-Controlled Data Interface: the radio's serial command protocol.

## Install
```sh
dotnet add package M0LTE.Radio.Tait
```

## What it surfaces that a bare KISS modem cannot

- **RSSI in dBm** (CCTM queries 063/064, 0.1 dB resolution).
- **Hardware carrier-sense** - unsolicited PROGRESS "receiver busy / not busy" messages become `CarrierSenseChanged` events + a `ChannelBusy` property (a true RF-level DCD).
- **Transmitter keying** (`SetTransmitterAsync`) - CCDI-forced TX ignores the radio's TX timer, so the driver unkeys on dispose if you left it keyed through it.
- **Telemetry + health** - PA temperature (CCTM 047), forward/reverse power detector readings (CCTM 318/319, an antenna-health proxy while transmitting), and a periodic **`TaitRadioHealthMonitor`** that trends them: idle-offset-corrected fwd/rev + ratio (a TREND, never VSWR - the detectors are raw √P-scaled millivolts per Tait's service docs), typed sample events + rolling min/median/max summaries.
- **Identity** - model/tier, CCDI version, serial number, firmware/hardware version inventory.
- **An escape hatch** (`TransactRawAsync`) for CCDI commands the driver doesn't model yet - framing and checksumming handled, responses returned decoded.
- **A station-control view** (`TaitRigControl`) - re-presents the radio through the [`M0LTE.Rig`](https://www.nuget.org/packages/M0LTE.Rig) `IRigControl` abstraction (the same seam the hamlib/rigctld and flrig backends implement), advertising the slice CCDI can honestly serve: PTT set/get and a relative RF-power meter (the CCTM 318 forward detector over its full scale). Frequency, mode, SWR and watts are deliberately unadvertised - the tuned frequency isn't CCDI-readable, the radio has no mode concept, and the power detectors are raw √P-scaled millivolts, not calibrated units. Cross-backend rig consumers feature-probe `RigCapabilities` and get exactly what's real.

## Usage
```csharp
await using var radio = TaitCcdiRadio.Open("/dev/ttyUSB0"); // 28800 8N1 default
await radio.SetProgressMessagesAsync(true);                 // per-session: enables DCD events

var id = await radio.QueryIdentityAsync();                  // e.g. "Tait TM8110", serial, versions
float rssi = await radio.ReadRssiDbmAsync();                // e.g. -90.3
radio.CarrierSenseChanged += (_, e) => Console.WriteLine($"DCD {(e.Busy ? "up" : "down")} at {e.At:O}");
```

The radio must be programmed with its data port in **Command mode** (the power-up state) at the matching baud rate.

`TaitCcdiRadio.Open` also takes an `ISerialIo` instead of a port name, so you can drive the radio over a byte pipe this package does not model - a serial-to-TCP bridge, say ([`TcpSerialIo`](https://www.nuget.org/packages/M0LTE.Radio.Tait) is supplied) - or script one in a test and exercise the whole transaction engine and unsolicited-message demux with no hardware attached.

## TNC-less AX.25 over the radio's own FFSK modem

The radio's Transparent mode turns its internal FFSK modem into an 8-bit-clean byte pipe, which is enough to carry AX.25 with no external TNC at all. That transport is AX.25-specific, so it does not live here: it ships as [`Packet.Ax25.Radio.Tait`](https://www.nuget.org/packages/Packet.Ax25.Radio.Tait), which builds on this package.

The trade-off it makes is worth knowing before you reach for it: one device and no audio wiring, but no signal telemetry, because while the CCDI channel is acting as a byte pipe the RSSI, SNR, noise-floor and DCD surfaces described above are unavailable.

## Beyond telemetry

The driver models the rest of the documented surface: channel report/change (`QueryCurrentChannelAsync` / `GoToChannelAsync`), CANCEL / DIAL, and **SDM short-data messages** - radio-to-radio, no TNC: plain 32-character (`SendSdmAsync`) and extended 128-character (`SendExtendedSdmAsync`), requiring SDMs enabled in the radio's programming. `TaitSdmSideChannel` exposes SDMs as an `M0LTE.Radio.IRadioSideChannel`, the mode-agnostic coordination plane a tuning or mode-negotiation stack can ride. Also: display query, Transparent mode (the radio's own FFSK/THSD modem as a byte pipe), a keep-alive **watchdog** (`ConnectionState` + events; probes on link silence, self-heals on recovery), **port auto-detection** (`TaitRadioPortDiscovery` - probes candidate ports with a MODEL query and identifies radios by CCDI serial number), and the whole **CCR mode** (`TaitCcrSession`, TM8100 only): run-time RX/TX frequency in Hz, TX power, bandwidth, CTCSS/DCS, Selcall encode/decode events, volume, and the pulse ping.

### ⚠ SDM delivery receipts are unreliable for close bidirectional traffic

The over-air SDM **delivery receipt** (CCDI PROGRESS `1D`, para `1`=ack / `0`=nak) is not a
dependable delivery signal when two radios exchange SDMs back-and-forth within a few seconds - as a
coordination protocol does. Bench-characterised on 2× TM8110 (CCDI 03.02): a radio captures its
send's receipt **only if** it has not transmitted an SDM auto-acknowledge since its previous send
**and** ≥~9 s have elapsed since its last auto-ack; otherwise it reports NAK after the ~6 s timeout.
Crucially the **SDM payload is delivered every time regardless** - only the receipt is lost. Full
characterisation and proof: [`docs/research/tm8110-sdm-autoack-refractory.md`](https://github.com/packet-net/packet.net/blob/main/docs/research/tm8110-sdm-autoack-refractory.md).

Guidance: treat the receipt as an **optimistic fast-path only** - never fail delivery on its
absence. For reliability, confirm at the application layer (the peer's reply). Auto-ack itself is a
**codeplug (programming-application) setting, not a runtime toggle** - there is no `f`-command to
disable it; a radio you own can have "SDM Auto Acknowledge" turned off in its codeplug to remove the
effect and save the ack airtime, but you cannot assume that on radios you don't program.

## CCR-over-SDM ⚠ experimental / unsafe

`UnsafeSendCcrOverSdmAsync` transmits a CCR command *into another radio* over the air - remote control that can retune, re-power, or key the target, with **no consent handshake in the protocol**. It is `[Experimental]` (`PKTTAIT001`) and carries the `Unsafe` prefix deliberately: a radio not already in CCR mode simply ignores it (immune), but any real deployment needs an application-layer consent/auth gate first - keep it to bench tooling and radios you own. See the [CCDI spike doc](https://github.com/packet-net/packet.net/blob/main/docs/research/tait-ccdi-spike.md).

## See also
- [`M0LTE.Radio`](https://www.nuget.org/packages/M0LTE.Radio) - the `IRadioControl` contract this implements
- [`M0LTE.Rig`](https://www.nuget.org/packages/M0LTE.Rig) - the CAT seam `TaitRigControl` presents the radio through
- [`Packet.Ax25.Radio.Tait`](https://www.nuget.org/packages/Packet.Ax25.Radio.Tait) - AX.25 over the radio's Transparent-mode FFSK pipe
- [`Packet.Tune.Core`](https://www.nuget.org/packages/Packet.Tune.Core) - link-tuning + mode coordination over the SDM side channel

Verified on hardware: 2× TM8110 (`TMAB12-B100`, CCDI 03.02, firmware 02.18.00.00). On that firmware the CCDI-side TX-power set (FUNCTION 0/7) answers "unsupported command" - but the CCR-mode power command works, so power control lives on `TaitCcrSession`.

Status: **experimental**, spike-born. Protocol reference: Tait MMA-00038-06 "TM8100/TM8200 CCDI Protocol Manual".

---
*AGPL-3.0-licensed.*
