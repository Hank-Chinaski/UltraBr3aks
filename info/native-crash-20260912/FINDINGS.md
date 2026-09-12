# Native-rendering recurrence and P: disconnect timeline

Prepared September 12, 2026. Root cause remains unresolved.

## Controlled-test outcome

**Confirmed fact, user-reported:** NBA progressed through the first quarter, then froze after the quarter recap when Bryan inbounded the ball. Total time was about 10-15 minutes and Bryan forced a restart. P: repeatedly disconnected/reconnected during play; he paused NBA and unplugged it around halfway through the first quarter, about five minutes before the later freeze.

**Confirmed fact:** The saved NBA configuration remains `RESOLUTION_SCALING_TECHNIQUE=0` (Native), last written September 12 at 04:15:37. It still records 2560x1440, frame generation false, GameInput false, and Reflex method 2.

**Falsified as a sufficient fix:** Disabling DLSS did not prevent a system crash. Native was still selected. The longer session and perceived gameplay improvement do not establish a statistically supported stability improvement, particularly given the external-drive events during this run.

**Confirmed fact:** WER Event 1001 at **04:25:24** records:

```text
0x00000154
Parameter 1: ffffe70f541ed000
Parameter 2: fffffc8bec01dd70
Parameter 3: 2
Parameter 4: 0
Report ID: 17233a0e-686b-4c58-943c-46b9a38598b3
Dump: E:\CrashDumps\MEMORY.DMP
```

Windows boot time is **04:25:06**. The full dump is **4,755,202,147 bytes**, last written **04:25:10**. The minidump `E:\CrashDumps\Minidump\091226-17109-01.dmp` is **7,764,508 bytes**, last written **04:25:24**. These are reboot/capture/report timestamps, not the internal bugcheck time.

Microsoft identifies `0x154` as an unexpected exception caught by the kernel memory store. This report alone does not identify the underlying exception or I/O status. [Official bugcheck reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x154--unexpected-store-exception).

**Earlier access limit, now resolved for the full dump:** A direct read of the protected minidump failed with an OS access-denied error, including outside the sandbox. Bryan subsequently copied the full dump to `C:\Users\PIZZAOVEN\Desktop\Mem\Native-20260912-0x154.dmp`. The copy is 4,755,202,147 bytes and was successfully analyzed below. The statuses reported below were extracted from this new dump itself.

## External-device identity

**Confirmed fact:** The retained `HKLM\SYSTEM\MountedDevices` mapping for `\DosDevices\P:` encodes GPT partition ID `d00a8d7d-11a0-43fe-a1dd-54b50b9cd85e`. The exact GUID bytes appear in the nonzero-capacity Partition/Diagnostic Event 1006 records during this session.

Those records identify:

```text
Manufacturer: SanDisk
Model: Extreme 55AE
Serial: 2343GD400848
Revision: 8058
Capacity when populated: 4000753467904 bytes
Historical disk number: 4
Disk ID: 7fa19611-d4eb-a3df-a322-096c19a0df9f
Parent ID: USB\VID_0781&PID_55AE\MSFT30323334334744343030383438
```

The recorded PagingCount, HibernationCount and DumpCount are zero. Do not claim this was the system's pagefile or crash-dump disk.

## Recorded sequence (Pacific time)

| Time | Capacity in Event 1006 | Partition count | P: partition GUID present |
| --- | --- | --- | --- |
| 04:16:49.665 | 0 | 0 | No |
| 04:16:51.781 | 4,000,753,467,904 | 2 | Yes |
| 04:18:25.617 | 0 | 0 | No |
| 04:18:26.678 | 4,000,753,467,904 | 2 | Yes |
| 04:18:40.624 | 0 | 0 | No |
| 04:18:41.682 | 4,000,753,467,904 | 2 | Yes |
| 04:18:52.164 | 0 | 0 | No |

**Supported inference:** This sequence corroborates Bryan's observed disconnect/reconnect pattern. The final zero-capacity record is consistent with his deliberate disconnection. Event 1006 field values alone do not prove the initiating electrical, device, controller or software cause, and user-removal-policy flags are not treated as a direct record of a user's action.

**Confirmed fact:** A subsequent live disk enumeration found the internal NVMe devices and no SanDisk matching this identity; a P: logical-disk query returned no entry. This is consistent with the device remaining disconnected after the restart.

## Other event evidence

System events for 04:05-04:27 were preserved in [system-events.json](system-events.json). No pre-reboot event matched the selected error/warning/storage/USB/PnP provider filters. The most recent pre-reboot System records returned by a separate query were informational Netwaw18 events at 04:15:07. This absence is not proof that no I/O fault occurred or that event logging stopped.

The already-enabled Partition/Diagnostic log contained the records above, preserved in [the full XML export](Microsoft-Windows-Partition_Diagnostic.json) and [the reduced identity/timeline export](external-drive-timeline.json). Kernel-PnP/Configuration records were also preserved. Storage-ClassPnP/Operational had no matching events in the selected window. DriverFrameworks-UserMode/Operational was disabled. Storage-Storport/Operational information could not be read due to an access error. No channels were enabled and no storage setting was changed.

## Remaining interpretation and next step

**Open hypotheses:** P:'s interruption initiated lasting disruption; it and the system crash share a cause; or it was incidental. Unplugging P: five minutes before the freeze does not discriminate among those possibilities.

The readable full copy has now been preserved and analyzed. It establishes the actual crash time and original exception; the failed page's missing translation data limits a complete device trace, as detailed below.

The earlier proposal was a comparison with this specific SanDisk absent from the start of a fresh Windows session. It was not run by the assistant. Bryan subsequently challenged prioritizing the five-minute USB-event association over the precise game action when the freeze occurred. The next investigation priority is now the second-quarter transition/inbound comparison below. The P: timeline is retained as an unresolved observation and does not establish a leading causal explanation.

## Full dump analysis after Bryan made the copy

**Confirmed fact:** WinDbg reports primary dump contents written successfully, final progress 100%, and internal bugcheck time **September 12, 2026 at 04:23:52.223 PDT**. Uptime was **9:17:40.829**. The actual crash occurred **300.059 seconds (5 minutes and 0.059 seconds)** after P:'s final zero-capacity event at 04:18:52.164. This independently matches Bryan's approximate five-minute interval. Event/file timestamps after reboot are not substituted for this internal crash time.

**Confirmed fact:** The original exception was recovered directly:

```text
Bugcheck: 0x154 UNEXPECTED_STORE_EXCEPTION
Exception-information pointer: fffffc8bec01dd70
EXCEPTION_RECORD: fffffc8bec01ed68
CONTEXT: fffffc8bec01e580
ExceptionCode: c0000006 STATUS_IN_PAGE_ERROR
ExceptionAddress: fffff802c73b1ba0 nt!RtlDecompressBufferLz4+0xb0
Parameter[0]: 0 (read)
Parameter[1]: 000001719f5902c0
Parameter[2]: c000000e STATUS_NO_SUCH_DEVICE
Instruction: movzx r10d,byte ptr [rdx]
Failure bucket: 0x154_c0000006_c000000e_nt!RtlDecompressBufferLz4
Failure hash: {f80368d8-3bea-7666-f736-c39e396bd15b}
```

The decompression routine could not read its source memory. This is an in-page I/O exception, not evidence that the LZ4 algorithm detected corrupt compressed data. Microsoft describes 0x154 as an unexpected exception caught by the kernel memory store; the exception record supplies the more specific mechanism here. [Bugcheck reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-0x154--unexpected-store-exception).

**Confirmed fact:** The faulting thread `ffffe70fa7e27080` (PID/TID `8470.8578`) belongs to `svchost.exe` process `ffffe70f7fbc50c0` and is attached to `MemCompression` process `ffffe70f541ef040`. The stack runs through the memory-store page-retrieval/decompression path after a user-mode page fault. `PROCESS_NAME: MemCompression` describes the attached context; it does not by itself identify the initiating program or service. The specific hosted service was not resolved.

**Confirmed fact:** `!vm 1` lists the virtual memory store and the disk files `\??\C:\pagefile.sys` and `\??\C:\swapfile.sys`; no P: paging file is listed. At this crash the main pagefile was **66,858,912 KiB**, differing from the older 43,008 MB observation in the handoff. This is a captured state, not a change made in this analysis. The report lists approximately 36.1 GiB of available physical memory and 43.6 GiB committed against a 127.5 GiB limit; it does not show exhaustion of total RAM or commit capacity.

**Limit:** `!pte` for the failed source address cannot read a page-table page at physical frame `e06148`. Selecting the MemCompression process and directly translating with its directory base `1b6d3e000` reproduces the missing PDPE read. Consequently the precise pagefile slot, page offset and associated I/O request/device stack were not recovered. The VAD identifies private memory, not an image-file control area. The apparent VAD commit charge is not used as a reliable memory-usage figure.

**Supported inference:** C:'s paging path remains relevant because the captured disk-backed paging files are on C:. This is not a complete request-to-device trace and does not identify a failing physical SSD, controller, link or driver. P:'s observed disruption could precede a persistent effect, share an initiator with this failure, or be incidental.

**Confirmed fact:** NTFS blackbox again has zero slow-I/O and oplock timeout records. PnP blackbox names `STORAGE\VolumeSnapshot\HarddiskVolumeSnapshot2`, problem code 24, no event in progress. That snapshot record is not an identification of P: or the failed NVMe device.

**Supported inference:** This recurrence shares `c0000006` with the earlier captured failures and independently shares lower status `c000000e` with the September 6/9 Registry failures and the directly analyzed September 11 csrss failure. Its immediate victim is the compressed-memory retrieval path, not the earlier winsrvext exception-dispatch path. This supports a recurring failed paging/backing-store mechanism across different consumers; it does not prove a single initiator or extend the extracted lower status to September 7 dumps where it remains unknown.

**Falsified as a sufficient fix:** Native rendering did not stop the system-level in-page failures. The longer single session does not establish an improvement in stability.

Analysis logs: [initial exception and crash time](analysis-pass1.txt), [thread ownership and paging inventory](analysis-pass2.txt), [explicit MemCompression-context check](analysis-pass3.txt), and [direct translation check](analysis-pass5.txt). Pass 4 used a frame-number form that this debugger interpreted as a directory address; that failed probe is superseded by the full directory-base check in pass 5. All debugger work was offline against the copy. No Windows, driver, BIOS, pagefile or game setting was changed in this follow-up.

## Revised priority: the first inbound of the second quarter

**Confirmed fact, user-reported:** Bryan specifies that the freeze occurred immediately as he passed the ball inbounds after the first-quarter recap, before the second-quarter game clock began advancing. This precise observed game action should be preserved separately from the total 10-15 minutes elapsed and the P: timeline.

**Open hypothesis:** The return from the recap to live play, or the first inbound action, triggers activity involved in the failure. This is the next reproduction target. The kernel dump does not identify the corresponding NBA game state or prove that the button press initiated the failed I/O. Earlier menu/idle failures mean this particular transition is not established as necessary for all incidents.

**Evidence check:** A read-only listing of the local NBA settings directory found the existing video configuration/help and PSO cache files. A filename search for `.log`, `.dmp`, `*crash*` and `.txt` under the NBA installation returned license texts and no gameplay diagnostic log. This limited search does not exclude logs elsewhere or files with other formats. No game was launched and no cache, configuration, executable or device was changed.

**Proposed single comparison:** If the current mode permits it, replay the same mode and matchup with only the quarter length shortened to the shortest supported setting. Record the original quarter length first. Keep Native rendering and the other current conditions unchanged. Observe the first inbound after the first-quarter recap; stop at the first crash. If quarter length is fixed in that mode, repeat the same sequence unchanged to establish whether the action is reproducible, without substituting another mode.

**Predictions and limits:** A freeze at the same action substantially earlier in real elapsed time would strengthen an association with the game transition/action. Passing that point weakens its repeatability in the shortened-quarter condition; a later crash would help distinguish transition from elapsed-time explanations. Neither outcome alone identifies the faulty component, and shortening quarters can also affect accumulated game activity. Existing evidence records this precise freeze point once, so its repeatability is not already answered.

**Risk and rollback:** Another system crash can lose unsaved work; save open work before testing. Restore the original quarter length afterward. This replaces the broad 45-60-minute P:-absence test as the immediate proposal. The proposed comparison has not been executed by the assistant.
