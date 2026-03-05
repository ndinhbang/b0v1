## Cài đặt QEMU thủ công

Docker Desktop hỗ trợ chạy và xây dựng các image đa nền tảng dưới chế độ mô phỏng theo mặc định. Không cần cấu hình nào thêm vì trình xây dựng sử dụng QEMU được đi kèm trong Docker Desktop VM.

Nếu bạn đang sử dụng một trình xây dựng bên ngoài Docker Desktop, chẳng hạn như Docker Engine trên Linux hoặc một trình xây dựng từ xa tùy chỉnh, bạn cần cài đặt QEMU và đăng ký các loại tệp thực thi trên hệ điều hành chủ. Các yêu cầu tiên quyết để cài đặt QEMU là:

- Phiên bản Linux kernel 4.8 hoặc mới hơn
- Phiên bản `binfmt-support` 2.1.7 hoặc mới hơn
- Các tệp nhị phân QEMU phải được biên dịch tĩnh và đăng ký với cờ `fix_binary`

Sử dụng image [`tonistiigi/binfmt`](https://github.com/tonistiigi/binfmt) để cài đặt QEMU và đăng ký các loại tệp thực thi trên máy chủ bằng một lệnh duy nhất:

```sh
docker run --privileged --rm tonistiigi/binfmt --uninstall qemu-*
docker run --privileged --rm tonistiigi/binfmt --install all
```

Lệnh này cài đặt các tệp nhị phân QEMU và đăng ký chúng với [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc), cho phép QEMU thực thi các định dạng tệp không phải là gốc để mô phỏng.

Để kiểm tra xem QEMU đã được cài đặt chính xác, bạn có thể chạy:

```sh
ls -al /proc/sys/fs/binfmt_misc/
```

Kết quả đầu ra dự kiến sẽ bao gồm các mục nhập như `qemu-aarch64`, `qemu-arm`, `qemu-ppc64le`, v.v.:

```sh
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

Sau khi QEMU được cài đặt và các loại tệp thực thi được đăng ký trên hệ điều hành chủ, chúng hoạt động một cách minh bạch bên trong các container. Bạn có thể xác minh đăng ký của mình bằng cách kiểm tra xem `F` có nằm trong các cờ của `/proc/sys/fs/binfmt_misc/qemu-*` hay không.

Ví dụ, để kiểm tra trình xử lý cho kiến trúc ARM 64-bit (aarch64), hãy đọc nội dung của tệp ảo tương ứng:

```sh
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
```
Kết quả đầu ra dự kiến:

```sh
enabled
interpreter /usr/bin/qemu-aarch64
flags: POCF
offset 0
magic 7f454c460201010000000000000000000200b700
mask ffffffffffffff00fffffffffffffffffeffffff
```

  * `enabled`: Cho biết trình xử lý đang hoạt động.
  * `interpreter`: Trỏ đến chương trình mà kernel sẽ gọi để chạy tệp nhị phân (đó là tệp nhị phân QEMU tĩnh).
  * `magic` và `mask`: Đây là các chuỗi byte cụ thể (byte magic) mà kernel sử dụng để xác định rằng tệp nhị phân thuộc về kiến trúc ARM64, kích hoạt mô phỏng QEMU.

Nếu bạn thấy các mục nhập này được liệt kê và `enabled` sau khi chạy lệnh, điều đó có nghĩa là tính năng xây dựng đa kiến trúc đã được thiết lập thành công.

### Kiểm tra hỗ trợ mô phỏng hiện tại

Bạn có thể kiểm tra xem mô phỏng có hoạt động bằng cách chạy một container cho kiến trúc khác hay không. Ví dụ, để chạy một container ARM64 trên máy chủ x86_64:

```sh
docker run --rm --platform linux/arm64 alpine uname -a
docker run --rm --platform linux/arm/v7 alpine uname -a
docker run --rm --platform linux/ppc64le alpine uname -a
docker run --rm --platform linux/s390x alpine uname -a
docker run --rm --platform linux/riscv64 alpine uname -a
```
Kết quả đầu ra dự kiến cho container ARM64:

```sh
Linux 20b9df4ab610 6.6.87.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun  5 18:30:46 UTC 2025 aarch64 Linux
```

-----

## 🛠️ Tự động hóa Đăng ký QEMU trên WSL

Nếu bạn khởi động lại WSL 2 (hoặc toàn bộ hệ thống Windows), đăng ký QEMU sẽ bị mất và bạn sẽ cần chạy lại lệnh đăng ký. Để tránh bất tiện này, bạn có thể tự động hóa quá trình đăng ký để chạy khi khởi động.

-----

### I. Tự động hóa Đăng ký QEMU khi Khởi động

Để đảm bảo Docker daemon ổn định và đăng ký trình xử lý QEMU liên tục, bạn nên bật `systemd` và tạo một dịch vụ chuyên dụng.

#### Bước 1: Bật Systemd (Nếu chưa được thực hiện)

Đây là yêu cầu tiên quyết để quản lý dịch vụ tự động trên các bản phân phối Linux hiện đại như Debian.

1.  Mở terminal WSL 2 Debian của bạn.
2.  Sử dụng một trình soạn thảo để mở tệp cấu hình WSL:
    ```sh
    sudo nano /etc/wsl.conf
    ```
3.  Thêm hoặc đảm bảo nội dung sau có mặt (độ nhạy cảm của chữ hoa/chữ thường là quan trọng):
    ```ini
    [boot]
    systemd=true
    ```
4.  Lưu và thoát trình soạn thảo.
5.  **Quan trọng:** Khởi động lại phiên WSL 2 để áp dụng thay đổi này.

    ```powershell
    wsl --shutdown
    wsl
    ```

#### Bước 2: Tạo một Dịch vụ Systemd cho Đăng ký QEMU

Chúng tôi sẽ tạo một tệp dịch vụ mới để chạy lệnh Docker sau khi Docker daemon đã khởi động.

1.  Tạo tệp dịch vụ trong thư mục cấu hình `systemd`:
    ```bash
    sudo nano /etc/systemd/system/qemu-binfmt-register.service
    ```
2.  Dán nội dung sau vào tệp (Tệp unit tiêu chuẩn này đảm bảo lệnh của bạn chạy với quyền truy cập có đặc quyền và phụ thuộc vào dịch vụ Docker):
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
3.  Lưu và thoát.

#### Bước 3: Bật và Khởi động Dịch vụ

1.  Tải lại cấu hình `systemd` để nhận ra dịch vụ mới:
    ```bash
    sudo systemctl daemon-reload
    ```
2.  Bật dịch vụ để nó chạy tự động khi Debian khởi động:
    ```bash
    sudo systemctl enable qemu-binfmt-register.service
    ```
3.  Khởi động dịch vụ ngay lập tức:
    ```bash
    sudo systemctl start qemu-binfmt-register.service
    ```

**Xác minh:** Sau khi chạy, bạn có thể kiểm tra trạng thái dịch vụ:

```bash
sudo systemctl status qemu-binfmt-register.service
```

Trạng thái sẽ hiển thị là `active (exited)`. Bây giờ, bất cứ khi nào bạn khởi động lại WSL (bằng cách chạy `wsl --shutdown` trên Windows), lệnh đăng ký QEMU sẽ được thực thi tự động.

## Tài liệu tham khảo
- [Docker Documentation: Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
