# M0LTE.Tait.Ccdi

Tait TM8100/TM8200 mobile-radio control over CCDI, the radios' serial command protocol, in C#: RSSI in dBm, real RF carrier-sense, PTT, PA temperature and power-detector telemetry, SDM short messages as a side channel, CCR run-time programming mode, and port auto-discovery.

```sh
dotnet add package M0LTE.Tait.Ccdi
```

```csharp
using M0LTE.Rig;
using M0LTE.Tait.Ccdi;

await using var radio = TaitCcdiRadio.Open("/dev/ttyUSB0");
await radio.SetProgressMessagesAsync(true);          // enable DCD events

radio.CarrierSenseChanged += (_, e) =>
    Console.WriteLine($"channel {(e.Busy ? "busy" : "clear")} at {e.At:O}");

Console.WriteLine((await radio.QueryIdentityAsync()).ProductName);
Console.WriteLine($"{await radio.ReadRssiDbmAsync():F1} dBm");
```

## Where it fits

This package implements both of [`M0LTE.Rig`](https://github.com/M0LTE/M0LTE.Rig)'s seams: `IRadioControl` natively, with push carrier-sense (`CarrierSenseChanged`) rather than the poll-based sense a plain CAT rig can offer; and a partial `IRigControl` station-control view via `TaitRigControl`, for cross-backend rig consumers that feature-probe `RigCapabilities`.

The sibling package [`M0LTE.Tait.Codeplug`](https://github.com/M0LTE/tait-codeplug) reads and writes these radios' codeplugs (the programming that decides which channels, frequencies and features exist); this package drives an already-programmed radio at run time. Different job, same radios.

AX.25 over the radio's Transparent-mode FFSK pipe - turning the radio's own internal modem into a TNC-less packet link - is AX.25-specific, so it does not live here: it ships from [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Ax25.Radio.Tait`, which builds on this package.

## Testing without a radio

`TaitCcdiRadio.Open` takes an `ISerialIo` as well as a port name, so you can script the byte pipe and drive the whole transaction engine and unsolicited-message demux with no hardware attached. That is how this repo's own tests run, and `dotnet test` needs nothing installed.

`TcpSerialIo` implements the same seam over a TCP socket, for a radio on the far end of a serial-to-TCP bridge.

## Hardware

Verified on 2x TM8110 (`TMAB12-B100`, CCDI 03.02, firmware 02.18.00.00). Protocol reference: Tait MMA-00038-06, "TM8100/TM8200 CCDI Protocol Manual".

## History

This driver was born inside [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Radio.Tait`, then split out to its own repo and released as `M0LTE.Radio.Tait` 0.1.0 alongside a sibling `M0LTE.Radio` abstractions package. At 0.2.0 those abstractions folded into [`M0LTE.Rig`](https://github.com/M0LTE/M0LTE.Rig), and this repo (and package) was renamed to `M0LTE.Tait.Ccdi` - the name "Rig" and "Radio" side by side carried too little distinction, and this driver sits next to `M0LTE.Tait.Codeplug`, another Tait-specific package, better than it sat next to a generic-sounding `M0LTE.Radio`.

## Licence

AGPL-3.0-or-later. See [LICENSE](LICENSE).
