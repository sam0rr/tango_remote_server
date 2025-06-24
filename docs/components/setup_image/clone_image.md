
# Step 3 — Flash Image to New SD Cards

---

## Prerequisites

* SD card inserted into host machine
* Identify the device node for your SD card

  * **Linux**: `/dev/sdX` (e.g., `/dev/sdb`)
  * **macOS**: `/dev/diskN` (e.g., `/dev/disk2`)
* Sufficient free space in your target folder (e.g., `~/Downloads`)

### Linux:

| Command                    | Purpose                              |
| -------------------------- | ------------------------------------ |
| `lsblk` or `sudo fdisk -l` | List disks and identify your SD card |
| `sudo umount /dev/sdX*`    | Unmount all SD card partitions       |

### macOS:

| Command                           | Purpose                                    |
| --------------------------------- | ------------------------------------------ |
| `diskutil list`                   | List disks and identify your SD card       |
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

#### Linux:

```bash
sudo umount /dev/sdX*
```

#### macOS:

```bash
diskutil unmountDisk /dev/diskN
```

---

### 3.3 Write the image to the SD card

#### Linux:

```bash
cd ~/Downloads
sudo dd if=./rpicfg_backup.img of=/dev/sdX bs=4M conv=noerror,sync status=progress
```

#### macOS:

```bash
cd ~/Downloads
sudo dd if=./rpicfg_backup.img of=/dev/rdiskN bs=4m conv=noerror,sync
```

---

### 3.4 One-liner (decompress & write)

#### Linux:

```bash
gunzip -c ~/Downloads/rpicfg_backup.img.gz | sudo dd of=/dev/sdX bs=4M conv=noerror,sync status=progress
```

#### macOS:

```bash
gunzip -c ~/Downloads/rpicfg_backup.img.gz | sudo dd of=/dev/rdiskN bs=4m conv=noerror,sync
```

---

### 3.5 Eject the SD card

#### Linux:

```bash
sudo eject /dev/sdX
```

#### macOS:

```bash
diskutil eject /dev/diskN
```

---

Continue with **[first boot on a new SD-card](first_boot_image.md)**.

---
