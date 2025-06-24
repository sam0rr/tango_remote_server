
# Step 2 — Create SD‑card Image

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

## 2.1 Dump the SD‑card to an image

1. Change to your working directory (e.g., `~/Downloads`):

   ```bash
   cd ~/Downloads
   ```

2. Run `dd` to create an uncompressed IMG file:

   ### Linux:

   ```bash
   sudo dd if=/dev/sdX of=./rpicfg_backup.img bs=4M conv=noerror,sync status=progress
   ```

   * Replace `X` with your device letter (e.g., `b` for `/dev/sdb`).
   * `bs=4M` improves copy speed.
   * `conv=noerror,sync` continues on read errors and pads blocks.
   * `status=progress` displays real-time progress.

   ### macOS:

   ```bash
   sudo dd if=/dev/rdiskN of=./rpicfg_backup.img bs=4m conv=noerror,sync
   ```

   * Replace `N` with your disk number (found via `diskutil list`).
   * `rdiskN` uses the raw device for faster I/O.
   * `bs=4m` improves copy speed.
   * `conv=noerror,sync` continues on read errors and pads blocks.

3. Wait for `dd` to finish. You’ll see a summary of bytes transferred.

---

## 2.2 Compress the image

1. Still in `~/Downloads`, compress with maximum gzip compression:

   ```bash
   gzip -9 rpicfg_backup.img
   ```

2. Wait for compression to finish. The result will be `rpicfg_backup.img.gz`.

---

## 2.3 Save the image for persistence

After compression, move or copy the `.img.gz` to a safe, persistent location:

* **OneDrive (or other cloud)**
* **External drive**

Ensure the destination has sufficient space and persistence.

---

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
