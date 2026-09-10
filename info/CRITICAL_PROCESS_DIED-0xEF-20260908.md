# DingleDerp game-triggered Windows crash investigation

**Case:** `CRITICAL_PROCESS_DIED-0xEF-20260908`  
**Status:** Unresolved  
**Evidence date:** 2026-09-10

This file records the decision boundary for future work. It does not assign a root cause.

## Current result and next evidence step (2026-09-10)

- **Confirmed fact (user report):** After the reported BIOS changes, Bryan played NBA 2K27 for approximately 15 minutes, then quit normally because he had to leave. He subsequently reported that the system crashed while NBA 2K27 was left idle. The idle duration and exact crash time have not been established.
- **Confirmed fact (fresh Windows event):** WER-SystemErrorReporting Event 1001, recorded at `2026-09-10 00:42:04.819` Pacific time, reports `0x0000001e` with arguments `0xffffffffc0000006`, `0xfffff80490e51c55`, `0xfffffe8276a5eca8`, `0xfffffe8276a5e4c0`. Report ID: `e6e32e2c-3956-476b-968a-5f06ec2663f7`. The first argument records `0xC0000006 STATUS_IN_PAGE_ERROR`. The event timestamp is not established as the instant of the crash. Captured event: [wer-event.json](dump-analysis-20260910/wer-event.json).
- **Confirmed fact (file metadata):** New dump files are present at the paths below. Their timestamps establish new artifacts; metadata alone does not verify their contents or successful completion.

| Artifact | Size in bytes | Last write, Pacific time |
| --- | ---: | --- |
| `E:\CrashDumps\MEMORY.DMP` | 5294552496 | 2026-09-10 00:41:54.764 |
| `E:\CrashDumps\Minidump\091026-13406-01.dmp` | 7702588 | 2026-09-10 00:42:04.815 |

- **Confirmed fact (analysis access limit):** The installed debugger could launch outside the sandbox, but opening either E: dump returned Win32 error 5, access denied. The RunAs attempt also failed with access denied. Computer-use access was unavailable after retry/reset. These are access failures, not evidence that either dump is corrupt.
- **Supported inference:** The combined configuration that included the reported Gen3 selection did not prevent the reported system crash. The new event again records an in-page exception, but the faulting process, function, backing file/device and lower I/O status have not been extracted from the new dump. Do not assume `Registry`, `nt!HvpGetCellPaged`, `csrss.exe`, `winsrvext.dll`, or lower status `0xC000000E` from earlier incidents.
- **Falsified as sufficient prevention:** The BIOS bundle as reported did not eliminate crashes. The successful 15-minute session was not a resolution. Physical slot mapping and the negotiated link speed at the later crash have not been directly verified, so this does not conclusively isolate Gen3 itself or exclude every storage-path hypothesis.
- **Current action:** Analyze the new full dump once a readable copy is available. The earlier longer-session validation plan and proposed Auto/Gen3 reversal are superseded; no additional reproduction or BIOS change is requested now. Keep the working dump configuration. There is no decision to keep C: at Gen3 permanently and no hardware diagnosis.

## Evidence classification before the new dump is analyzed

### Confirmed facts

- Three previously analyzed system crashes involve `0xC0000006 STATUS_IN_PAGE_ERROR`; the new 2026-09-10 WER event also records that exception code.
- The 2026-09-06 `0x1E` dump has lower I/O status `0xC000000E STATUS_NO_SUCH_DEVICE` in `nt!HvpGetCellPaged` while the `Registry` process was active.
- The two 2026-09-07 `0xEF` dumps terminate `csrss.exe` with exit status `0xC0000006` and share bucket `0xEF_csrss.exe_ntdll!RtlLookupFunctionEntry`.
- Both `0xEF` dumps reference the image-backed `winsrvext.dll` page at relative offset `0x23840` despite different ASLR bases. Their lower I/O status remains unextracted.
- The same `0xEF` signature recurred after SoftRAID, AOMEI backup filters, MacDrive, and Paragon APFS were removed.
- NBA 2K27 has reproduced the failure at its menu before gameplay. GPU utilization at that moment was not measured.
- Under the subsequently reported BIOS configuration, one approximately 15-minute NBA session ended normally; a later idle session crashed. These are separate observations.

### Supported inferences

- A failed in-page operation is a repeatable failure mechanism, but the initiating component is not identified.
- Game-specific or shared game-runtime paths deserve comparison because the workstation is reported stable under other demanding workloads.
- A kernel bitmap dump may omit user pages needed to recover the first `csrss.exe` exception; any dump conclusion must state that limitation.
- The first short post-change session did not establish a reproducible link-speed benefit. The later idle crash supersedes any suggestion that this session established a workaround.

### Open hypotheses

- A game, anti-cheat, input, overlay, graphics, virtualization, or Windows-build interaction.
- Memory, CPU/IMC settings, GPU, power, storage controller/link, physical media, paging, or image-section behavior.
- A repeatable failure to retrieve `winsrvext.dll + 0x23840` in the older `0xEF` dumps; this is not equivalent to proven on-disk corruption.
- A link-speed-dependent contribution involving the drive, M.2 slot, CPU path, firmware, signal integrity, power, or software timing. The current observations neither identify such a component nor establish Gen3 as adequate prevention.

### Falsified as sufficient causes

- SoftRAID drivers.
- AOMEI backup filter drivers.
- MacDrive `MDDISK` and `MDMOUNT` filters.
- Paragon APFS in combination with the removed MacDrive installation.

Their removal did not prevent recurrence. This does not prove they never contributed to earlier incidents.

## Historical test setup: combined BIOS changes including M.2_2 Gen3 (2026-09-09)

- **Confirmed fact (user report at that stage):** Bryan reported changing M.2_2 to Gen3 and disabling a soft-off power option. At the time of those screenshots, he had not yet run a game test and had limited troubleshooting time. These were settings changes, not a reported BIOS firmware update. Later game outcomes are recorded above.
- **Confirmed fact (screenshot evidence):** Image 3 shows the Save Changes & Reset confirmation listing the changes below. It establishes the selected before/after values; the still-open confirmation alone did not establish that they were saved or what link speed was negotiated after boot. Images 1 and 2 show the earlier Auto selection, not a failed Gen3 test.

| Setting | Before | Selected after |
| --- | --- | --- |
| M.2_2 Link Speed | Auto | Gen3 |
| USB power delivery in Soft Off state (S5) | Enabled | Disabled |
| LED lighting when in sleep, hibernate or soft-off states | All On | Aura Only |
| CPU Fan Profile | Standard | Turbo |
| Fast Boot (BIOS setting) | Enabled | Disabled |
| Profile Name | Empty | bb |
| Download & Install ARMOURY CRATE app | Enabled | Disabled |

- **Confirmed fact (manufacturer specification):** M.2_2 on the ROG MAXIMUS Z790 DARK HERO is a CPU-connected PCIe 4.0 x4 slot. [ASUS specifications](https://rog.asus.com/us/motherboards/rog-maximus/rog-maximus-z790-dark-hero/spec/)
- **Confirmed fact (power-state definition):** S5 is full shutdown; the working state is S0. The photographed USB option specifies S5, and the photographed Aura option specifies sleep/hibernate/soft-off lighting. These labels do not describe a fullscreen transition. [Microsoft system power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)
- **Confirmed fact (other photographed settings):** Image 4 shows PCI Express Native Power Management Enabled, Native ASPM Auto, PCH DMI Link ASPM Control Disabled, PCH ASPM Auto, L1 Substates Disabled, and SA DMI ASPM, DMI Gen3 ASPM and PEG ASPM Disabled. Image 5 shows Q-Code LED Function Auto and Alteration Mode Switch assigned to PCIE Link Speed. None establishes that a physical switch was operated or that further settings changed. These are observations, not additional changes to perform.
- **Open hypothesis tested:** The recurring crash depends on M.2_2 operating above Gen3. The benchmark comparison below supports C: being affected by the M.2_2 selection, while physical slot mapping and negotiated speeds have not been directly read. Multiple simultaneous changes prevent isolation of the Gen3 hypothesis.
- **Original prediction if correct:** Comparable NBA sessions would stop reproducing the failure at confirmed Gen3. Stability with accompanying changes would support only improvement under the combined configuration, not identify a responsible setting or component. Throughput, timing and cooling changes could affect reproduction.
- **Original prediction if wrong:** The failure could recur. A verified same-signature recurrence at confirmed Gen3 would show that the cap was insufficient prevention, without excluding every storage-path hypothesis. The new event must be analyzed before making that full comparison.
- **Risk and recorded rollback:** Reducing Gen4 to Gen3 lowers the slot's maximum transfer bandwidth. Reproduction can still cause a system crash and loss of unsaved work. Image 3 establishes Auto as the previous M.2_2 setting; the table preserves other prior values for any future individually planned reversal. No rollback is currently requested. [Intel PCIe transfer-rate reference](https://cdrdv2-public.intel.com/634648/634648-004.pdf)
- **Historical recommendations, now superseded:** A short 15–20-minute check was followed by proposed longer Gen3 sessions and a possible one-setting Auto comparison. The later idle crash ends that validation plan. Analyze the new dump before proposing another controlled change.

Screenshot sources: `C:\Users\PIZZAOVEN\.codex\attachments\7b83fcfe-8e9b-4f67-988b-11d593c5f560\image-1.jpg` through `image-5.jpg`; all five previously inspected.

## Samsung Magician benchmark comparison (reported 2026-09-09)

**Confirmed facts (two supplied benchmark screenshots):** All entries show a 1 GB test repeated six times. C: has a historical and a new result; E: has a new result. The E: screenshot identifies a Samsung SSD 990 PRO 2TB and lists sequential 128 KB/QD32/one thread, random 4 KB/QD32/16 threads. Equivalent detailed parameters are not visible in the C: history screenshot.

| Volume and reported configuration | Displayed date/time | Sequential read MB/s | Sequential write MB/s | Random read IOPS | Random write IOPS |
| --- | --- | ---: | ---: | ---: | ---: |
| C: before, reported Gen4 | 2026-09-07 19:48:28 | 6916 | 6418 | 1389404 | 784667 |
| C: after, reported Gen3 | 2026-09-09 03:55:40 | 3558 | 1420 | 849609 | 801269 |
| E: after, reported still Gen4 | 2026-09-09 04:04:54 | 7009 | 6827 | 1397949 | 1025390 |

- **Supported inference:** C: sequential read falling to roughly 51% of its earlier value is consistent with the Gen3 x4 bandwidth limit, while E: retains throughput consistent with Gen4. Together with the BIOS report, this supports C: being the drive affected by the M.2_2 limit. Throughput alone does not identify a physical slot or read negotiated link status. This is runtime evidence of a performance change, not crash-cause evidence.
- **Supported inference:** C: sequential write falls to roughly 22% of its earlier value. Halving the link bandwidth ceiling alone does not account for the full drop to 1420 MB/s. C: random write is approximately unchanged (about 2% higher); the results do not show every metric halving.
- **Open hypothesis:** The additional sequential-write reduction reflects an unmeasured test condition or another factor. Samsung states its write specifications use Intelligent TurboWrite and performance varies with system/firmware configuration; the screenshots do not establish cache exhaustion, temperature, background activity, media failure, or a connection to the bugchecks. [Samsung 990 PRO datasheet](https://download.semiconductor.samsung.com/resources/data-sheet/samsung_nvme_ssd_990_pro_datasheet_rev.2.0.pdf)
- **Confirmed fact (historical sequence):** No game outcome accompanied the benchmark screenshots at the time. The subsequent short successful session and later idle crash are now recorded above. A successful benchmark did not establish game stability; no additional benchmark is requested.

## Existing artifact-analysis plan

Prioritize the fresh full dump: recover the actual exception record and lower status; identify the faulting process/function; then, where captured structures permit, follow the failed virtual address to its backing file and device stack. Compare the result against the older `0x1E` and `0xEF` incidents. A backing volume identifies the affected read path, not necessarily the initiator. Do not substitute an older exception status when the new record is inaccessible.

For the older `csrss.exe` dumps, the unresolved question remains the first exception and lower I/O status behind the recursive user exception dispatch. The previously used `.exr -1` returned a bugcheck breakpoint and did not answer that question. Target a saved exception record if the captured pages contain it.

## Optional live-state evidence, deferred

The read-only game comparison collector remains available for a future targeted software comparison. It is not the current step, and no new game-running capture or crash reproduction is requested while the fresh dump awaits analysis.

The prior invocation was:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\PIZZAOVEN\Documents\GitHub\ComfyUI-311\script_examples\collect_game_crash_evidence.ps1" -Phase Baseline
```

Its documented output location is `C:\Users\PIZZAOVEN\Documents\CrashDiagnostics\GameComparison`; `-Phase GameRunning` identifies the comparison phase. The collector records processes, modules, drivers, services and targeted events without changing drivers, services, pagefile, dump settings or applications. Missing game processes and inaccessible queries must remain explicit limitations, not negative evidence. The prior script path has not been revalidated during the 2026-09-10 dump-access work.

## Change-test template

No machine change should be requested without recording:

1. **Hypothesis:** the single causal proposition under test.
2. **Correct-result prediction:** what should change if it is true.
3. **Wrong-result prediction:** what should remain or differ if it is false.
4. **Risk and rollback:** exact scope and reversal procedure.
5. **Evidence gap:** why existing dumps and captures cannot already decide it.

Do not infer SSD failure from `STATUS_IN_PAGE_ERROR`, request a full C: backup for a read-only query, move hardware without direct evidence and agreement, or remove additional software merely because it appears in an inventory.
