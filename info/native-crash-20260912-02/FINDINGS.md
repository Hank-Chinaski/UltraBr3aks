# Second Native-rendering crash near the start of the second quarter

Analyzed September 12, 2026. Root cause remains unresolved.

## User-reported reproduction

**Confirmed fact, user-reported:** Bryan replayed the exact same game mode, teams and quarter length. Quarter length was not shortened. This time the opponent inbounded at the start of the second quarter. About six seconds into the quarter, the game briefly froze for approximately three to four seconds and resumed. Around twelve seconds into the quarter it froze permanently, including video and audio, and Bryan forced a restart. These quarter-relative timings are user observations, not independently timestamped against the dump; they are retained separately from process elapsed time.

Bryan copied the dump to `C:\Users\PIZZAOVEN\Desktop\Mem\Native-20260912-0x154_02.dmp`. The readable copy is **3,545,529,718 bytes**, with filesystem modification time September 12 at 05:13:00. WinDbg reports successful primary dump capture and final progress 100%.

**Confirmed fact:** The saved NBA video configuration still records Native rendering (`RESOLUTION_SCALING_TECHNIQUE=0`), frame generation false, GameInput false, Reflex method 2, 2560x1440 and VSYNC 0. No configuration value was changed during this analysis.

## Direct comparison of the two Native dumps

| Attribute | First Native run | Second Native run |
| --- | --- | --- |
| Internal crash time, PDT | September 12, 04:23:52.223 | September 12, 05:12:02.675 |
| Windows uptime | 9:17:40.829 | 0:46:56.346 |
| NBA process elapsed time | 8:22.942 | 7:52.084 |
| User-observed game phase | First inbound of second quarter, before clock advanced | Brief pause around 6 seconds into second quarter; permanent freeze around 12 seconds |
| Bugcheck | 0x154 | 0x154 |
| Faulting function | nt!RtlDecompressBufferLz4+0xb0 | Same |
| Exception | c0000006 STATUS_IN_PAGE_ERROR | Same, independently extracted |
| Underlying I/O status | c000000e STATUS_NO_SUCH_DEVICE | Same, independently extracted |
| Attached process | MemCompression | MemCompression |
| Owning process of faulting thread | svchost.exe | FormlabsCrashHandler.exe |

**Confirmed fact:** Both dumps have bucket `0x154_c0000006_c000000e_nt!RtlDecompressBufferLz4` and failure hash `{f80368d8-3bea-7666-f736-c39e396bd15b}`. The matching exception records and instruction support the comparison beyond the bucket name alone. The failure occurs on a read of the decompression source memory, not on a reported invalid compressed-data result.

The first NBA elapsed time was recovered from the first dump during this follow-up; both figures describe time since NBA process creation, including startup and menus, not just active gameplay. They differ by **30.858 seconds**. Because both runs used the same quarter duration, game phase and elapsed runtime remain correlated. No shortened-quarter comparison has yet been completed.

## New dump details and limits

```text
Bugcheck parameters:
  P1 ffffa90d93f4d000
  P2 ffff82064296dd70
  P3 2
  P4 0
EXCEPTION_RECORD ffff82064296ed68
CONTEXT ffff82064296e580
ExceptionAddress fffff805c9db1ba0 = nt!RtlDecompressBufferLz4+0xb0
ExceptionCode c0000006
Parameter[0] 0 (read)
Parameter[1] 000001f3b45df770
Parameter[2] c000000e
Instruction: movzx r10d,byte ptr [rdx]

Faulting thread ffffa90da1eb0040, PID/TID 411c.9a80
Owning process ffffa90d99cba0c0, FormlabsCrashHandler.exe
Attached process ffffa90d93f4f040, MemCompression
MemCompression directory base a96bba000

NBA process ffffa90d967a80c0, PID 5c98, parent PID 40d0
NBA PEB 475b929000, paged out
NBA directory base e1ef4d000
NBA working set 7,842,648 KiB at capture
```

**Supported inference:** The same terminal paging failure occurring on behalf of different background processes is consistent with those processes encountering a shared underlying problem. It does not establish FormlabsCrashHandler.exe as a cause, and its presence is not a basis for uninstalling or disabling Formlabs software.

**Limit:** The failed source lies in a private-memory VAD, with no image-file control area. The relevant page-table page (physical frame `846ec4`) is not present in this bitmap dump. Direct translation using MemCompression's directory base also fails at the PDPE read. The exact paging slot, disk offset, associated failing IRP and responsible device stack therefore were not recovered from this page. The prior Native dump had the same kind of translation-data limitation at a different frame.

**Confirmed fact:** The paging inventory lists `C:\pagefile.sys` and `C:\swapfile.sys`, plus the virtual store. Available physical memory is 37,916,172 KiB, and committed memory is 38,644,444 KiB against a 133,717,824 KiB limit. These figures do not show exhaustion of total physical RAM or system commit. They do not establish a physical SSD defect.

## Targeted game-thread and brief-recovery checks

The dump yielded **192 NBA thread entries**. The visible kernel stacks show waits/completion handling or running user addresses; NBA's PEB is paged out and the user frames do not supply named quarter-transition logic. This capture does not identify the game action that initiated the system failure.

Three outstanding I/O requests were listed on NBA threads and inspected:

| IRP | Captured operation | Status field at capture |
| --- | --- | --- |
| ffffa90d8328e010 | Pending 16-byte read via xinputhid | 0 |
| ffffa90dbeb0e2a0 | Pending AFD device-control/poll request | 0 |
| ffffa90da4d932a0 | Pending NTFS directory-notification request through FltMgr | 0 |

**Limit:** Pending requests are not proof of a fault, and their current zero status fields do not prove completed successful I/O. None of these three requests supplies the `c000000e` failure or a connection to the brief pause. This is not a complete inventory of all I/O in the system, including memory-manager or separate driver-worker requests.

**Confirmed fact:** A read-only query of the System log for **05:10:30-05:12:10 PDT**, covering the final freeze and the nearby brief-recovery report, completed with `NoMatchingEvents`. No display/storage reset was established from this window. This absence does not prove that no reset, stall or I/O disruption occurred. No channels were enabled.

NTFS blackbox again shows zero slow-I/O and oplock timeout records. PnP blackbox names `SWD\DAFUPnPProvider\uuid:ff654bed-128b-40da-a814-ba2ee3de0c9f`, problem code 24, no event in progress. This is not attributed to P: or to a storage controller. P:'s connection state during this new session was not established and is not inferred from the previous session.

## Updated interpretation and proposed discriminator

**Supported inference:** Two matched Native-rendering runs now end near the start of the second quarter and independently share the same kernel failure signature. This strengthens the early-second-quarter phase as a reproduction target.

**Supported inference:** Bryan making the inbound pass and the exact instant the clock starts are unnecessary for the latest recurrence: the opponent inbounded, the clock advanced and the game briefly resumed before the final freeze. The broader phase remains the relevant candidate. Earlier menu/idle crashes prevent treating this phase as necessary for every incident.

**Open hypotheses:** A second-quarter transition-related activity triggers the problem; or time/accumulated work under the same match conditions produces the similar timing. The brief pause could be part of the developing failure or a separate event; its mechanism is not established.

**Confirmed fact, user-reported:** Bryan identifies the mode as **MyNBA** and the played-quarter duration as **5 minutes** for both runs. This resolves the pending mode/duration question.

**Proposed single comparison:** Keep the same MyNBA matchup and other current settings, changing only played-quarter length from 5 minutes to 1 minute if offered, otherwise the shortest available value below 5. Observe the first-quarter recap and play through the second quarter if it remains stable, stopping at the first system crash. Record the quarter/clock position of any brief stall or final freeze and approximate elapsed real time. Restore 5-minute quarters afterward. The exact minimum/menu path in this NBA 2K27 build was not verified from official documentation; no unsupported UI path is supplied. No setting was changed by the assistant.

**Predictions:** A repeat of the early-second-quarter failure substantially earlier after launch would strengthen a game-phase association. Passing that phase would weaken repeatability in the shortened condition, without proving a fix or proving an elapsed-time cause. If a later crash occurs near the previous launch-to-crash time, that would favor elapsed time/accumulated activity. Shorter quarters also change accumulated game activity, so neither outcome alone identifies a faulty component. Existing runs both used 5-minute quarters and therefore do not separate phase from elapsed time.

**Risk and rollback:** Another system crash could lose unsaved work. Save open work before a reproduction, stop at the first crash, and restore the original quarter length after the comparison. No setting change or reproduction was executed by the assistant. Native rendering has failed twice as a sufficient fix.

## Artifacts

- [Initial dump analysis](analysis-pass1.txt)
- [Original exception, ownership and failed-page checks](analysis-pass2.txt)
- [NBA threads and direct address-translation check](game-threads.txt)
- [Three outstanding NBA I/O requests](game-irps.txt)
- [Prior Native dump's NBA elapsed time](prior-game-time.txt)
- [Targeted System-log query result](system-crash-window.json)

All debugger operations were offline against preserved copies. The only live reads were the saved NBA video settings and the narrow System-log query. No BIOS, game, driver, service, pagefile, device or cache setting was changed.
