using M0LTE.Rig;

namespace M0LTE.Radio.Tests;

/// <summary>Scripted <see cref="IRigControl"/> for the rig->radio bridge tests: settable
/// capabilities, DCD, signal strength and PTT answered instantly from memory, receive-side reads
/// scriptable to fail (<see cref="ReadFault"/>), and counters/flags for cadence and disposal
/// assertions. The station-control members the bridge never touches (frequency/mode/meters)
/// throw <see cref="NotSupportedException"/>.</summary>
internal sealed class FakeRig : IRigControl
{
    private int disposed;
    private int dcdReads;
    private int strengthReads;
    private int pttSets;

    public RigCapabilities Capabilities { get; init; } =
        RigCapabilities.DcdRead | RigCapabilities.SignalStrengthRead | RigCapabilities.PttSet;

    public RigInfo Info { get; init; } = new("Fake rig", "Acme", "Fake-1000");

    public bool Dcd { get; set; }

    public double StrengthDbm { get; set; } = -120;

    public bool Ptt { get; private set; }

    /// <summary>When set, every receive-side read throws it - models a bounced daemon mid-poll.</summary>
    public RigException? ReadFault { get; set; }

    /// <summary>Number of DCD reads attempted (faulted ones included) - cadence assertions.</summary>
    public int DcdReads => Volatile.Read(ref dcdReads);

    /// <summary>Number of signal-strength reads attempted - delegation assertions.</summary>
    public int StrengthReads => Volatile.Read(ref strengthReads);

    /// <summary>Number of PTT commands issued - no-redundant-unkey assertions.</summary>
    public int PttSets => Volatile.Read(ref pttSets);

    /// <summary>True once <see cref="DisposeAsync"/> ran.</summary>
    public bool Disposed => disposed != 0;

    private T Answer<T>(T value)
        => ReadFault is { } fault ? throw fault : value;

    public ValueTask<bool> ReadDcdAsync(CancellationToken cancellationToken = default)
    {
        Interlocked.Increment(ref dcdReads);
        return new(Answer(Dcd));
    }

    public ValueTask<double> ReadSignalStrengthDbmAsync(CancellationToken cancellationToken = default)
    {
        Interlocked.Increment(ref strengthReads);
        return new(Answer(StrengthDbm));
    }

    public ValueTask SetPttAsync(bool transmit, CancellationToken cancellationToken = default)
    {
        Interlocked.Increment(ref pttSets);
        Ptt = transmit;
        return ValueTask.CompletedTask;
    }

    public ValueTask<long> GetFrequencyAsync(CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask SetFrequencyAsync(long frequencyHz, CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask<RigModeState> GetModeAsync(CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask SetModeAsync(RigMode mode, int? passbandHz = null, CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask<bool> GetPttAsync(CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask<double> ReadSwrAsync(CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask<double> ReadRfPowerAsync(CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask<double> ReadRfPowerWattsAsync(CancellationToken cancellationToken = default) =>
        throw new NotSupportedException();

    public ValueTask DisposeAsync()
    {
        Interlocked.Exchange(ref disposed, 1);
        return ValueTask.CompletedTask;
    }
}
