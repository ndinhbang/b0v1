## Install QEMU manually

Docker Desktop supports running and building multi-platform images under emulation by default. No configuration is necessary as the builder uses the QEMU that's bundled within the Docker Desktop VM.

If you're using a builder outside of Docker Desktop, such as if you're using Docker Engine on Linux, or a custom remote builder, you need to install QEMU and register the executable types on the host OS. The prerequisites for installing QEMU are:

- Linux kernel version 4.8 or later
- `binfmt-support` version 2.1.7 or later
- The QEMU binaries must be statically compiled and registered with the `fix_binary` flag

Use the [`tonistiigi/binfmt`](https://github.com/tonistiigi/binfmt) image to install QEMU and register the executable types on the host with a single command:

```
docker run --privileged --rm tonistiigi/binfmt --uninstall qemu-*
docker run --privileged --rm tonistiigi/binfmt --install all
```

This installs the QEMU binaries and registers them with [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc), enabling QEMU to execute non-native file formats for emulation.

To check if QEMU is installed correctly, you can run:

```
ls -al /proc/sys/fs/binfmt_misc/
```

Expected output should include entries like `qemu-aarch64`, `qemu-arm`, `qemu-ppc64le`, etc.:

```
drwxr-xr-x 2 root root 0 Dec 12 21:31 ./
dr-xr-xr-x 1 root root 0 Dec 12 20:39 ../
-rw-r--r-- 1 root root 0 Dec 12 21:31 python3.11
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-aarch64
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-arm
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-loongarch64
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-mips64
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-mips64el
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-ppc64le
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-riscv64
-rw-r--r-- 1 root root 0 Dec 12 21:32 qemu-s390x
--w------- 1 root root 0 Dec 12 21:31 register
-rw-r--r-- 1 root root 0 Dec 12 20:39 status
-rw-r--r-- 1 root root 0 Dec 12 21:31 WSLInterop-late
```

Once QEMU is installed and the executable types are registered on the host OS, they work transparently inside containers. You can verify your registration by checking if `F` is among the flags in `/proc/sys/fs/binfmt_misc/qemu-*`.

For example, to check the handler for the ARM 64-bit architecture (aarch64), read the content of the corresponding virtual file:

```
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
```
Expected output:

```
enabled
interpreter /usr/bin/qemu-aarch64
flags: POCF
offset 0
magic 7f454c460201010000000000000000000200b700
mask ffffffffffffff00fffffffffffffffffeffffff
```

  * `enabled`: Indicates the handler is active.
  * `interpreter`: Points to the program the kernel will call to run the binary file (which is the static QEMU binary).
  * `magic` and `mask`: These are the specific byte sequences (magic bytes) the kernel uses to identify that the binary file belongs to the ARM64 architecture, triggering the QEMU emulation.

If you see these entries listed and `enabled` after running the command, it means the multi-architecture build feature has been successfully set up.

### Test current emulation support

You can test if the emulation is working by running a container for a different architecture. For example, to run an ARM64 container on an x86_64 host:

```
docker run --rm --platform linux/arm64 alpine uname -a
docker run --rm --platform linux/arm/v7 alpine uname -a
docker run --rm --platform linux/ppc64le alpine uname -a
docker run --rm --platform linux/s390x alpine uname -a
docker run --rm --platform linux/riscv64 alpine uname -a
```
Expected output for the ARM64 container:

```
Linux 20b9df4ab610 6.6.87.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun  5 18:30:46 UTC 2025 aarch64 Linux
```

-----

## 🛠️ Automating QEMU Registration on WSL

If you restart WSL 2 (or your entire Windows system), the QEMU registration will be lost, and you'll need to run the registration command again. To avoid this inconvenience, you can automate the registration process to run at startup.

-----

### I. Automating QEMU Registration at Startup

To ensure a stable Docker daemon and persistent QEMU handler registration, you should enable `systemd` and create a dedicated service.

#### Step 1: Enable Systemd (If not already done)

This is a prerequisite for automatic service management on modern Linux distributions like Debian.

1.  Open your Debian WSL 2 terminal.
2.  Use an editor to open the WSL configuration file:
    ```
    sudo nano /etc/wsl.conf
    ```
3.  Add or ensure the following content is present (case sensitivity is important):
    ```ini
    [boot]
    systemd=true
    ```
4.  Save and exit the editor.
5.  **Crucial:** Restart the WSL 2 session to apply this change.

    ```powershell
    wsl --shutdown
    wsl
    ```

#### Step 2: Create a Systemd Service for QEMU Registration

We will create a new service file to run the Docker command after the Docker daemon has started.

1.  Create the service file in the `systemd` configuration directory:
    ```bash
    sudo nano /etc/systemd/system/qemu-binfmt-register.service
    ```
2.  Paste the following content into the file (This standard unit file ensures your command runs with privileged access and depends on the Docker service):
    ```ini
    [Unit]
    Description=Register QEMU binfmt handlers for multiarch Docker builds
    Requires=docker.service
    After=docker.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/bin/docker run --privileged --rm tonistiigi/binfmt --install all

    [Install]
    WantedBy=multi-user.target
    ```
3.  Save and exit.

#### Step 3: Enable and Start the Service

1.  Reload the `systemd` configuration to recognize the new service:
    ```bash
    sudo systemctl daemon-reload
    ```
2.  Enable the service so it automatically runs when Debian starts up:
    ```bash
    sudo systemctl enable qemu-binfmt-register.service
    ```
3.  Start the service immediately:
    ```bash
    sudo systemctl start qemu-binfmt-register.service
    ```

**Verification:** After running, you can check the service status:

```bash
sudo systemctl status qemu-binfmt-register.service
```

The status should show as `active (exited)`. Now, whenever you restart WSL (by running `wsl --shutdown` on Windows), the QEMU registration command will be executed automatically.

## References
- [Docker Documentation: Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
