
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

## 2.2 Shrink and compress the image with PiShrink

Safely shrink the image to its minimal size and compress it using xz via PiShrink. This method produces a significantly smaller file (only of what is actually used).

### Requirements

* Docker installed
* Internet access to clone the PiShrink repository
* Sufficient free space (at least 2× the size of the image)

1. **Clone the PiShrink repository and build the Docker image:**

   ```bash
   cd ~/Downloads
   git clone https://github.com/drewsif/pishrink.git
   cd pishrink
   docker build -t local-pishrink .
   ```

   The official repository already contains a working `Dockerfile`. The build process takes less than a minute.

2. **Move your `.img` file into the PiShrink folder:**

   ```bash
   mv ~/Downloads/rpicfg_backup.img ~/Downloads/pishrink/
   ```

3. **Run PiShrink via Docker to shrink and compress:**

   ```bash
   cd ~/Downloads/pishrink
   docker run --rm --privileged \
     -v "$PWD":/mnt \
     local-pishrink \
     -avZd /mnt/rpicfg_backup.img /mnt/rpicfg_backup-shrunk.img
   ```

   * `-a`: enables advanced features and optimizations
   * `-v`: verbose output
   * `-Z`: compress with xz (best compression ratio)
   * `-d`: maximum verbosity with debugging information

   This step will:

   * Fix any filesystem issues (`e2fsck`)
   * Resize the partition
   * Zero free space
   * Compress the result as `.xz`

4. **Result**

   The final output will be:

   ```bash
   ~/Downloads/pishrink/rpicfg_backup-shrunk.img.xz
   ```

   You can now safely store or distribute this file.

---

## 2.3 Save the image for persistence

After compression, move or copy the `.img.gz` to a safe, persistent location (reliable):

* **OneDrive (or other cloud)**
* **External drive**

Ensure the destination has sufficient space and persistence.

---

Continue with **[Clone image to SD-cards](clone_image.md)**.

---
