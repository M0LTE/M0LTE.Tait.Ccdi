# M0LTE.Radio

> What a control channel to the radio *behind* the modem gives you, expressed protocol-neutrally.

A data modem hands you demodulated frames and nothing else. A radio with a serial control channel (Tait CCDI, Yaesu CAT, ICOM CI-V, ...) can also tell you how strong the signal was, tell you the moment the channel goes busy, and key its own transmitter. This package is the driver-neutral seam that surfaces those, and the base contract concrete drivers implement (see [`M0LTE.Radio.Tait`](https://www.nuget.org/packages/M0LTE.Radio.Tait)). Applications code against the interfaces here.

## Install
```sh
dotnet add package M0LTE.Radio
```

## What a control channel gives you that the modem can't

- **RSSI in dBm** - attribute signal strength, and SNR against a tracked noise floor, to what you receive.
- **Hardware carrier-sense (DCD)** - the channel is busy *now*, typically 0.5-1 s before a modem finishes demodulating the frame on air. That head start is exactly what a medium-access gate wants.
- **Transmitter keying** - PTT under software control, independent of the modem's PTT line.
- **A radio-native side channel** - small control datagrams that bypass the audio modem entirely, so they keep working while the link they sit beside is being reconfigured.

## Types

- **`IRadioControl`** - the capability-probed contract: `ReadRssiDbmAsync`, `SetTransmitterAsync`, `ChannelBusy` + `CarrierSenseChanged`, and a `RadioCapabilities` flags enum. Drivers advertise only what their radio and firmware actually support. Reserved flags (channel change, frequency, TX power) exist so richer radios can be described before the interface grows those members.
- **`IRadioSideChannel`** - a small-datagram control plane the radio itself provides (Tait SDM over the radios' internal FFSK modem, for instance): `SendAsync` / `ReadBufferedAsync` for short payloads, with over-air delivery receipts and a `MaxPayloadLength` budget. Because it bypasses the audio modem it is agnostic to mode, deviation and channel width, which makes it the natural place to renegotiate the very link it sits beside. Drivers advertise the machinery via `RadioCapabilities.SideChannel`; consumers must still probe that it is enabled in the radio's programming before gating features on it.
- **`RigRadioControl`** - the rig-to-radio bridge: presents a CAT rig ([`M0LTE.Rig`](https://www.nuget.org/packages/M0LTE.Rig)'s `IRigControl`, so hamlib `rigctld` or flrig) through this package's `IRadioControl`. Capabilities map at construction (`DcdRead -> CarrierSense`, `SignalStrengthRead -> RssiRead`, `PttSet -> TransmitterControl`); a rig offering none of the three is rejected.

  CAT backends are poll-only, so carrier-sense edges are *synthesised* by an owned DCD poll loop (100 ms by default). Edges shorter than the poll interval are invisible, which is coarser than a true push source, and you should size your expectations accordingly. A failed read fails open (`ChannelBusy = null`) and backs off to a slower retry cadence until the backend self-heals. `ownsRig: true` hands the rig's lifetime to the adapter; the default `false` leaves it with the caller, and dispose best-effort unkeys anything the adapter left keyed.

## Usage

```csharp
using M0LTE.Radio;
using M0LTE.Radio.Tait;

await using var radio = TaitCcdiRadio.Open("/dev/ttyUSB0");
await radio.SetProgressMessagesAsync(true);   // turn on DCD events

radio.CarrierSenseChanged += (_, e) => Console.WriteLine($"channel {(e.Busy ? "busy" : "clear")} at {e.At:O}");

if (radio.Capabilities.HasFlag(RadioCapabilities.RssiRead))
{
    Console.WriteLine($"{await radio.ReadRssiDbmAsync():F1} dBm");
}
```

Or the same seam over a CAT rig:

```csharp
using M0LTE.Rig.Hamlib;

await using var rig = await RigctldRig.ConnectAsync(new RigctldRigOptions { Host = "localhost" });
await using var radio = new RigRadioControl(rig, ownsRig: true);
```

## See also

- [`M0LTE.Radio.Tait`](https://www.nuget.org/packages/M0LTE.Radio.Tait) - the Tait TM8100/TM8200 CCDI implementation of this contract
- [`M0LTE.Rig`](https://www.nuget.org/packages/M0LTE.Rig) - the station-control (CAT) seam `RigRadioControl` bridges from
- [`Packet.Ax25.Radio`](https://www.nuget.org/packages/Packet.Ax25.Radio) - AX.25 adapters over this contract: per-frame RSSI tagging, and DCD into the AX.25 CSMA gate

Status: **shape confirmed.** The `IRadioControl` subset {RSSI-get, busy-get, PTT-set} survived four implementations without an interface change. The reserved flags (channel, frequency, TX power) stay reserved: QSY is station control and lives on the sibling rig seam, not here.

---
*AGPL-3.0-licensed.*
