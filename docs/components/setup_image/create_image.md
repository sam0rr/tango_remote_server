
# Step 2 — Create SD‑card Image

---

## Prerequisites

* SD card inserted into host machine
* Identify the device node for your SD card

  * **Linux**: `/dev/sdX` (e.g., `/dev/sdb`)
  * **macOS**: `/dev/diskN` (e.g., `/dev/disk2`)
* Sufficient free space in your target folder (e.g., `~/Downloads`)

### Linux:

| Command                           | Purpose                                    |
| ----------------------------------| -------------------------------------------|
| `lsblk` or `sudo fdisk -l`        | List disks and identify your SD card       |
| `sudo umount /dev/sdX*`           | Unmount entire SD card (`X` = disk number) |

### macOS:

| Command                           | Purpose                                    |
| ----------------------------------| -------------------------------------------|
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
   sudo dd if=/dev/sdX of=./rpicfg_backup.img bs=4M conv=noerror,sync,sparse status=progress
   ```

   * Replace `X` with your device letter (e.g., `b` for `/dev/sdb`).
   * `bs=4M` improves copy speed.
   * `conv=noerror,sync` continues on read errors and pads blocks.
   * `conv=sparse` punches holes for zero blocks to save space.
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

## 2.2 Shrink and compress the image with ArmbianShrink

Shrink the image to its minimal size and compress it safely using **ArmbianShrink**, a lightweight tool designed for GPT-based systems like Armbian, Radxa, and Orange Pi.

### Requirements

* macOS or Linux
* Internet access to download `armbianshrink.sh`
* Sufficient free space (at least 2× the image size)

1. **Download and install ArmbianShrink** (if not already installed):

   ```bash
   curl -L https://raw.githubusercontent.com/dedalodaelus/ArmbianShrink/master/armbianshrink.sh \
     -o armbianshrink.sh
   chmod +x armbianshrink.sh
   sudo mv armbianshrink.sh /usr/local/bin/
   ```

2. **Run ArmbianShrink** from your working directory (e.g., `~/Downloads`):

   ```bash
   cd ~/Downloads
   sudo armbianshrink.sh -Z rpicfg_backup.img rpicfg_backup_shrunk.img
   ```

   **Options used:**

   * `-Z`: Shrinks the filesystem **and** compresses to `.xz`

   This script will:

   * Run a filesystem check (`e2fsck`)
   * Shrink the root filesystem to its minimal size
   * Truncate the image file
   * Compress the result to `rpicfg_backup_shrunk.img.xz`

3. **Result**

   The final output will be:

   ```bash
   ~/Downloads/rpicfg_backup_shrunk.img.xz
   ```

   You can now safely store or distribute this file.

---

## 2.3 Save the image for persistence

After compression, move or copy the `.img.gz` to a safe, persistent location:

* **OneDrive (or other cloud)**
* **External drive**

Ensure the destination has sufficient space and persistence.

---

Continue with **[Clone image to SD-cards](clone_image.md)**.

---
