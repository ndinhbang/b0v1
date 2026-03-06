# Docker Container Truy cập Host: Hướng dẫn Hoàn chỉnh về host.docker.internal

Mục lục

*   [Giới thiệu](#giới-thiệu)
*   [Tại sao localhost không hoạt động?](#tại-sao-localhost-không-hoạt-động)
*   [Cơ chế cách ly mạng Container](#cơ-chế-cách-ly-mạng-container)
*   [host.docker.internal là gì?](#hostdockerinternal-là-gì)
*   [Hỗ trợ Phiên bản và Nền tảng](#hỗ-trợ-phiên-bản-và-nền-tảng)
*   [Phương pháp Cấu hình cho Ba Nền tảng](#phương-pháp-cấu-hình-cho-ba-nền-tảng)
*   [Cấu hình Mac/Windows (Docker Desktop)](#cấu-hình-macwindows-docker-desktop)
*   [Cấu hình Linux (Docker Engine)](#cấu-hình-linux-docker-engine)
*   [Cấu hình Để vượt Qua Giới hạn Nền tảng (Được khuyến nghị Mạnh mẽ)](#cấu-hình-để-vượt-qua-giới-hạn-nền-tảng-được-khuyến-nghị-mạnh-mẽ)
*   [Cấu hình Dịch vụ Host Cần thiết](#cấu-hình-dịch-vụ-host-cần-thiết)
*   [Dịch vụ Phải Lắng nghe trên Địa chỉ Chính xác](#dịch-vụ-phải-lắng-nghe-trên-địa-chỉ-chính-xác)
*   [Cấu hình Quyền người dùng (MySQL cụ thể)](#cấu-hình-quyền-người-dùng-mysql-cụ-thể)
*   [Cấu hình Tường lửa](#cấu-hình-tường-lửa)
*   [Khuyến nghị Bảo mật](#khuyến-nghị-bảo-mật)
*   [Danh sách kiểm tra Khắc phục sự cố Chung](#danh-sách-kiểm-tra-khắc-phục-sự-cố-chung)
*   [Sự cố 1: Kết nối bị từ chối](#sự-cố-1-kết-nối-bị-từ-chối)
*   [Sự cố 2: Hết thời gian chờ kết nối](#sự-cố-2-hết-thời-gian-chờ-kết-nối)
*   [Sự cố 3: Host không xác định (không thể phân giải host.docker.internal)](#sự-cố-3-host-không-xác-định-không-thể-phân-giải-hostdockerinternal)
*   [Sự cố 4: Xác thực thất bại (Truy cập bị từ chối)](#sự-cố-4-xác-thực-thất-bại-truy-cập-bị-từ-chối)
*   [Sự cố 5: Không nhất quán Cấu hình Đa nền tảng](#sự-cố-5-không-nhất-quán-cấu-hình-đa-nền-tảng)
*   [Thần chú Khắc phục sự cố Nhanh chóng](#thần-chú-khắc-phục-sự-cố-nhanh-chóng)
*   [Ví dụ Thực tế](#ví-dụ-thực-tế)
*   [Ví dụ 1: Ứng dụng Spring Boot Kết nối với MySQL Host](#ví-dụ-1-ứng-dụng-spring-boot-kết-nối-với-mysql-host)
*   [Ví dụ 2: Ứng dụng Node.js Kết nối với Redis Host](#ví-dụ-2-ứng-dụng-nodejs-kết-nối-với-redis-host)
*   [Ví dụ 3: Cấu hình Môi trường Dev Hoàn chỉnh](#ví-dụ-3-cấu-hình-môi-trường-dev-hoàn-chỉnh)
*   [Tóm tắt](#tóm-tắt)

## Giới thiệu

Thứ Sáu lúc 3 giờ chiều. Tôi đang nhìn vào thông báo lỗi trong terminal: `Connection refused`.

Thành thật mà nói, nó rất là bực mình. MySQL đang chạy tốt trên máy cục bộ của tôi—Navicat có thể kết nối, dòng lệnh hoạt động—nhưng ứng dụng được đóng gói trong container chỉ không thể truy cập nó. Tôi kiểm tra lại chuỗi kết nối ba lần: `localhost:3306`. Tên người dùng và mật khẩu đều đúng. Vấn đề là gì?

Hóa ra là ba từ đó: `localhost`.

Nếu bạn đã gặp phải điều này trước đây—sử dụng `localhost` hoặc `127.0.0.1` bên trong Docker container để kết nối với các dịch vụ host luôn không thành công—bài viết này dành cho bạn. Tôi sẽ giải thích bằng các thuật ngữ đơn giản: tại sao localhost bên trong container không phải là những gì bạn nghĩ, và cách giải quyết vấn đề này một cách thanh lịch với "tên miền kỳ diệu" `host.docker.internal`.

Những gì bạn sẽ học được:

*   Nguyên tắc thực sự đằng sau cách ly mạng container (không có jargon)
*   Các phương pháp cấu hình chính xác cho Mac, Windows và Linux
*   Danh sách kiểm tra khắc phục sự cố thực tế (để lần tới bạn cần nó)

## Tại sao localhost không hoạt động?

Câu trả lời ngắn gọn: container có thế giới mạng độc lập của riêng họ.

Có vẻ trừu tượng? Hãy để tôi diễn giải nó theo cách khác. Hãy nghĩ về một container như một ngôi nhà nhỏ độc lập với địa chỉ riêng của nó, hộp thư riêng của nó, mọi thứ của riêng nó. Khi bạn gọi "localhost" hoặc nhập "127.0.0.1" bên trong container, bạn thực sự đang tìm kiếm **chính ngôi nhà đó**, không phải máy chủ bên ngoài.

Cụ thể:

*   Trên máy chủ, `localhost` trỏ đến chính máy chủ đó
*   Bên trong một container, `localhost` trỏ đến chính container đó
*   Chúng hoàn toàn khác nhau

Tôi khá ngạc nhiên khi lần đầu tiên học được điều này. MySQL đang chạy tốt trên máy tính của tôi, vậy tại sao container lại không thể kết nối? Vì lý do này—container đang tìm kiếm MySQL trong thế giới của riêng nó, nơi hiển nhiên nó không tồn tại.

### Cơ chế cách ly mạng Container

Docker tạo một "network namespace" độc lập cho mỗi container (đừng để thuật ngữ làm bạn sợ). Hãy nghĩ về nó theo cách này:

Mỗi container có giao diện mạng riêng, địa chỉ IP riêng, bảng định tuyến riêng. Giống như bạn và những người hàng xóm của bạn—cùng tòa nhà, nhưng mật khẩu wifi riêng biệt, không có can thiệp.

Container và host giao tiếp qua một cầu ảo gọi là `docker0`. Địa chỉ IP của container thường như `172.17.0.x`, và từ góc độ của container, địa chỉ IP của host là `172.17.0.1` (địa chỉ cổng của cây cầu).

Khi bạn truy cập `localhost` bên trong một container, bạn đang truy cập `127.0.0.1` của container, không phải `127.0.0.1` của host. Tự nhiên, nó không thể truy cập MySQL của host.

Đây là một số thông báo lỗi thực tế để minh họa:

```sh
Error: connect ECONNREFUSED 127.0.0.1:3306
```

Hoặc:

```sh
Can't connect to MySQL server on 'localhost' (111)
```

Đây là lỗi cổ điển từ "sử dụng localhost bên trong một container để kết nối với các dịch vụ host."

## host.docker.internal là gì?

Vì localhost không hoạt động, làm cách nào để chúng ta cho phép container truy cập host?

Docker cung cấp một giải pháp thanh lịch: `host.docker.internal`. Đây là một tên miền đặc biệt mà tự động phân giải thành địa chỉ IP của host. Hãy coi nó như một "tên gọi thay thế" cho host—không quan trọng địa chỉ IP của host thực tế là gì, sử dụng tên này sẽ tìm thấy nó.

Ví dụ, nếu MySQL của bạn lắng nghe trên cổng 3306 trên host, chỉ cần kết nối như thế này bên trong container:

```sh
mysql://user:pass@host.docker.internal:3306/dbname
```

Không cần lo lắng liệu địa chỉ IP của host có phải `192.168.1.100` hoặc `10.0.0.5`, hoặc liệu địa chỉ IP có thay đổi trong các môi trường mạng khác nhau—`host.docker.internal` tự động trỏ đến địa chỉ chính xác.

Khá tiện lợi, phải không?

### Hỗ trợ Phiên bản và Nền tảng

Nhưng có một sự cố mà bạn cần biết.

**Người dùng Mac và Windows (Docker Desktop)**

Nếu bạn đang sử dụng Docker Desktop (cái có GUI), phiên bản 18.03 trở đi (tháng 3 năm 2018) hỗ trợ sẵn `host.docker.internal`. Hoạt động ngay lập tức, không cần cấu hình thêm.

Chỉ cần viết `host.docker.internal` trực tiếp trong mã của bạn:

```js
const mysql = require('mysql2');
const connection = mysql.createConnection({
  host: 'host.docker.internal',  // Đơn giản thế đó
  port: 3306,
  user: 'root',
  password: 'your_password'
});
```

**Người dùng Linux (Docker Engine)**

Linux không may mắn như vậy. Vì Docker chạy trực tiếp trên hệ thống trong Linux, mà không có lớp VM mà Mac/Windows có, `host.docker.internal` không tồn tại theo mặc định.

Tin tốt: kể từ Docker Engine 20.10 (tháng 12 năm 2020), bạn có thể bật nó thủ công thông qua cấu hình. Làm sao? Chúng ta sẽ đề cập đến điều nó trong phần tiếp theo.

Nếu phiên bản Docker của bạn cũ hơn, có các giải pháp thay thế:

*   Sử dụng `172.17.0.1` (địa chỉ cổng mặc định Docker)
*   Sử dụng địa chỉ IP thực tế của host trong mạng Docker
*   Sử dụng `docker.for.mac.host.internal` (chỉ các phiên bản Mac cũ hơn)

## Phương pháp Cấu hình cho Ba Nền tảng

Phần này có các cấu hình thực tế mà bạn có thể sao chép.

### Cấu hình Mac/Windows (Docker Desktop)

Trường hợp đơn giản nhất.

**Phương pháp 1: Sử dụng Trực tiếp trong Mã**

Không cần cấu hình thêm, chỉ cần viết `host.docker.internal` trong mã của bạn:

```yml
# docker-compose.yml
version: '3'
services:
  app:
    image: myapp:latest
    environment:
      - DB_HOST=host.docker.internal  # Sử dụng trực tiếp
      - DB_PORT=3306
```

**Phương pháp 2: Khai báo Rõ ràng (Tùy chọn)**

Mặc dù không bắt buộc, bạn có thể thêm `extra_hosts` nếu bạn muốn nó rõ ràng:

```yml
version: '3'
services:
  app:
    image: myapp:latest
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - DB_HOST=host.docker.internal
```

`host-gateway` là cú pháp mới trong Docker 20.10+, có nghĩa là "địa chỉ cổng host."

Sử dụng lệnh `docker run`:

```sh
docker run -d \
  --add-host=host.docker.internal:host-gateway \
  -e DB_HOST=host.docker.internal \
  myapp:latest
```

### Cấu hình Linux (Docker Engine)

Hơi phức tạp hơn trong Linux, cần cấu hình thủ công.

**Phương pháp 1: Được Khuyến nghị - Sử dụng host-gateway**

Phương pháp phổ quát nhất, hoạt động trên Docker 20.10+ trên tất cả các nền tảng:

```yml
# docker-compose.yml
version: '3'
services:
  app:
    image: myapp:latest
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Cấu hình chính
    environment:
      - DB_HOST=host.docker.internal
      - DB_PORT=3306
```

Sử dụng `docker run`:

```sh
docker run -d \
  --add-host=host.docker.internal:host-gateway \
  -e DB_HOST=host.docker.internal \
  myapp:latest
```

Lợi thế của cách tiếp cận này là **tính tương thích đa nền tảng**—cấu hình tương tự hoạt động trên Mac, Windows và Linux mà không có những sửa đổi cụ thể của nền tảng.

**Phương pháp 2: Dự phòng - Sử dụng Địa chỉ IP Cầu Docker**

Nếu `host-gateway` không khả dụng (Docker quá cũ), hãy sử dụng cổng mặc định:

```yml
version: '3'
services:
  app:
    image: myapp:latest
    extra_hosts:
      - "host.docker.internal:172.17.0.1"  # Cổng mặc định Docker
    environment:
      - DB_HOST=host.docker.internal
```

`172.17.0.1` là cổng mặc định cho mạng cầu Docker. Địa chỉ IP này là đúng trong hầu hết các trường hợp, trừ khi bạn đã sửa đổi cấu hình mạng mặc định của Docker.

**Phương pháp 3: Giải pháp Cuối cùng - Chế độ Mạng host**

Nếu các phương pháp trên không hoạt động, có một lựa chọn "hạt nhân":

```sh
docker run -d \
  --network=host \
  -e DB_HOST=localhost \  # Bây giờ có thể sử dụng localhost
  myapp:latest
```

Hoặc trong docker-compose:

```yml
version: '3'
services:
  app:
    image: myapp:latest
    network_mode: "host"  # Sử dụng mạng host
    environment:
      - DB_HOST=localhost  # Có thể sử dụng localhost trực tiếp
```

**Ưu điểm**: Đơn giản và thô, container trực tiếp sử dụng ngăn xếp mạng của host, `localhost` là localhost thực sự.

**Nhược điểm**:

*   Phá vỡ cách ly mạng của container
*   Container và host chia sẻ cổng, xung đột tiềm ẩn (ví dụ: container muốn 8080 nhưng host đã sử dụng nó)
*   Chỉ Linux, Mac/Windows không hỗ trợ nó
*   **Không được khuyến nghị cho production**, chỉ để gỡ lỗi phát triển cục bộ

### Cấu hình Để vượt Qua Giới hạn Nền tảng (Được khuyến nghị Mạnh mẽ)

Nếu nhóm của bạn có người dùng Mac và Linux, hoặc mã của bạn chạy trong các môi trường khác nhau, hãy sử dụng cấu hình này:

```yml
# docker-compose.yml
version: '3'
services:
  app:
    image: myapp:latest
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Tất cả các nền tảng công nhận
    environment:
      - DB_HOST=host.docker.internal
      - DB_PORT=3306
      - DB_USER=root
      - DB_PASSWORD: your_password
```

Cấu hình này hoạt động trên tất cả các nền tảng với Docker 20.10+ (được phát hành vào cuối năm 2020). Nếu phiên bản Docker của bạn vẫn còn trước 2020... thành thật mà nói, đã đến lúc nâng cấp.

## Cấu hình Dịch vụ Host Cần thiết

Cấu hình phía container là không đủ.

Các dịch vụ host cũng cần cấu hình phù hợp, nếu không kết nối sẽ vẫn không thành công. Rất nhiều người bỏ qua điều này, vì vậy hãy giải quyết nó riêng biệt.

### Dịch vụ Phải Lắng nghe trên Địa chỉ Chính xác

Đây là sai lầm phổ biến nhất.

Nhiều dịch vụ mặc định chỉ lắng nghe trên `127.0.0.1`, có nghĩa là chúng chỉ chấp nhận kết nối từ máy cục bộ. Nhưng container Docker không được coi là "cục bộ"—các yêu cầu đến từ cây cầu Docker sẽ bị từ chối.

Bạn cần các dịch vụ lắng nghe trên `0.0.0.0`, có nghĩa là "chấp nhận kết nối từ tất cả các giao diện mạng."

**Cấu hình MySQL**

Tìm tệp cấu hình MySQL, thường ở:

*   Linux: `/etc/mysql/mysql.conf.d/mysqld.cnf`
*   Mac (Homebrew): `/usr/local/etc/my.cnf`
*   Windows: `C:\ProgramData\MySQL\MySQL Server 8.0\my.ini`

Sửa đổi `bind-address`:

```ini
[mysqld]
# Có thể ban đầu là
# bind-address = 127.0.0.1

# Thay đổi thành
bind-address = 0.0.0.0
```

Khởi động lại MySQL sau khi thay đổi:

```sh
# Linux
sudo systemctl restart mysql

# Mac
brew services restart mysql

# Windows
# Khởi động lại dịch vụ MySQL trong Services Manager
```

**Cấu hình Redis**

Chỉnh sửa `redis.conf` (thường ở `/etc/redis/redis.conf` hoặc `/usr/local/etc/redis.conf`):

```sh
# Tìm dòng này
bind 127.0.0.1 -::1

# Thay đổi thành
bind 0.0.0.0
```

Khởi động lại Redis:

```sh
# Linux
sudo systemctl restart redis

# Mac
brew services restart redis
```

**Cấu hình PostgreSQL**

Chỉnh sửa `postgresql.conf`:

```sh
listen_addresses = '*'  # Lắng nghe trên tất cả các địa chỉ
```

Cũng sửa đổi `pg_hba.conf` để cho phép truy cập subnet Docker:

```sh
# Thêm dòng này để cho phép subnet 172.17.0.0/16
host    all             all             172.17.0.0/16           md5
```

### Cấu hình Quyền người dùng (MySQL cụ thể)

Ngay cả khi MySQL lắng nghe trên 0.0.0.0, vẫn còn rào cản quyền người dùng.

Quyền người dùng MySQL được quản lý bởi "username@source\_host". Ví dụ, `root@localhost` và `root@%` là hai người dùng khác nhau.

Nếu người dùng MySQL của bạn chỉ cho phép truy cập `localhost`, container vẫn không thể kết nối. Bạn cần cấp quyền truy cập subnet Docker:

```sql
-- Tùy chọn 1: Cho phép từ bất kỳ host nào (đơn giản nhưng ít an toàn hơn)
GRANT ALL PRIVILEGES ON *.* TO 'your_user'@'%' IDENTIFIED BY 'your_password';

-- Tùy chọn 2: Chỉ cho phép subnet Docker (an toàn hơn)
GRANT ALL PRIVILEGES ON *.* TO 'your_user'@'172.17.0.%' IDENTIFIED BY 'your_password';

-- Xóa cache quyền
FLUSH PRIVILEGES;
```

Đối với MySQL 8.0+, cú pháp hơi khác:

```sql
-- Trước tiên tạo người dùng
CREATE USER 'your_user'@'%' IDENTIFIED BY 'your_password';

-- Sau đó cấp quyền
GRANT ALL PRIVILEGES ON *.* TO 'your_user'@'%';

FLUSH PRIVILEGES;
```

### Cấu hình Tường lửa

Một số hệ thống' tường lửa có thể chặn container Docker truy cập các dịch vụ host.

**Kiểm tra trạng thái tường lửa**:

```sh
# Linux (ufw)
sudo ufw status

# Linux (firewalld)
sudo firewall-cmd --state
```

**Cho phép truy cập subnet Docker** (sử dụng cổng MySQL 3306 làm ví dụ):

```sh
# ufw
sudo ufw allow from 172.17.0.0/16 to any port 3306

# firewalld
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="172.17.0.0/16" port port="3306" protocol="tcp" accept'
sudo firewall-cmd --reload
```

### Khuyến nghị Bảo mật

Lắng nghe trên `0.0.0.0` có có những rủi ro bảo mật—dịch vụ của bạn trở nên tiếp xúc với các máy khác trong mạng.

**Cách tiếp cận Môi trường Production**:

1.  **Lắng nghe chỉ trên giao diện cụ thể**: Nếu bạn biết giao diện nào Docker sử dụng, lắng nghe chỉ trên giao diện đó

    ```
    bind-address = 172.17.0.1
    ```

2.  **Kết hợp với tường lửa**: Chỉ cho phép truy cập subnet Docker, chặn các nguồn khác

3.  **Sử dụng container cơ sở dữ liệu chuyên dụng**: Không chạy cơ sở dữ liệu trên host, trực tiếp bắt đầu container cơ sở dữ liệu với Docker Compose, container ứng dụng và cơ sở dữ liệu trong cùng một mạng, an toàn hơn


**Môi trường Phát triển Cục bộ**:

Thành thật mà nói, để phát triển cục bộ, lắng nghe trên `0.0.0.0` không phải là vấn đề lớn. Máy tính của bạn không phải máy chủ, các mạng bên ngoài không thể truy cập nó. Đừng lo lắng quá nhiều.

## Danh sách kiểm tra Khắc phục sự cố Chung

Gặp vấn đề kết nối? Đừng hoảng sợ, khắc phục sự cố từng bước với danh sách kiểm tra này.

### Sự cố 1: Kết nối bị từ chối

Lỗi phổ biến nhất. Thông báo lỗi trông như:

```sh
Error: connect ECONNREFUSED host.docker.internal:3306
```

Hoặc:

```sh
Can't connect to MySQL server on 'host.docker.internal' (111)
```

**Các Nguyên nhân Có thể và Các Bước Khắc phục sự cố**:

**Bước 1: Kiểm tra xem Dịch vụ Host có Đang chạy không**

Trên máy chủ:

```sh
# Kiểm tra MySQL
sudo systemctl status mysql    # Linux
brew services list              # Mac

# Kiểm tra xem cổng có đang lắng nghe không
netstat -an | grep 3306
# Hoặc
lsof -i :3306
```

Nếu dịch vụ không chạy, hãy bắt đầu nó trước.

**Bước 2: Kiểm tra Địa chỉ Lắng nghe của Dịch vụ**

Trên máy chủ:

```sh
# Kiểm tra địa chỉ nào MySQL đang lắng nghe
sudo netstat -tlnp | grep 3306
```

Đầu ra sẽ trông như:

```sh
tcp  0  0 0.0.0.0:3306  0.0.0.0:*  LISTEN  1234/mysqld
```

Kiểm tra cột thứ ba. Nếu nó là `0.0.0.0:3306`, lắng nghe trên tất cả các địa chỉ, không có vấn đề. Nếu nó là `127.0.0.1:3306`, đó là vấn đề—chỉ lắng nghe cục bộ, container không thể kết nối.

Giải pháp: Làm theo phần "Cấu hình Dịch vụ Host" ở trên, thay đổi `bind-address` thành `0.0.0.0`.

**Bước 3: Kiểm tra Tường lửa**

Tạm thời tắt tường lửa để kiểm tra:

```sh
# Linux (ufw)
sudo ufw disable

# Linux (firewalld)
sudo systemctl stop firewalld

# Mac
# System Preferences -> Security & Privacy -> Firewall -> Off
```

Nếu vô hiệu hóa tường lửa cho phép kết nối, đó là vấn đề tường lửa. Hãy nhớ cấu hình các quy tắc tường lửa như được đề cập trước đó, sau đó bật lại tường lửa.

### Sự cố 2: Hết thời gian chờ kết nối

Thông báo lỗi:

```sh
Error: connect ETIMEDOUT host.docker.internal:3306
```

Hết thời gian chờ thường phức tạp hơn từ chối, có nghĩa là gói tin đã được gửi nhưng không quay lại.

**Các Nguyên nhân Có thể và Các Bước Khắc phục sự cố**:

**Bước 1: Kiểm tra xem host.docker.internal có Phân giải được không**

Bên trong container:

```sh
# Nhập container
docker exec -it your_container sh

# Ping nó
ping host.docker.internal
```

Nếu ping thất bại hoặc hiển thị "unknown host", `host.docker.internal` không được cấu hình đúng.

**Người dùng Linux hãy chú ý ở đây**: Xác nhận docker-compose.yml hoặc lệnh docker run của bạn bao gồm `--add-host=host.docker.internal:host-gateway`.

**Bước 2: Kiểm tra Số Cổng**

Bạn có chắc chắn đó là 3306 không? Nếu MySQL đã thay đổi cổng thì sao?

Xác nhận trên host:

```sh
# Kiểm tra cổng thực tế của MySQL
sudo netstat -tlnp | grep mysqld
```

**Bước 3: Kiểm tra Tính kết nối Mạng Container-to-Host**

Bên trong container:

```sh
# Kiểm tra xem cổng có thể tiếp cận được không
telnet host.docker.internal 3306

# Nếu telnet không khả dụng, sử dụng nc
nc -zv host.docker.internal 3306
```

Nếu cổng không thể tiếp cận, hãy kiểm tra lại tường lửa và cấu hình dịch vụ.

### Sự cố 3: Host không xác định (không thể phân giải host.docker.internal)

Thông báo lỗi:

```sh
getaddrinfo ENOTFOUND host.docker.internal
```

Điều này có nghĩa là phân giải DNS thất bại, container không nhận ra tên miền `host.docker.internal`.

**Giải pháp**:

Kiểm tra cấu hình container, thêm `extra_hosts`:

```yml
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Hoặc với docker run:

```sh
docker run --add-host=host.docker.internal:host-gateway ...
```

### Sự cố 4: Xác thực thất bại (Truy cập bị từ chối)

Thông báo lỗi:

```sh
Access denied for user 'root'@'172.17.0.2' (using password: YES)
```

Điều này có nghĩa là kết nối MySQL đã thành công, nhưng quyền người dùng không chính xác.

**Giải pháp**:

Cấp quyền người dùng MySQL:

```sql
-- Kiểm tra quyền người dùng hiện tại
SELECT user, host FROM mysql.user WHERE user='root';

-- Nếu chỉ tồn tại root@localhost, cần tạo root@% hoặc root@172.17.0.%
CREATE USER 'root'@'%' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;
```

### Sự cố 5: Không nhất quán Cấu hình Đa nền tảng

Nhóm có người dùng Mac và Linux chia sẻ cùng một docker-compose.yml, hoạt động trên Mac nhưng không thành công trên Linux.

**Giải pháp**:

Hợp nhất bằng cách tiếp cận `host-gateway`, phổ quát trên các nền tảng:

```yaml
services:
  app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Đảm bảo Docker version ≥20.10. Nếu thành viên nhóm có Docker cũ hơn, thúc đẩy họ nâng cấp.

### Thần chú Khắc phục sự cố Nhanh chóng

Khi gặp vấn đề kết nối, kiểm tra theo thứ tự này:

1.  **Dịch vụ đang chạy?** → `systemctl status` / `brew services list`
2.  **Lắng nghe đúng cách?** → `netstat -tlnp`, kiểm tra nếu `0.0.0.0` hoặc `127.0.0.1`
3.  **Container được cấu hình?** → Kiểm tra `extra_hosts` hoặc `--add-host`
4.  **DNS hoạt động?** → Bên trong container `ping host.docker.internal`
5.  **Cổng có thể tiếp cận được?** → Bên trong container `telnet` hoặc `nc` test cổng
6.  **Tường lửa mở?** → Tạm thời vô hiệu hóa để kiểm tra
7.  **Quyền được cấp?** → Người dùng MySQL là `@localhost` hoặc `@%`

Chín lần mười, đó là một trong ba vấn đề đầu tiên.

## Ví dụ Thực tế

Lý thuyết đã được đề cập, hãy xem hai ví dụ thực tế.

### Ví dụ 1: Ứng dụng Spring Boot Kết nối với MySQL Host

**Kịch bản**: Bạn có một dự án Spring Boot, muốn chạy nó trong Docker, kết nối với cơ sở dữ liệu MySQL cục bộ.

**Bước 1: Cấu hình Spring Boot**

`application.yml`:

```sh
spring:
  datasource:
    # Sử dụng host.docker.internal để kết nối với MySQL host
    url: jdbc:mysql://host.docker.internal:3306/mydb?useSSL=false&serverTimezone=UTC
    username: root
    password: your_password
    driver-class-name: com.mysql.cj.jdbc.Driver
```

**Bước 2: Cấu hình Docker Compose**

`docker-compose.yml`:

```sh
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Cấu hình chính
    environment:
      # Cũng có thể ghi đè bằng biến env
      SPRING_DATASOURCE_URL: jdbc:mysql://host.docker.internal:3306/mydb
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: your_password
```

**Bước 3: Cấu hình MySQL Host**

Chỉnh sửa `/etc/mysql/mysql.conf.d/mysqld.cnf`:

```ini
[mysqld]
bind-address = 0.0.0.0
```

Khởi động lại MySQL:

```sh
sudo systemctl restart mysql
```

Cấp quyền người dùng:

```sql
CREATE USER 'root'@'%' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;
```

**Bước 4: Khởi động và Kiểm tra**

```sh
docker-compose up --build
```

Nếu bạn thấy logs như `HikariPool-1 - Start completed`, kết nối cơ sở dữ liệu đã thành công.

**Nhật ký Khắc phục sự cố**:

Khi tôi lần đầu tiên cấu hình điều này, tôi gặp `Connection refused`. Quá trình khắc phục sự cố:

1.  Kiểm tra MySQL đang chạy: `systemctl status mysql` → Đang chạy
2.  Kiểm tra địa chỉ lắng nghe: `netstat -tlnp | grep 3306` → Tìm thấy `127.0.0.1:3306`
3.  Thay đổi tệp cấu hình `bind-address = 0.0.0.0`, khởi động lại MySQL
4.  Chạy lại, kết nối được

### Ví dụ 2: Ứng dụng Node.js Kết nối với Redis Host

**Kịch bản**: Dự án Node.js sử dụng Redis để lưu trữ cache, Redis trên host trong quá trình phát triển cục bộ.

**Bước 1: Mã Node.js**

```js
// redis-client.js
const redis = require('redis');

const client = redis.createClient({
  host: process.env.REDIS_HOST || 'host.docker.internal',
  port: process.env.REDIS_PORT || 6379,
  // Nếu Redis có mật khẩu
  password: process.env.REDIS_PASSWORD
});

client.on('connect', () => {
  console.log('Redis connected successfully');
});

client.on('error', (err) => {
  console.error('Redis error:', err);
});

module.exports = client;
```

**Bước 2: Cấu hình Docker Compose**

`docker-compose.yml`:

```yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      NODE_ENV: development
      REDIS_HOST: host.docker.internal
      REDIS_PORT: 6379
```

**Bước 3: Cấu hình Redis Host**

Chỉnh sửa `/etc/redis/redis.conf` hoặc `/usr/local/etc/redis.conf`:

```sh
# Tìm dòng bind
bind 127.0.0.1 ::1

# Thay đổi thành
bind 0.0.0.0
```

Nếu Redis có `protected-mode yes`, cũng thay đổi:

```sh
protected-mode no  # Chấp nhận cho phát triển cục bộ, đừng làm điều này trong production
```

Khởi động lại Redis:

```sh
# Linux
sudo systemctl restart redis

# Mac
brew services restart redis
```

**Bước 4: Xác minh**

Khởi động ứng dụng:

```sh
docker-compose up
```

Xem `Redis connected successfully`, bạn rất tốt.

**Xử lý Đa nền tảng**:

Nếu nhóm có người dùng Mac và Linux, hợp nhất với các biến env:

```js
const REDIS_HOST = process.env.REDIS_HOST || (
  process.platform === 'linux' ? 'host.docker.internal' : 'host.docker.internal'
);
```

Đợi, bây giờ cả hai đều có thể sử dụng `host.docker.internal`, không cần phải phân biệt các nền tảng. Miễn là Docker Compose có `extra_hosts: ["host.docker.internal:host-gateway"]`, Mac và Linux sử dụng cùng một cấu hình.

### Ví dụ 3: Cấu hình Môi trường Dev Hoàn chỉnh

Đây là một mẫu thực tế, container ứng dụng kết nối với MySQL host và Redis:

```yml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      # Cấu hình cơ sở dữ liệu
      DB_HOST: host.docker.internal
      DB_PORT: 3306
      DB_NAME: myapp
      DB_USER: root
      DB_PASSWORD: your_password

      # Cấu hình Redis
      REDIS_HOST: host.docker.internal
      REDIS_PORT: 6379

      # Cấu hình ứng dụng
      NODE_ENV: development
      PORT: 8080
    volumes:
      - .:/app
      - /app/node_modules  # Đừng mount node_modules
    command: npm run dev  # Chế độ dev hot reload
```

Danh sách kiểm tra cấu hình host tương ứng:

```sh
# MySQL
# Chỉnh sửa /etc/mysql/mysql.conf.d/mysqld.cnf
bind-address = 0.0.0.0
# Khởi động lại: sudo systemctl restart mysql

# Redis
# Chỉnh sửa /etc/redis/redis.conf
bind 0.0.0.0
protected-mode no
# Khởi động lại: sudo systemctl restart redis

# Tường lửa (nếu cần)
sudo ufw allow from 172.17.0.0/16 to any port 3306
sudo ufw allow from 172.17.0.0/16 to any port 6379
```

Cấu hình này hoạt động trên Mac và Linux, sẵn sàng sao chép-dán.

## Tóm tắt

Sau tất cả điều đó, ba điểm cốt lõi:

**1\. Hiểu nguyên tắc**

Container có thế giới mạng riêng của chúng. `localhost` bên trong một container đề cập đến chính container đó, không phải host. Đây là cách ly namespace mạng, thiết kế của Docker, không phải là lỗi.

**2\. Chọn phương pháp Đúng**

Chọn cách tiếp cận dựa trên môi trường của bạn:

| Môi trường                       | Cách tiếp cận Được khuyến nghị           | Cấu hình                         |
| -------------------------------- | ----------------------------------------- | -------------------------------- |
| Mac/Windows (Docker Desktop)     | Sử dụng `host.docker.internal` trực tiếp | Không cấu hình thêm              |
| Linux (Docker Engine 20.10+)     | `extra_hosts: host-gateway`               | `docker-compose` hoặc `--add-host` |
| Nhóm đa nền tảng                 | `extra_hosts: host-gateway`               | Cấu hình thống nhất, tất cả nền tảng |
| Phiên bản Linux cũ hơn           | Sử dụng `172.17.0.1`                     | `extra_hosts` chỉ định IP        |
| Lựa chọn cuối cùng               | `--network=host`                         | Chỉ phát triển cục bộ, phá vỡ cách ly |


**3\. Cấu hình Dịch vụ Đúng cách**

Cấu hình container không đủ, dịch vụ host cũng cần setup:

*   Thay đổi địa chỉ lắng nghe thành `0.0.0.0`
*   Cấp quyền người dùng MySQL truy cập từ subnet Docker
*   Cho phép subnet Docker qua tường lửa

**Cây quyết định Nhanh chóng**

Khi gặp vấn đề kết nối:

```
Không thể kết nối với dịch vụ host?
  ↓
Sử dụng Mac/Windows hoặc Linux?
  ↓
Mac/Windows:
  → Sử dụng host.docker.internal trực tiếp
  → Nếu vẫn không thành công, kiểm tra cấu hình dịch vụ host

Linux:
  → Phiên bản Docker ≥20.10?
      Có → Sử dụng extra_hosts: host-gateway
      Không → Sử dụng extra_hosts: 172.17.0.1
  → Kiểm tra cấu hình dịch vụ host
  → Kiểm tra tường lửa

Đã thử mọi thứ?
  → Đi qua danh sách kiểm tra khắc phục sự cố từng mục
  → Lựa chọn hạt nhân: --network=host (chỉ phát triển cục bộ)
```

**Suy nghĩ Cuối cùng**

Phát triển có container thực sự rất tiện lợi, nhưng mạng có nhiều cạm bẫy. Tuy nhiên, làm chủ hai cấu hình chính—`host.docker.internal` và `host-gateway`—giải quyết được hầu hết các vấn đề.
