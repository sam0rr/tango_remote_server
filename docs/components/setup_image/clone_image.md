
# Step 3 — Flash Image to New SD Cards

---

## Prerequisites

* Blank SD card inserted into host machine
* Identify the device node for your SD card (e.g., `/dev/disk13` on macOS)
* Sufficient free space in your SD-card

| Command                           | Purpose                                    |
| --------------------------------- | ------------------------------------------ |
| `diskutil list`                   | List all disks and identify your SD card   |
| `diskutil unmountDisk /dev/diskN` | Unmount entire SD card (`N` = disk number) |

---

## Option A — BalenaEtcher (GUI)

1. Open **BalenaEtcher**.
2. Select `rpicfg_backup.img.gz`.
3. Choose your SD card from the list.
4. Click **Flash** and wait for confirmation.

---

## Option B — Command-line (no Etcher)

### 3.1 Decompress the image (if gzipped)

```bash
# keep original .gz file
gunzip -k ~/Downloads/rpicfg_backup.img.gz
```

---

### 3.2 Unmount the target disk

```bash
# macOS
diskutil unmountDisk /dev/diskN
```

---

### 3.3 Write the image to the SD card

```bash
cd ~/Downloads
sudo dd if=./rpicfg_backup.img of=/dev/rdiskN bs=4m conv=noerror,sync
```

---

### 3.4 One-liner (decompress & write)

```bash
gunzip -c ~/Downloads/rpicfg_backup.img.gz | sudo dd of=/dev/rdiskN bs=4m conv=noerror,sync
```

---

### 3.5 Eject the SD card

```bash
# macOS
diskutil eject /dev/diskN
```

---

Continue with **[first boot on a new SD-card](first_boot_image.md)**.

---

