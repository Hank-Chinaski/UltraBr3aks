# DingleDerp game-triggered Windows crash investigation

**Case:** `CRITICAL_PROCESS_DIED-0xEF-20260908`  
**Status:** Unresolved  
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
**Evidence date:** 2026-09-09
=======
**Evidence date:** 2026-09-08
>>>>>>> theirs
=======
**Evidence date:** 2026-09-08
>>>>>>> theirs
=======
**Evidence date:** 2026-09-08
>>>>>>> theirs
=======
**Evidence date:** 2026-09-08
>>>>>>> theirs
=======
**Evidence date:** 2026-09-08
>>>>>>> theirs

This file records the decision boundary for future work. It intentionally does not assign a root cause.

## Evidence classification

### Confirmed facts

- Three analyzed system crashes involve `0xC0000006 STATUS_IN_PAGE_ERROR`.
- The 2026-09-06 `0x1E` dump has lower I/O status `0xC000000E STATUS_NO_SUCH_DEVICE` in `nt!HvpGetCellPaged` while the `Registry` process was active.
- The two later `0xEF` dumps terminate `csrss.exe` with exit status `0xC0000006` and share bucket `0xEF_csrss.exe_ntdll!RtlLookupFunctionEntry`.
- Both `0xEF` dumps reference the image-backed `winsrvext.dll` page at relative offset `0x23840` despite different ASLR bases.
- The same `0xEF` signature recurred after SoftRAID, AOMEI backup filters, MacDrive, and Paragon APFS were removed.
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
- NBA 2K27 can reproduce the failure at its menu before gameplay. GPU utilization at that moment was not measured.
=======
- NBA 2K27 can reproduce the failure at its menu, so maximum gameplay load is not required.
>>>>>>> theirs
=======
- NBA 2K27 can reproduce the failure at its menu, so maximum gameplay load is not required.
>>>>>>> theirs
=======
- NBA 2K27 can reproduce the failure at its menu, so maximum gameplay load is not required.
>>>>>>> theirs
=======
- NBA 2K27 can reproduce the failure at its menu, so maximum gameplay load is not required.
>>>>>>> theirs
=======
- NBA 2K27 can reproduce the failure at its menu, so maximum gameplay load is not required.
>>>>>>> theirs

### Supported inferences

- A failed in-page operation is the repeatable failure mechanism, but the component initiating it is not identified.
- Game-specific or shared game-runtime paths deserve comparison because the workstation is reported stable under other demanding workloads.
- A kernel bitmap dump may omit user pages needed to recover the first `csrss.exe` exception; any dump conclusion must state that limitation.

### Open hypotheses

- A game, anti-cheat, input, overlay, graphics, virtualization, or Windows-build interaction.
- Memory, CPU/IMC settings, GPU, power, storage controller/link, physical media, paging, or image-section behavior.
- A repeatable failure to retrieve `winsrvext.dll + 0x23840`; this is not equivalent to proven on-disk corruption.

### Falsified as sufficient causes

- SoftRAID drivers.
- AOMEI backup filter drivers.
- MacDrive `MDDISK` and `MDMOUNT` filters.
- Paragon APFS in combination with the removed MacDrive installation.

<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
<<<<<<< ours
## Current test: combined BIOS changes including M.2_2 Gen3 (2026-09-09)

- **Confirmed fact (user report):** Bryan reports changing M.2_2 to Gen3 and disabling a soft-off power option. He explicitly reports that no game test has run yet and has limited time for further troubleshooting. These are settings changes, not a reported BIOS firmware update.
- **Confirmed fact (screenshot evidence):** Image 3 shows the Save Changes & Reset confirmation listing the changes below. It establishes the before/after values selected in BIOS, but the still-open confirmation is not itself evidence of saving them or of the negotiated speed after boot. Images 1 and 2 show the earlier Auto selection, not a failed Gen3 test.

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
- **Confirmed fact (other photographed settings):** Image 4 shows PCI Express Native Power Management Enabled, Native ASPM Auto, PCH DMI Link ASPM Control Disabled, PCH ASPM Auto, L1 Substates Disabled, and SA DMI ASPM, DMI Gen3 ASPM and PEG ASPM Disabled. Image 5 shows Q-Code LED Function Auto and Alteration Mode Switch assigned to PCIE Link Speed. None is evidence that a physical switch was operated or that further settings changed. These are observations, not additional changes to perform.
- **Open hypothesis:** The recurring crash depends on the M.2_2 link operating above Gen3. The subsequent benchmark comparison below supports C: being affected by the M.2_2 setting, while physical slot mapping and negotiated speeds have not been directly read. Multiple selected changes mean the next run cannot isolate the Gen3 hypothesis.
- **Correct-result prediction:** If the link previously operated above Gen3 and this dependency causes the crashes, comparable NBA sessions should stop reproducing the same failure at confirmed Gen3. With the accompanying changes, stability supports only an improvement under the combined configuration; it cannot identify the responsible setting or component. One successful session is preliminary. Throughput, timing and cooling changes can alter reproduction.
- **Wrong-result prediction:** The same failure may recur. Recurrence at confirmed Gen3 would falsify the speed cap as a sufficient prevention measure, without excluding every storage-path hypothesis. An unchanged negotiated speed would make this an ineffective comparison.
- **Risk and rollback:** Reducing Gen4 to Gen3 lowers the slot's maximum transfer bandwidth. Another reproduction can still cause a system crash and loss of unsaved work. Image 3 now establishes Auto as the previous M.2_2 setting; the table preserves the other previous values for a future individually planned reversal. No rollback or further BIOS/hardware change is requested now. [Intel PCIe transfer-rate reference](https://cdrdv2-public.intel.com/634648/634648-004.pdf)
- **Evidence gap and immediate recommendation:** Existing dumps do not establish a dependence on negotiated link speed, and the current configuration has not been tested. After the selected settings are saved and Windows has booted, save open work and run NBA 2K27 in its usual configuration for up to 15-20 minutes, or until the first failure. This is a practical check against the earlier roughly five-minute reproductions, not a stability certification. Record elapsed runtime, menu/gameplay context and any recurrence. If a crash occurs, allow its dump to finish and stop further repetitions; compare its actual dump signature later. A frozen frame alone cannot establish that it is the same failure. No new collector run or BIOS change is a prerequisite for this short check.

Screenshot sources: `C:\Users\PIZZAOVEN\.codex\attachments\7b83fcfe-8e9b-4f67-988b-11d593c5f560\image-1.jpg` through `image-5.jpg`; all five inspected.

## Samsung Magician benchmark comparison (reported 2026-09-09)

**Confirmed facts (two supplied benchmark screenshots):** All entries show a 1 GB test repeated six times. C: has a historical and a new result; E: has a new result. The E: screenshot identifies a Samsung SSD 990 PRO 2TB and lists sequential 128 KB/QD32/one thread, random 4 KB/QD32/16 threads. Equivalent detailed parameters are not visible in the C: history screenshot.

| Volume and reported configuration | Displayed date/time | Sequential read MB/s | Sequential write MB/s | Random read IOPS | Random write IOPS |
| --- | --- | ---: | ---: | ---: | ---: |
| C: before, reported Gen4 | 2026-09-07 19:48:28 | 6916 | 6418 | 1389404 | 784667 |
| C: after, reported Gen3 | 2026-09-09 03:55:40 | 3558 | 1420 | 849609 | 801269 |
| E: after, reported still Gen4 | 2026-09-09 04:04:54 | 7009 | 6827 | 1397949 | 1025390 |

- **Supported inference:** C: sequential read falling to roughly 51% of its earlier value is consistent with the Gen3 x4 bandwidth limit, while E: retains throughput consistent with Gen4. Together with the BIOS change report, this supports C: being the drive affected by the M.2_2 limit. Benchmark throughput alone does not directly identify a physical slot or read negotiated link status. This is new runtime evidence of a performance change; it is not crash-cause evidence.
- **Supported inference:** C: sequential write falls to roughly 22% of its earlier value. Halving the link bandwidth ceiling alone does not account for the full drop to 1420 MB/s. C: random write is approximately unchanged (about 2% higher); the results do not show every metric halving.
- **Open hypothesis:** The additional sequential-write reduction reflects an unmeasured test condition or another factor. Samsung states its write specifications use Intelligent TurboWrite and performance varies with system/firmware configuration; the screenshots do not establish cache exhaustion, temperature, background activity, media failure, or a connection to the bugchecks. [Samsung 990 PRO datasheet](https://download.semiconductor.samsung.com/resources/data-sheet/samsung_nvme_ssd_990_pro_datasheet_rev.2.0.pdf)
- **Confirmed fact (case state):** No post-change NBA result is supplied with these benchmarks. The next useful result remains the short NBA run already described; no additional benchmark, BIOS change or repair is requested. A successful storage benchmark does not establish game stability.

## Existing artifact-analysis plan
=======
## Next evidence step
>>>>>>> theirs
=======
## Next evidence step
>>>>>>> theirs
=======
## Next evidence step
>>>>>>> theirs
=======
## Next evidence step
>>>>>>> theirs
=======
## Next evidence step
>>>>>>> theirs

Prefer direct analysis of the preserved dumps. If they are not available in this repository, collect one live-state baseline and one game-running snapshot with the read-only collector:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\PIZZAOVEN\Documents\GitHub\ComfyUI-311\script_examples\collect_game_crash_evidence.ps1" -Phase Baseline
```

Run the same command with `-Phase GameRunning` while NBA 2K27 is at its menu. The script writes only beneath `C:\Users\PIZZAOVEN\Documents\CrashDiagnostics\GameComparison` and does not alter drivers, services, the pagefile, dump settings, or applications.

The comparison is intended to identify game-only processes, loaded modules, drivers, services, and contemporaneous events before selecting a controlled change. A missing game process or access-denied module query is explicitly logged rather than treated as negative evidence.

## Change-test template

No machine change should be requested without recording:

1. **Hypothesis:** the single causal proposition under test.
2. **Correct-result prediction:** what should change if it is true.
3. **Wrong-result prediction:** what should remain or differ if it is false.
4. **Risk and rollback:** exact scope and reversal procedure.
5. **Evidence gap:** why existing dumps and captures cannot already decide it.

Do not infer SSD failure from `STATUS_IN_PAGE_ERROR`, request a full C: backup for a read-only query, move hardware without direct evidence and agreement, or remove additional software merely because it appears in an inventory.
