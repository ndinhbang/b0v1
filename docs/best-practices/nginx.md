## 🚀 Hướng Dẫn Tối Ưu Hóa Nginx + PHP-FPM (Chi Tiết & Lệnh Cụ Thể)

### I. Tối Ưu Hóa PHP-FPM (Quản lý Process và Bộ nhớ)

Các thông số này được cấu hình trong file pool của PHP-FPM (ví dụ: `/etc/php-fpm.d/www.conf`). Sau khi sửa đổi, **luôn cần** khởi động lại PHP-FPM: `systemctl restart php-fpm`.



#### 1\. Số lượng Process Con Tối Ưu (`pm.max_children`)

Đây là thông số phức tạp nhất, cần tính toán dựa trên ba yếu tố sau:

| Yếu tố | Ký hiệu | Cách Xác định & Lệnh | Giá trị (Ví dụ) |
| :--- | :--- | :--- | :--- |
| **Tổng RAM Hệ thống** | $RAM_{total}$ | Sử dụng lệnh **`free -m`** (đơn vị MB) trên **Host/VPS** để lấy giá trị `total` ở hàng `Mem:`. | $16384$ MB |
| **RAM Ứng dụng khác** | $RAM_{os\&apps}$ | Ước tính RAM sử dụng bởi HĐH, Nginx, Database (MySQL/PostgreSQL), Redis, v.v. Bạn có thể tạm thời **tắt PHP-FPM** và xem giá trị `used` trên lệnh `free -m`. | $2000$ MB |
| **RAM mỗi Process PHP** | $RAM_{per\_child}$ | Đo lường **RSS trung bình** (tính bằng MB) của các tiến trình PHP-FPM đang hoạt động. | $48.5$ MB |

**Lệnh Cụ thể để tìm $RAM_{per\_child}$:**
(Đảm bảo PHP-FPM đang chạy và xử lý request)

```bash
# Lệnh tính toán RSS trung bình của các tiến trình PHP-FPM (trừ tiến trình master)
ps -ylC php-fpm --sort:rss | awk '{sum+=$8; print $8}' | tail -n+2 | awk "END {print sum/NR/1024}"
```

**Công thức Tính toán:**
$$N_{child} \approx \frac{RAM_{total} - RAM_{os\&apps}}{RAM_{per\_child}}$$

  * **Cấu hình Cụ thể:** Áp dụng giá trị $N_{child}$ đã tính toán (ví dụ: `pm.max_children = 288`).
  * **Lý do Chi tiết:** Đảm bảo **tất cả** các tiến trình PHP-FPM đều nằm gọn trong **RAM vật lý**. Nếu giá trị quá cao, hệ thống sẽ phải dùng **Swap**, dẫn đến hiệu suất giảm mạnh.

#### 2\. Phương thức Quản lý Process (`pm`)

  * **Thông số:** `pm`
  * **Cấu hình Cụ thể:** `pm = static`
  * **Lệnh Đọc:**
    ```bash
    grep '^pm' /etc/php-fpm.d/www.conf
    ```
  * **Lý do Chi tiết:** Mô hình **`static`** giúp kiểm soát **chính xác** lượng **RAM** tiêu thụ, ngăn chặn việc hệ thống bị **overcommit** trong các đợt tải cao đột ngột.

#### 3\. Kiểm soát Rò rỉ Bộ nhớ (`pm.max_requests`)

  * **Thông số:** `pm.max_requests`
  * **Cấu hình Cụ thể:** `pm.max_requests = 10000`
  * **Lệnh Đọc:**
    ```bash
    grep 'max_requests' /etc/php-fpm.d/www.conf
    ```
  * **Lý do Chi tiết:** Buộc tiến trình con **khởi động lại (respawn)** sau số lượng request nhất định, làm sạch bộ nhớ định kỳ, chống lại sự tích lũy bộ nhớ (memory leaks).

#### 4\. Kênh Giao tiếp (`listen`)

  * **Thông số:** `listen`
  * **Cấu hình Cụ thể:** `listen = /var/run/php-fpm.sock`
  * **Lý do Chi tiết:** Sử dụng **UNIX Domain Socket (UDS)** cho độ trễ (latency) thấp hơn so với TCP/IP bằng cách loại bỏ các bước xử lý không cần thiết của ngăn xếp mạng.

-----

### II. Tối Ưu Hóa Kernel Linux (Cấu hình trên HOST)

Các thông số sysctl này phải được cấu hình trên **Host** và cần quyền `root`/`sudo`.

#### 1\. Giới hạn Hàng đợi Kết nối (`net.core.somaxconn`)

  * **Thông số:** `net.core.somaxconn`
  * **Cấu hình Cụ thể:** `4096`
  * **Lệnh Đọc:**
    ```bash
    sysctl net.core.somaxconn
    ```
  * **Lý do Chi tiết:** Đặt giới hạn tối đa cho **kernel listen queue**. Giá trị cao giúp chống lại các đợt tăng tải đột ngột, tránh việc kernel từ chối kết nối mới (gây ra lỗi **502** cho Nginx).

#### 2\. Giới hạn Socket Send Buffer (`net.core.wmem_max`)

  * **Thông số:** `net.core.wmem_max`
  * **Cấu hình Cụ thể:** `4194304` (4MB)
  * **Lệnh Đọc:**
    ```bash
    sysctl net.core.wmem_max
    ```
  * **Lý do Chi tiết:** Tăng giới hạn tối đa cho **socket send buffer** (**SO\_SNDBUF**). Việc này cho phép Nginx ghi dữ liệu phản hồi lớn vào **buffer** của kernel mà không bị **chặn (blocking)** bởi client chậm, giải phóng tiến trình Nginx.

#### 3\. Cấu hình Vĩnh viễn (Persistent)

  * **Hành động:** Thêm các thông số vào file cấu hình `/etc/sysctl.d/99-network.conf`.
  * **Lệnh:**
    ```bash
    echo "net.core.somaxconn=4096" | sudo tee -a /etc/sysctl.d/99-network.conf
    echo "net.core.wmem_max=4194304" | sudo tee -a /etc/sysctl.d/99-network.conf
    sysctl -p
    ```

-----

### III. Tối Ưu Hóa Nginx (FastCGI Proxy)

Các thông số này được cấu hình trong file Nginx (ví dụ: `/etc/nginx/nginx.conf`).

#### 1\. Bộ đệm FastCGI (`fastcgi_buffers` & `fastcgi_buffer_size`)

  * **Directive:** `fastcgi_buffers`
  * **Cấu hình Cụ thể:** `fastcgi_buffers 16 16k;`
  * **Lệnh Đọc:**
    ```bash
    grep 'fastcgi_buffers' /etc/nginx/nginx.conf
    ```
  * **Lý do Chi tiết:** Nginx nhận **toàn bộ** phản hồi từ PHP-FPM vào bộ đệm, cho phép **giải phóng** tiến trình PHP-FPM (tác vụ **CPU-bound**) ngay lập tức. Nginx sau đó quản lý việc truyền tải dữ liệu chậm (tác vụ **I/O-bound**) đến client.

#### 2\. Giới hạn Kết nối Worker (`worker_connections`)

  * **Directive:** `worker_connections`
  * **Cấu hình Cụ thể:** `worker_connections 65535;`
  * **Lệnh Đọc:**
    ```bash
    grep 'worker_connections' /etc/nginx/nginx.conf
    ```
  * **Lý do Chi tiết:** Đặt giới hạn tối đa số lượng kết nối mà một tiến trình **worker** của Nginx có thể xử lý. Giá trị này phải phù hợp với giới hạn **File Descriptor (FD)** của tiến trình.

#### 3\. Giới hạn File Descriptors (`ulimit -n`)

  * **Setting:** Tăng giới hạn **FDs** cho tiến trình Nginx.
  * **Cấu hình Cụ thể:** `65535`
  * **Lệnh Đọc (Kiểm tra trong Shell Nginx):**
    ```bash
    ulimit -n
    ```
  * **Lệnh Sửa (Docker):**
    ```bash
    docker run --ulimit nofile=65535:65535 your-image:latest
    ```
  * **Lý do Chi tiết:** Mỗi kết nối (client, UDS, tệp tĩnh) đều yêu cầu một **FD**. Nếu giới hạn thấp (mặc định 1024), Nginx sẽ nhanh chóng hết FD và gây ra lỗi **502** dưới tải cao.

-----

### IV. Lệnh Kiểm Tra và Áp Dụng Cuối Cùng

| Hành động | Lệnh | Ghi chú |
| :--- | :--- | :--- |
| **Kiểm tra Nginx** | `nginx -t` | Kiểm tra cú pháp cấu hình. |
| **Kiểm tra PHP-FPM** | `php-fpm -tt -y /path/to/php-fpm.conf` | **In ra các giá trị đã được phân giải** (resolved values), bao gồm backlog thực tế. |
| **Tải lại Nginx** | `systemctl reload nginx` | **Nên dùng** thay vì `restart` để tránh gián đoạn dịch vụ. |
| **Khởi động lại PHP-FPM** | `systemctl restart php-fpm` | **Bắt buộc** để áp dụng các thay đổi trong file pool. |
