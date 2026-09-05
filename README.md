# M0LTE.Radio

Radio control for amateur-radio data links, in C#. What a serial control channel to the radio *behind* the modem gives you: signal strength, hardware carrier-sense, transmitter keying, telemetry, and a radio-native side channel that bypasses the audio path entirely.

| Package | What it is |
| --- | --- |
| [`M0LTE.Radio`](https://www.nuget.org/packages/M0LTE.Radio) | The abstraction: `IRadioControl`, `IRadioSideChannel`, `RadioCapabilities`, plus `RigRadioControl` which presents any [`M0LTE.Rig`](https://github.com/M0LTE/M0LTE.Rig) CAT rig through the same seam. |
| [`M0LTE.Radio.Tait`](https://www.nuget.org/packages/M0LTE.Radio.Tait) | Tait TM8100/TM8200 over CCDI: RSSI in dBm, real RF carrier-sense, PTT, PA temperature and power-detector telemetry, SDM short messages, CCR mode, port auto-discovery. |

```sh
dotnet add package M0LTE.Radio.Tait
```

```csharp
using M0LTE.Radio;
using M0LTE.Radio.Tait;

await using var radio = TaitCcdiRadio.Open("/dev/ttyUSB0");
await radio.SetProgressMessagesAsync(true);          // enable DCD events

radio.CarrierSenseChanged += (_, e) =>
    Console.WriteLine($"channel {(e.Busy ? "busy" : "clear")} at {e.At:O}");

Console.WriteLine((await radio.QueryIdentityAsync()).ProductName);
Console.WriteLine($"{await radio.ReadRssiDbmAsync():F1} dBm");
```

## Why this is a separate thing

Radio control is not packet radio. These libraries grew up inside [`packet-net/packet.net`](https://github.com/packet-net/packet.net) as `Packet.Radio` and `Packet.Radio.Tait`, where the name implied a coupling to AX.25 that most of the code did not have. They moved here so they can be used by anything that talks to a radio, and released on their own cadence.

The parts that genuinely *are* AX.25 stayed behind: per-frame RSSI tagging and the DCD-to-CSMA bridge ship as [`Packet.Ax25.Radio`](https://www.nuget.org/packages/Packet.Ax25.Radio), and AX.25 over the Tait's Transparent-mode FFSK pipe ships as [`Packet.Ax25.Radio.Tait`](https://www.nuget.org/packages/Packet.Ax25.Radio.Tait). Both build on the packages here. Nothing here depends on them, or on anything else from that stack.

## Testing without a radio

`TaitCcdiRadio.Open` takes an `ISerialIo` as well as a port name, so you can script the byte pipe and drive the whole transaction engine and unsolicited-message demux with no hardware attached. That is how this repo's own tests run, and `dotnet test` needs nothing installed.

`TcpSerialIo` implements the same seam over a TCP socket, for a radio on the far end of a serial-to-TCP bridge.

## Hardware

Verified on 2x TM8110 (`TMAB12-B100`, CCDI 03.02, firmware 02.18.00.00). Protocol reference: Tait MMA-00038-06, "TM8100/TM8200 CCDI Protocol Manual".

## Licence

AGPL-3.0-or-later. See [LICENSE](LICENSE).
