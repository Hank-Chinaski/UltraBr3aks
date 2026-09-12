# DingleDerp: additional analysis of the latest post-Gen3 crash

Prepared September 12, 2026. Root cause remains unresolved. Analysis used existing copied dumps and read-only event/file queries; no Windows, BIOS, driver, or application settings were changed.

## Outcome

**Confirmed fact:** The September 11 crash repeats the earlier `0xEF / csrss.exe / ntdll!RtlLookupFunctionEntry` signature. This analysis recovered an actual exception record with lower status `0xC000000E`, and traced the affected DLL's backing volume directly to C:.

**Confirmed fact:** Before this critical process died, a System worker had sent it a `0xC0000222 STATUS_LOST_WRITEBEHIND_DATA` message for a PowerToys CursorWrap log on C:. The original kernel hard-error packet retains the filename. Additional System cache-writer threads were reporting lost delayed writes involving other C: files.

**Supported inference:** The repeating `winsrvext.dll + 0x23840` exception-handling failure is downstream of an earlier failed write and an earlier failed instruction fetch. The investigation now has evidence of both read and write failures involving C:, beyond an unreadable page in debugger output alone.

**Open hypothesis:** The component responsible for the failed I/O remains unidentified. This does not prove defective SSD media, a physical NVMe disconnect, a PCIe slot fault, or PowerToys causation. PowerToys log files can be victims of a wider failure.

**Falsified as a sufficient fix:** The reported Gen3 trial did not prevent the recurring system crashes. The initial 15-minute session was not proof of a fix. The reported BIOS trial included other changes, so its effects cannot be attributed exclusively to the link-speed setting. No permanent Gen3 recommendation follows from these results.

## Artifacts and incident identity

| Artifact | What it establishes |
| --- | --- |
| `C:\Users\PIZZAOVEN\Desktop\Mem\CRITICAL_PROCESS_DIED (ef).txt` | User-supplied latest WinDbg transcript, 755 lines |
| `C:\Users\PIZZAOVEN\Desktop\Mem\Post-Gen3-20260911.dmp` | Directly analyzed kernel bitmap dump, 3,506,382,983 bytes |
| `C:\Users\PIZZAOVEN\Desktop\Mem\Post-Gen3-20260910-004154.dmp` | Earlier directly analyzed post-trial `0x1E` dump |

**Confirmed fact:** The latest dump's internal crash time is **September 11, 2026, 19:03:53.764 PDT**, uptime **1 minute 53.411 seconds**. Its 19:06 file/WER timestamps describe later capture/reporting, not the crash instant. `NBA2K27.exe` is present; its recorded elapsed process time is **49.374 seconds**.

**Confirmed fact:** The earlier copied `0x1E` dump's internal crash time is **September 9, 2026, 23:00:26.071 PDT**, uptime **1:50:52.503**. Its September 10 filename/reporting time must not replace that internal timestamp.

## Recovered latest-crash sequence

### 1. Original kernel hard-error packet

System thread `ffff880dc772f400` (PID/TID `4.254`) is waiting for an ALPC reply from the crashing csrss process `ffff880de19a7080`. Its stack includes:

```text
nt!IopHardErrorThread
nt!ExRaiseHardError
nt!ExpRaiseHardError
nt!LpcSendWaitReceivePort
```

At `.frame /r a`, saved RBX is `ffff880e01c939d0`. Disassembly of this dump's `nt!IopHardErrorThread` shows that the packet status is read at `RBX+0x10`, and a counted Unicode filename is passed from `RBX+0x18`.

```text
Packet:       ffff880e01c939d0
Status:       c0000222
String:       ffff880e01c939e8
String bytes: 0xde
Buffer:       ffff880dff97c0a0
Filename:     C:\Users\PIZZAOVEN\AppData\Local\Microsoft\PowerToys\CursorWrap\ModuleInterface\Logs\v0.97.2\log_2026-09-11.log
```

The csrss-side message at `0000010cf81ab618` independently contains client ID `4.254` and status `c0000222`. Its user string pointer was unreadable; the filename above was recovered from the kernel packet instead. No assumption about an undocumented structure's full layout was needed for that recovery: packet field use was checked against the actual kernel instructions.

Microsoft defines `0xC0000222` as `STATUS_LOST_WRITEBEHIND_DATA`, a delayed-write failure. See [Microsoft's NTSTATUS reference](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55).

Evidence: [harderror-packet.txt](dump-analysis-20260911/harderror-packet.txt), [write-error.txt](dump-analysis-20260911/write-error.txt), [harderror-context.txt](dump-analysis-20260911/harderror-context.txt), [system-harderror.txt](dump-analysis-20260911/system-harderror.txt).

### 2. Earlier instruction-page failure inside csrss

The oldest captured matching user exception record found on this thread's stack is at `0000000971cfe9b0`, paired with context `0000000971cfe4c0`:

```text
Exception address: 00007ffcd5ddc000 = winsrvext!GetHardErrorText+0xbc
Exception code:    c0000006
Parameter[0]:      8   (instruction fetch)
Parameter[1]:      00007ffcd5ddc000
Parameter[2]:      c000000e
DLL base:          00007ffcd5dd0000
Relative offset:   0xc000
```

**Confirmed fact:** This captured instruction fetch failed with lower status `STATUS_NO_SUCH_DEVICE` while csrss was preparing hard-error text. This is the oldest recovered exception in that thread's captured sequence, not proof of the ultimate initiating system fault.

The stack's `UserHardErrorEx`, `CSRSRV!QueueHardError`, and `CSRSRV!CsrApiRequestThread` return addresses, saved argument, and matching kernel sender corroborate the hard-error-message path.

Evidence: [targeted-pass3.txt](dump-analysis-20260911/targeted-pass3.txt), [harderror-context.txt](dump-analysis-20260911/harderror-context.txt), [harderror-detail.txt](dump-analysis-20260911/harderror-detail.txt).

### 3. Repeated exception-handling failure at the familiar DLL offset

Record `0000000971cc1f30` contains:

```text
Exception address: 00007ffcd8c7309d = ntdll!RtlLookupFunctionEntry+0x8d
Exception code:    c0000006
Parameter[0]:      0   (read)
Parameter[1]:      00007ffcd5df3840 = winsrvext.dll + 0x23840
Parameter[2]:      c000000e
```

The current ntdll dispatcher instructions were inspected to locate the saved exception records; `.exr -1` was not relied upon. This recovers the lower I/O status for **this September 11 dump**. It does not retroactively extract or prove the missing lower status in the September 7 dumps.

Evidence: [targeted-pass2.txt](dump-analysis-20260911/targeted-pass2.txt).

### 4. Direct backing-volume mapping

The correct query `!vad 00007ffcd5df3840 1` identifies an image mapping for `\Windows\System32\winsrvext.dll`:

```text
ControlArea: ffff880dd61b75e0
FileObject:  ffff880de1ae8140
Device:      ffff880dd1fa38f0
VPB:         ffff880dd3237a00
Volume:      \Device\HarddiskVolume3
Label:       CooCoo
Serial:      EEF90D57
```

The dump's `\GLOBAL??\C:` symbolic link resolves to that same `\Device\HarddiskVolume3`; E: resolves to `\Device\HarddiskVolume7`. This directly identifies C: as the DLL's backing volume. It does not identify which layer returned the failed status or prove that the physical SSD vanished.

The captured volume stack contains volsnap, volume, iorate, fvevol and volmgr. Its device node is Started. These are captured state and inventory, not attribution of fault. The earlier transcript's VAD-root-pointer query returned an unrelated pagefile-backed mapping; it must not be used to label the actual DLL access as a pagefile read.

Evidence: [device-trace.txt](dump-analysis-20260911/device-trace.txt), [game-and-device-context.txt](dump-analysis-20260911/game-and-device-context.txt).

## Additional corroboration and limits

**Confirmed fact:** Other System threads are in `CcWriteBehindPostProcess` / `CcMmLogLostDelayedWriteError`. File objects recovered from those contexts identify:

- `ffff880dfc9757c0`: PowerToys AdvancedPaste module log.
- `ffff880dfc9988b0`: PowerToys NewPlus shell-extension log.
- `ffff880dfc99b600`: NTFS stream named `\$ConvertToNonresident`.

All three refer to the same C: device and VPB above. Raw stack argument columns contain `c000000e` values but are not independently validated exception records; do not treat every such stack value as a proven call argument. The two user exception records' lower statuses were explicitly validated.

Evidence: [additional-writes.txt](dump-analysis-20260911/additional-writes.txt), [write-error.txt](dump-analysis-20260911/write-error.txt).

**Confirmed fact:** A read of the named on-disk CursorWrap log succeeded after running the read outside the sandbox. Its displayed tail contains initialization entries at 13:38 and 23:10, not a recovered entry at the 19:03 crash. This absence does not establish inactivity or a cause; the dump explicitly reports a failed write.

**Confirmed fact:** The targeted System event query for September 11, 18:58–19:07, found boot/dump/volume-health and PnP records, but no disk/stornvme/storport reset or WHEA record in that selected provider window. Successful primary dump generation remains corroborated by the dump header despite volmgr reporting both success and failure events. Event-log absence does not override the captured failed operations. [Event results](dump-analysis-20260911/storage-event-window.json).

**Confirmed fact:** The earlier post-trial `0x1E` dump has an actual `c0000006` record with lower `c000000e` at `nt!HvpGetCellPaged+a5`; hive inventory identifies the SOFTWARE hive. [Earlier analysis](dump-analysis-20260910-copy/initial-analysis.txt).

**Open hypothesis:** PowerToys might participate in a trigger, but the established fact is failure to persist its logs. Exiting or uninstalling it has not been tested here. A named victim file is not causal proof.

**Open hypothesis:** The remaining separation is between failures originating in C:'s software/storage stack and its controller/link/device path, including corruption that could affect those paths. The captured error identifies failure semantics, not the responsible component.

**Limit:** The game PEB loader data was missing in this bitmap dump. Exact game build, renderer and injected modules were not recovered; empty debugger module output is not evidence that overlays are absent. `winsrvext.dll` reports version `10.0.26100.9444`; that alone was not used to assert the kernel's exact file revision.

## Next evidence target

Compare NBA's launch path, active components and file/cache activity with the successful games recorded below. In parallel with that comparison, trace the failing C: operations below the volume layer, looking for a retained failed request or controller/device error state. Compare the preserved September 11 `0x154` minidump if a readable copy becomes available; its WER record establishes a separate preceding bugcheck but not its internal exception. The remaining evidence gap is attribution of the failed operations, not whether the latest event is merely an NBA application crash.

No additional reproduction, permanent Gen3 restriction, driver removal, PowerToys uninstall, or physical storage intervention is justified as a proven fix by this analysis.

## September 12 update: successful comparisons on D:

**Confirmed fact, user-reported:** Bryan played Tiny Terry's Turbo Trip without an issue, and completed a full Dynasty-mode game in EA SPORTS College Football 27 without freezing or a crash. Exact session durations were not reported. These are completed successful sessions, not proof of indefinite stability.

**Confirmed fact, local file inspection:** All three game executables are present on the same D: installation volume:

| Game | Executable | Observed outcome |
| --- | --- | --- |
| NBA 2K27 | `D:\GAMES\NBA 2K27\NBA2K27.exe` | Repeated system crashes in the investigation |
| Tiny Terry's Turbo Trip | `D:\GAMES\Tiny Terry's Turbo Trip\Tiny Terry's Turbo Trip.exe` | Successful session reported September 12 |
| EA SPORTS College Football 27 | `D:\GAMES\EA SPORTS College Football 27\CollegeFB27.exe` | Full Dynasty-mode game completed successfully |

This confirms a local NBA installation on D:; the process image's full path in the September 11 dump was not recovered in this update. No assumption about D:'s physical disk number is needed for the volume comparison. The BIOS setting during the two successful sessions was not independently queried.

**Supported inference:** The selective game trigger deserves greater weight. A model in which any demanding game is enough to produce the failure is weakened. A simple difference between the games' installation volumes does not distinguish these local installations. The user's assessment of comparable demand is useful context, but no CPU/GPU/storage workload measurements were supplied to establish identical demand.

**Confirmed fact:** These successful sessions do not undo the failed C: operations captured in the NBA-associated dump. C: is an affected backing volume; the game executable need not be installed there for C: to participate in a failure.

**Open hypothesis:** Differences in NBA's launch path, protection, mods or injected components, input/overlay activity, caching, and workload could account for the selectivity. None is established as causal. A file being present is not evidence it ran or was loaded. Limited executable inventory found `start_protected_game.exe` and `mod.exe` beside NBA; their role and use remain unverified. College Football's `EAAntiCheat.GameServiceLauncher.exe` reports product name EA Javelin Anticheat and version 1.0.13295687.0; presence alone does not establish runtime state. These observations justify comparison, not execution, removal, or blame.

No new setting change, reproduction, or executable launch was performed for this update.
