# Changelog

Newest first. Versions are the `v*` tags in this repo; both packages release together.

## Unreleased

## 0.1.0

First release from this repo.

Split out of [`packet-net/packet.net`](https://github.com/packet-net/packet.net), where these
were `Packet.Radio` and `Packet.Radio.Tait`, most recently published as part of that repo's
`lib-v0.33.0`. Git history came across with the code.

- Renamed: packages, namespaces and project directories are all `M0LTE.Radio*` now. Type names
  and behaviour are unchanged, so porting is a `using` edit.
- The AX.25-specific parts did not come across. `RssiTaggingTransport` and `RadioCarrierSense`
  now ship from packet.net as `Packet.Ax25.Radio`, and `TaitTransparentTransport` as
  `Packet.Ax25.Radio.Tait`. That leaves these packages with no dependency on the packet stack
  at all: `M0LTE.Radio` needs only `M0LTE.Rig`, and `M0LTE.Radio.Tait` adds `System.IO.Ports`.
- **`ISerialIo` and `TcpSerialIo` are public API**, and the internal `TaitCcdiRadio.OpenForTest`
  is now a public `TaitCcdiRadio.Open(ISerialIo, ...)` overload. The seam had to cross a repo
  boundary to keep packet.net's Transparent-readiness tests working; exposing it also gives
  anyone a hardware-free way to test against the driver, or to reach a radio over a byte pipe
  this package does not model.
- Non-ASCII characters removed from every runtime string, including the section marks in CCDI
  argument-validation messages, which are now spelled out. Comments keep their notation.
