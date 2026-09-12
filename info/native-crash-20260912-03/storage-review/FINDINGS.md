# Offline storage review of Native-20260912-03.dmp

Analyzed September 12, 2026. This review used the preserved dump only. No device, driver, power, BIOS, game or capture settings were changed.

## Direct localization of the storage failure

**Confirmed fact:** `!storagekd.storclass ffff95858d2dc050 2` identifies the boot/paging disk as Samsung SSD 990 PRO 2TB, firmware `8B2QJXD7`, serial `0025_3842_3141_8E54.`. This is the recorded C: physical SSD, independently distinguishing it from the second 990 PRO.

```text
Class FDO:        ffff95858d2dc050
Class extension:  ffff95858d2dc1a0
Physical DO:      ffff958587fb9050
Storport adapter: ffff958587f7c050
Adapter extension:ffff958587f7c1a0
Miniport:         stornvme
Miniport HwDeviceExt: ffff958587f81010
PCI bus/slot reported by storadapter: 2 / 0
```

**Confirmed fact:** The class driver's retained last 16 failed requests all show WRITE(10), SrbStatus `08`, SCSI status `02`, sense bytes `05 25 00`, and decoded time `10:26:17.507`. Microsoft documents SrbStatus 08 as `SRB_STATUS_NO_DEVICE`. [STORAGE_REQUEST_BLOCK reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/srb/ns-srb-_storage_request_block).

**Confirmed fact:** The last 1,000 retained Storport log entries for this C: adapter contain 388 `HwStorBuildIo` records and 388 `SpNotifyReqComplete` records with `No device`, including 26 READ(10) and 362 WRITE(10) completions. There are zero `HwStorStartIo` entries in that retained span. The remaining entries are adapter pause/resume bookkeeping. All 1,000 decoded timestamps are `10:26:17.507`; the failure onset and preceding successful operation are outside this retained span. Total log entries written was 39,841,946. See [pass4.txt](pass4.txt).

**Limit:** This counter/history does not establish that 388 different files failed, because class retry packets and SRBs can be reused. It also does not provide the earlier operation that triggered the controller state change.

## Why the miniport is rejecting those requests

**Confirmed fact:** The loaded stornvme image, with matching public symbols, contains this behavior in `NVMeHwBuildIo`:

```text
fffff804`6f0f136e mov eax,dword ptr [rdi+18h]
fffff804`6f0f137e test al,1
fffff804`6f0f1380 je NVMeHwBuildIo+0xf4
...
fffff804`6f0f13c6 mov byte ptr [rbx+3],8
... construct sense 05/25/00, SCSI status 02 ...
... StorPortNotification(RequestComplete), return false ...
```

At capture, `[C_HwDeviceExt+18h] = 01000000`. Its bit 0 is clear, so this state selects the immediate no-device completion before the normal SCSI-to-NVMe translation and start-I/O path. The observed log sequence and returned statuses agree with this code path. See [pass5.txt](pass5.txt) and [pass6.txt](pass6.txt).

**Confirmed fact:** `stornvme!NVMeIsDeviceGone` reads the qword controller register at offset `28h` through the MMIO pointer at `[HwDeviceExt+B0h]`. If that register read is `FFFFFFFFFFFFFFFF`, it sets bit 24 (`01000000`) at `[HwDeviceExt+18h]` and returns true:

```text
fffff804`6f101dd0 mov rax,qword ptr [rcx+0B0h]
fffff804`6f101dd8 mov rax,qword ptr [rax+28h]
fffff804`6f101ddc cmp rax,0FFFFFFFFFFFFFFFFh
fffff804`6f101de0 jne return_false
fffff804`6f101de2 or dword ptr [rcx+18h],1000000h
```

The same bit is set by two paths in `WaitForCommandCompleteWithCustomTimeout`; both were independently checked and both use that same MMIO qword register read and all-ones comparison. The parent analysis scanned the loaded image's executable sections and found these three immediate OR writers. That scan is not proof against arbitrary memory corruption, indirect writes, or every possible state-copy operation.

Microsoft's register layout identifies offset 28h as **ASQ, Admin Submission Queue Base Address**. It is not a NAND media-error counter. [NVME_CONTROLLER_REGISTERS](https://learn.microsoft.com/en-us/windows/win32/api/nvme/ns-nvme-nvme_controller_registers).

**Confirmed fact:** The second 990 PRO and SPCC controller extensions have state value `00000201` at offset 18h (bits 0 and 9 set, bit 24 clear). The failed C: adapter has `01000000` (bit 24 set, bits 0 and 9 clear). Their retained logs contain successful I/O. See [pass3.txt](pass3.txt) and [pass9.txt](pass9.txt).

**Supported inference:** The C: NVMe driver recorded its device-gone condition, consistent with losing valid access to the controller's MMIO register, and was rejecting ordinary reads/writes as no-device. This directly localizes a failure to the C: NVMe/controller access path, beyond the generic in-page status. The finding is consistent with the critical paging failure and concurrent C: write failures the parent analysis is tracing.

**Limit:** The MMIO backing page at physical `70700` was not captured in the bitmap dump. Its contents could not be re-read offline. The retained state and driver code support the inference; the dump does not directly show a current hardware register value. Public stornvme type names for the state bits are unavailable, so offsets and behavior are reported instead of inventing private field names.

**Open hypotheses:** The initiating cause of the C: controller access loss could lie in the SSD controller/firmware, PCIe link or platform power handling, Windows/driver behavior, or corrupted state/address translation. This review does not discriminate among them and does not prove defective flash media or a replacement SSD as a guaranteed fix. The mere presence of adapter power pause/resume records is insufficient to blame power management: functioning adapters also have those records.

## Additional retained state

**Confirmed fact:** Storport still labels all four internal units and their adapters `Working`. The C: unit is not frozen, has no queued unit requests, and reports one outstanding request that the extension could not find on its lists, possibly captured during a list transfer. These administrative states do not negate the explicit no-device completions.

The class transfer packet engine retains a queued read of `\Windows\System32\winsrvext.dll`: upper IRP `ffff9585c4a2a010`, lower IRP `ffff9585afc1fde0`, SRB `ffff9585a8628860`, READ(10), 4096 bytes, LBA `135df600`. This request itself remains pending with SRB status 0, so it is not labeled a completed failed read. Other queued requests include `$UsnJrnl:$J` and `$BitMap`.

`!storpagingdevice` identifies the boot/paging miniport as stornvme and model/firmware above; its `PagingPathCount: 4` is not evidence of four paging disks. `!storwheaerror` has zero/unknown details and no flags. `!blackboxntfs` has zero slow-I/O and oplock timeout records; neither finding rules out the established storage failure.

PnP blackbox identifies SanDisk USB `VID_0781&PID_55AE` / serial `2343GD400848`, with FILETIME `134337073459405049` = September 12, 10:22:25.9405049 PDT. This is 3 minutes 51.567 seconds before the internal bugcheck time. No PnP event is in progress. It is a retained P: device event, not evidence that P: initiated the independently localized C: controller failure.

## Artifacts

- [Device and PnP inventory](pass1.txt)
- [Boot/paging identification and extension help](pass2.txt): the last `!object` lookup stalled and the session was stopped; earlier command output was captured.
- [C: request failures and adapter comparison](pass3.txt)
- [Last 1,000 C: requests and queued winsrvext read](pass4.txt)
- [NVMeHwBuildIo disassembly](pass5.txt)
- [Controller state and reset code](pass6.txt)
- [Remove/stop/power paths](pass7.txt)
- [Initialization, reset, and state reads](pass8.txt)
- [Device-gone detection and working-controller flags](pass9.txt)
- [Two additional bit-24 writers](pass10.txt); their incoming branches were verified in the parent's `../nvme-code.txt` at lines around 6356 and 6411.
