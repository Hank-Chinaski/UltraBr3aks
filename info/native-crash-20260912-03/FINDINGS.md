# Third Native run: C: NVMe device-gone state recovered

Analyzed September 12, 2026. The failing storage path is now localized more precisely; the initiating defect and a guaranteed repair remain unproven.

## Scope and user instruction

Bryan completed the proposed comparison in **MyNBA**, retaining the same game/matchup/teams and changing played-quarter duration from **5 minutes to 1 minute**. He reports a crash with **five seconds remaining in the second quarter**, **4 minutes 6 seconds after launch**. He preserved `C:\Users\PIZZAOVEN\Desktop\Mem\Native-20260912-03.dmp` and explicitly directed that there be **no further exchanges of crash-reproduction tests**. That supersedes the earlier proposed test loop. No game launch, reproduction, device change, driver change or system-setting change was performed in this follow-up.

## Main new evidence

**Confirmed fact:** The captured storage-class identity ties the failed boot/paging NVMe path to the C: Samsung 990 PRO 2 TB, serial `0025_3842_3141_8E54.`, firmware `8B2QJXD7`. This identification is from the actual dump's storage structures, not an assumption from the final exception or a reused disk number.

**Confirmed fact:** In the last 1,000 captured Storport log entries for this controller, **388 read/write requests complete with `SRB_STATUS_NO_DEVICE`**: **26 reads and 362 writes**. The corresponding 388 build-I/O records have **no `HwStorStartIo` entries** in this retained span. Repeated completion/retry records are not counted as 388 distinct damaged files or SSD media failures. The class error history also records NoDevice, SCSI status 02 and sense 05/25/00.

**Confirmed fact:** The driver's captured hardware-device extension is `ffff958587f81010`; its state dword at offset `+0x18` is **`0x01000000`**. Bit 24 is set and bit 0 is clear. Disassembly of this dump's matching `stornvme.sys` shows:

1. `NVMeIsDeviceGone` reads the controller's 64-bit register at offset `0x28` through the pointer at hardware-extension offset `0xB0`.
2. When that read equals `0xFFFFFFFFFFFFFFFF`, it sets state bit 24 (`0x01000000`) and returns true.
3. Two additional explicit writes of this bit in `WaitForCommandCompleteWithCustomTimeout` are likewise guarded by an all-ones read of the same register.
4. `NVMeHwBuildIo` checks bit 0. The captured clear value takes the path that completes the request with NoDevice and sense 05/25/00 before NVMe command submission.

Microsoft identifies controller-register offset `0x28` as **ASQ, the Admin Submission Queue base-address register**. [Official register definition](https://learn.microsoft.com/en-us/windows/win32/api/nvme/ns-nvme-nvme_controller_registers).

**Supported inference:** Windows' NVMe driver detected loss of usable register access to the C: controller and retained its device-gone state. This directly supports a controller/access-path failure, substantially beyond the earlier inference from STATUS_IN_PAGE_ERROR alone. The controller being listed as Working/D0 by another structure does not prove it was successfully serving I/O.

**Limit:** The physical MMIO page is not captured, so the all-ones observation is reconstructed from the persistent driver flag and its verified setters; it is not a new direct hardware-register read. The failure storm overwrote the earlier ring history: all retained C: entries have timestamp 10:26:17.507. They do not identify the first instant the controller became inaccessible or the operation that initiated it. The evidence does not distinguish SSD-controller malfunction, PCIe/link or platform/power access loss, firmware behavior, or a software/state corruption problem. It does not prove defective NAND/media and does not justify a guaranteed SSD-replacement, slot-move, power-setting or driver-update claim.

Detailed storage evidence and logs are preserved under [storage-review](storage-review/FINDINGS.md). The matching-image full code disassembly is [nvme-code.txt](nvme-code.txt).

## Third dump and comparison

**Confirmed fact:** The readable copy is **3,986,198,179 bytes**, filesystem modification time **10:27:15 PDT**. WinDbg reports successful primary capture and 100% final progress. Internal crash time is **September 12, 2026 at 10:26:17.507 PDT**; uptime **5:13:20.350**. NBA process elapsed time is **4:06.920**, independently confirming Bryan's measured approximately 4:06.

| Attribute | First Native | Second Native | Third Native |
| --- | --- | --- | --- |
| Played-quarter length, user report | 5 minutes | 5 minutes | 1 minute |
| Reported crash point | Q2 first inbound, clock not yet advancing | Q2 about 12 seconds in, after brief pause/recovery | Q2 with 5 seconds remaining |
| NBA process runtime | 8:22.942 | 7:52.084 | 4:06.920 |
| Bugcheck | 0x154 | 0x154 | 0x154 |
| Original exception / lower status | c0000006 / c000000e | Same | Same, independently recovered |
| Immediate fault | RtlDecompressBufferLz4+0xb0 | Same | Same |
| Owning process of the thread attached to MemCompression | svchost.exe | FormlabsCrashHandler.exe | CastSrv.exe |

All three share failure bucket `0x154_c0000006_c000000e_nt!RtlDecompressBufferLz4` and hash `{f80368d8-3bea-7666-f736-c39e396bd15b}`. The exception is on a read of compressed source memory, not a reported LZ4 compressed-data validation error. The different owning processes are immediate memory consumers and are not implicated as initiators solely by these stacks.

```text
Bugcheck parameters:
  P1 ffff9585a2be3000
  P2 fffff3014007dd70
  P3 2
  P4 0
EXCEPTION_RECORD fffff3014007ed68
CONTEXT fffff3014007e580
ExceptionAddress fffff804dbfb1ba0 = nt!RtlDecompressBufferLz4+0xb0
ExceptionCode c0000006
Parameter[0] 0 (read)
Parameter[1] 00000187f8077d10
Parameter[2] c000000e
Faulting thread ffff9585c63e4080, PID/TID 65b0.8598
Owning process ffff9585ac5c3080, CastSrv.exe
Attached process ffff9585a2be5040, MemCompression
NBA process ffff9585ce54a080, PID ad94
```

**Limit:** The failed compressed-memory source lies in a private VAD, and physical page-table frame `6a92df` is missing from the bitmap dump. Its exact paging slot and request were not recovered. This remaining limit does not erase the separately recovered controller-state and real read/write failure evidence. Paging inventory again lists C: pagefile and swapfile, plus the virtual store. Available physical memory is 44,304,428 KiB and committed memory 34,309,416 KiB against a 133,717,824 KiB limit; total RAM/commit exhaustion is not shown.

**Supported inference:** Failure with shorter quarters at roughly half the prior launch-to-crash time strengthens a connection to game activity and weakens a fixed eight-minute runtime threshold. The point is now late in the second quarter, so an exact first-inbound/clock-start trigger is not reproduced. This cannot on its own identify the game operation that exposes the controller problem; earlier menu/idle failures remain part of the case.

## Separate failed write recovered from System

**Confirmed fact:** System thread `ffff9585be2ee040` was waiting for a csrss ALPC reply after `IopHardErrorThread` / `ExRaiseHardError`. Its recovered kernel packet at `ffff9585c48cac10` contains **`c0000222 STATUS_LOST_WRITEBEHIND_DATA`**, with filename:

`C:\Windows\System32\winevt\Logs\Microsoft-Windows-Hyper-V-VmSwitch-Operational.evtx`

This is a failed write to a Windows event-log file on C:, independently supporting broader C: I/O disruption during the incident. It is not evidence that Hyper-V or that event provider caused the controller failure. The earlier September 11 dump's failed PowerToys log writes likewise identify affected files, not necessarily initiators.

The System-thread capture completed. [System threads](system-threads.txt), [recovered frame/packet address](harderror.txt), and [packet status and filename](harderror-packet.txt). The first register-expression read used the default context rather than the displayed reconstructed frame; explicit packet-address reads in the final log recovered the valid data.

## Other evidence retained without causal attribution

PnP blackbox names the known SanDisk P: USB identity, with event time **10:22:25.9405049 PDT**, about 15.354 seconds after NBA process launch and 3:51.567 before the bugcheck. Problem code 24 and no event in progress are captured. This does not explain why C:'s NVMe registers became inaccessible. P: was not changed or used as the next reproduction target in this follow-up. NTFS blackbox again contains zero slow-I/O or oplock timeout records; that does not negate the storage log's actual failed requests.

## Verified-fix audit and remaining boundary

**Confirmed fact:** The publisher's actual NBA patch-note images for versions 1.2 through 1.5 were reviewed. No checked note identifies this MyNBA timing plus Windows in-page/NoDevice failure or provides a verified matching fix. The exact installed game patch remains unknown because the executable's normal version fields are blank. The downloaded third-party update archive was not executed. See [official-patch and local-build audit](../third-dump-game-review/FINDINGS.md).

Samsung's current listed 990 PRO firmware is still **8B2QJXD7**, already reported installed; earlier 7B2QJXD7 release notes discussed intermittent non-recognition and blue screens, but this does not establish recurrence of that defect on the current firmware. [Samsung firmware releases](https://semiconductor.samsung.com/consumer-storage/support/tools/).

ASUS lists **2202** as the current board BIOS; its notes do not identify a remedy for this captured NVMe condition. [ASUS BIOS releases](https://www.asus.com/us/supportonly/rog%20maximus%20z790%20dark%20hero/helpdesk_bios/).

A newer Windows build, KB5124008 / 26100.9445, is published, but its release notes do not establish a matching storage/controller fix. It was not installed or represented as a verified solution. [September Windows release notes](https://support.microsoft.com/en-us/servicing/os/windows-11/2026/09/kb5124008-windows-11-24h2-25h2-security-update).

**Open hypotheses:** The reason for C: controller-register access loss remains unresolved. Public release-note absence does not prove no software fix exists. A definite repair cannot be selected honestly from these captures alone. Further forced game crashes are not requested; the current deliverable is the newly substantiated fault localization and preserved evidence.

**Falsified as a sufficient fix:** Native rendering did not prevent any of these three failures. The prior Gen3 trial also did not prevent recurrence. The quarter-length change was a discriminator, not a proposed repair, and no stability benefit is claimed.

No diagnostic configuration, firmware, BIOS, power policy, game file, driver, service or physical connection was changed during this analysis.
