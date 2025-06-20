
# Step 2 — Create SD‑card Image

---

## Prerequisites

* SD card inserted into host machine
* Identify the device node for your SD card (e.g., `/dev/disk12` on macOS)
* Sufficient free space in your target folder (e.g., `~/Downloads`)

| Command                           | Purpose                                    |
| --------------------------------- | -------------------------------------------|
| `diskutil list`                   | List all disks and identify your SD card   |
| `diskutil unmountDisk /dev/diskN` | Unmount entire SD card (`N` = disk number) |

---

## 2.1 Dump the SD‑card to an image

1. Change to your working directory (e.g., `~/Downloads`):

   ```bash
   cd ~/Downloads
   ```

2. Run `dd` to create an uncompressed IMG file:

   ```bash
   sudo dd if=/dev/rdiskN of=./rpicfg_backup.img bs=4m conv=noerror,sync
   ```

   * Replace `N` with your disk number (found via `diskutil list`).
   * `bs=4m` speeds up the copy.
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

Continue with **[Clone image to SD-cards](clone_image.md)**.

---
