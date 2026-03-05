# Docker Container Thoát Ngay Lập Tức? Hướng Dẫn Khắc Phục Sự Cố Hoàn Chỉnh

Mục lục

*   [Hiểu về Vòng Đời Container và Mã Thoát](#hiểu-về-vòng-đời-container-và-mã-thoát)
*   [Bản Chất của Container: Vòng Đời Process](#bản-chất-của-container-vòng-đời-process)
*   [Tham Chiếu Nhanh Mã Thoát: Câu Chuyện Đằng Sau Các Số](#tham-chiếu-nhanh-mã-thoát-câu-chuyện-đằng-sau-các-số)
*   [Các Mẫu Mã Thoát](#các-mẫu-mã-thoát)
*   [Phương Pháp Chẩn Đoán 4 Bước để Xác Định Vấn Đề Nhanh Chóng](#phương-pháp-chẩn-đoán-4-bước-để-xác-định-vấn-đề-nhanh-chóng)
*   [Bước 1: Xác Nhận Trạng Thái Container](#bước-1-xác-nhận-trạng-thái-container)
*   [Bước 2: Kiểm Tra Logs Container](#bước-2-kiểm-tra-logs-container)
*   [Bước 3: Kiểm Tra Cấu Hình Container](#bước-3-kiểm-tra-cấu-hình-container)
*   [Bước 4: Xác Minh Khởi Động Tương Tác](#bước-4-xác-minh-khởi-động-tương-tác)
*   [5 Kịch Bản Lỗi Phổ Biến và Giải Pháp](#5-kịch-bản-lỗi-phổ-biến-và-giải-pháp)
*   [Kịch Bản 1: Lỗi Tệp Cấu Hình hoặc Đường Dẫn Bị Thiếu](#kịch-bản-1-lỗi-tệp-cấu-hình-hoặc-đường-dẫn-bị-thiếu)
*   [Kịch Bản 2: Hết Bộ Nhớ (OOM Killed)](#kịch-bản-2-hết-bộ-nhớ-oom-killed)
*   [Kịch Bản 3: Xung Đột Port](#kịch-bản-3-xung-đột-port)
*   [Kịch Bản 4: Quyền Hạn Không Đủ](#kịch-bản-4-quyền-hạn-không-đủ)
*   [Kịch Bản 5: Dịch Vụ Phụ Thuộc Chưa Sẵn Sàng](#kịch-bản-5-dịch-vụ-phụ-thuộc-chưa-sẵn-sàng)
*   [Các Biện Pháp Phòng Ngừa và Thực Hành Tốt Nhất](#các-biện-pháp-phòng-ngừa-và-thực-hành-tốt-nhất)
*   [Cấu Hình Health Checks (HEALTHCHECK)](#cấu-hình-health-checks-healthcheck)
*   [Đặt Restart Policies](#đặt-restart-policies)
*   [Quản Lý Log: Ngăn Chặn Đĩa Đầy](#quản-lý-log-ngăn-chặn-đĩa-đầy)
*   [Giám Sát và Alerts: Phát Hiện Vấn Đề Sớm](#giám-sát-và-alerts-phát-hiện-vấn-đề-sớm)
*   [Danh Sách Kiểm Tra Cấu Hình Môi Trường Production](#danh-sách-kiểm-tra-cấu-hình-môi-trường-production)
*   [Kết Luận](#kết-luận)


Đây là hướng dẫn chẩn đoán các lỗi khởi động container. Cho dù bạn đang thấy Exit Code 1, 137, hay bất cứ mã nào khác, phương pháp này sẽ giúp bạn nhanh chóng xác định được nguyên nhân gốc rễ.

## Hiểu về Vòng Đời Container và Mã Thoát

Trước khi bắt đầu khắc phục sự cố, hãy làm rõ một câu hỏi cơ bản: tại sao container lại thoát?

### Bản Chất của Container: Vòng Đời Process

Docker container về cơ bản là một process bị cô lập. Khi process còn sống, container chạy; khi process chết, container thoát.

Hình dung bạn khởi động một container web server. Process chính có thể là nginx hoặc node. Miễn là process đó chạy, `docker ps` sẽ hiển thị container. Nhưng nếu process chính thoát vì bất kỳ lý do nào—hoàn thành bình thường, crash, hoặc bị system kill—container sẽ lập tức vào trạng thái Exited.

Đó là lý do tại sao đôi khi `docker ps` không hiển thị gì, và bạn cần flag `-a` để xem các container đã thoát.

### Tham Chiếu Nhanh Mã Thoát: Câu Chuyện Đằng Sau Các Số

Mỗi khi container thoát, Docker ghi lại một mã thoát. Những số này có vẻ khó hiểu, nhưng chúng thực sự đang cho bạn biết điều gì đã xảy ra.

**Exit Code 0**: Mọi thứ tốt, task hoàn thành.
Ví dụ, nếu bạn chạy một script import dữ liệu hoàn thành thành công, nó sẽ thoát với 0. Đây không phải là vấn đề—container vừa hoàn thành công việc của nó.

**Exit Code 1**: Chương trình gặp sự cố.
Đây là mã lỗi phổ biến nhất. Có thể là tệp được cấu hình sai, phụ thuộc bị thiếu, hoặc lỗi trong mã. Về cơ bản, ứng dụng bên trong container đã crash.

Tôi nhớ triển khai một container MySQL vào một lần mà cứ thoát với code 1. Sau khi đào sâu vào logs, tôi phát hiện ra rằng tôi đã vô tình gõ dấu hai chấm thay vì dấu bằng trong tệp cấu hình. MySQL nhìn thấy lỗi cú pháp và từ chối khởi động.

**Exit Code 137**: Hết bộ nhớ, hoặc bị kill bắt buộc.
Đây là mã mà tôi sợ nhất. 137 thường có nghĩa là một trong hai điều:

1.  Container vượt quá giới hạn bộ nhớ của nó, và OOM Killer của Linux đã chấm dứt process
2.  Ai đó (hoặc hệ thống) đã thực thi `docker kill` hoặc `kill -9`

Làm thế nào để phân biệt? Kiểm tra trường `OOMKilled` với `docker inspect`. Nếu nó là `true`, đó là vấn đề bộ nhớ; nếu `false`, nó có thể đã bị chấm dứt thủ công.

**Exit Code 127**: Lệnh không tìm thấy.
Thường có nghĩa là CMD hoặc ENTRYPOINT trong Dockerfile có đường dẫn sai, hoặc executable không tồn tại trong image container.

**Exit Code 139**: Lỗi phân đoạn (Segmentation fault).
Điều này thường xuất hiện trong các chương trình C/C++, có nghĩa là chương trình đã truy cập vào bộ nhớ mà nó không được truy cập. Nếu bạn không chạy các chương trình cấp thấp, bạn sẽ hiếm khi thấy cái này.

### Các Mẫu Mã Thoát

Mã thoát thực sự tuân theo một mẫu:

*   **0**: Thoát bình thường, không có vấn đề
*   **1-128**: Vấn đề ứng dụng (lỗi app, lỗi config, v.v.)
*   **129-255**: Sự can thiệp bên ngoài (bị kill bằng signal, bị chấm dứt bởi hệ thống, v.v.)

Hiểu được các mẫu này giúp bạn biết loại vấn đề nào bạn đang gặp phải, cho bạn hướng để khắc phục sự cố.

## Phương Pháp Chẩn Đoán 4 Bước để Xác Định Vấn Đề Nhanh Chóng

Bây giờ bạn biết những gì các mã thoát có nghĩa là. Nhưng biết các ý nghĩa là chưa đủ—bạn cần biết cách đào sâu vào vấn đề từng bước một.

Tôi đã phát triển một phương pháp chẩn đoán 4 bước bao gồm khoảng 90% các kịch bản lỗi khởi động container. Thực hiện quy trình này và bạn sẽ thấy các vấn đề không hề bí ẩn.

### Bước 1: Xác Nhận Trạng Thái Container

Đừng vội vàng kiểm tra logs. Trước tiên, xác nhận container có tồn tại và thực sự đã chết.

```sh
docker ps -a
```

Lệnh này liệt kê tất cả các container, bao gồm các container đã thoát. Hãy chú ý đến các thông tin chính này:

**CONTAINER ID**: Mã định danh duy nhất của container, cần thiết cho các lệnh tiếp theo. Bạn có thể sao chép chỉ vài ký tự đầu tiên; Docker sẽ tự động so khớp.

**Cột STATUS**: Đây là cái quan trọng. Các container đang chạy hiển thị `Up X minutes`, các container đã thoát hiển thị `Exited (code) X minutes ago`.

Ví dụ:

```sh
CONTAINER ID   IMAGE         STATUS
a1b2c3d4e5f6   mysql:8.0     Exited (1) 2 minutes ago
```

Exit code 1 gợi ý một vấn đề ở tầng ứng dụng. Nếu nó là 137, có khả năng là vấn đề về bộ nhớ.

**Lưu ý thời gian tạo và thoát**. Nếu container thoát ít hơn 1 giây sau khi tạo, nó có thể là lệnh khởi động hoặc vấn đề cấu hình. Nếu nó chạy trong một khoảng thời gian trước khi thoát, nó có thể là thiếu tài nguyên hoặc lỗi phụ thuộc.

### Bước 2: Kiểm Tra Logs Container

Đây là bước quan trọng nhất. Containers thường để lại các manh mối trước khi thoát, và những manh mối đó nằm trong logs.

**Xem cơ bản**:

```sh
docker logs <container_id>
```

Điều này hiển thị tất cả standard output và standard error từ container. Thường bạn sẽ trực tiếp thấy các thông báo lỗi như `Permission denied`, `No such file or directory`, `Connection refused`, v.v.

**Theo dõi thực thời** (tốt cho việc khắc phục quy trình khởi động):

```sh
docker logs -f <container_id>
```

Nếu bạn muốn xem điều gì xảy ra trong quá trình khởi động container, hãy sử dụng `-f`. Nó hoạt động giống như `tail -f`, hiển thị các logs mới theo thời gian thực. Mặc dù điều này ít hữu ích đối với các container đã thoát, nhưng nó rất tuyệt khi cố gắng khởi động lại.

**Xem chỉ logs gần đây**:

```sh
docker logs --tail 100 <container_id>
```

Nếu logs container quá dài, chỉ kiểm tra 100 dòng cuối cùng. Thường những dòng cuối cùng tiết lộ vấn đề.

**Thêm timestamps**:

```sh
docker logs -t <container_id>
```

Flag `-t` thêm timestamps cho mỗi dòng log, giúp bạn xác định chính xác thời điểm vấn đề xảy ra.

**Lọc error logs**:

```sh
docker logs <container_id> 2>&1 | grep -i error
```

Nếu có quá nhiều logs, chỉ cần tìm các dòng chứa "error". Điều này nhanh chóng xác định các lỗi quan trọng.

### Bước 3: Kiểm Tra Cấu Hình Container

Đôi khi logs không tiết lộ nhiều. Đó là khi bạn cần lặn sâu hơn vào cấu hình và trạng thái của container.

**Xem cấu hình đầy đủ**:

```sh
docker inspect <container_id>
```

Điều này xuất ra rất nhiều thông tin JSON, bao gồm tất cả cấu hình container, biến môi trường, mount points, cài đặt mạng, v.v. Đó là rất nhiều thông tin, nhưng rất hữu ích.

**Kiểm tra nhanh các thông tin cụ thể**:

Kiểm tra mã thoát:

```sh
docker inspect --format '{{.State.ExitCode}}' <container_id>
```

Kiểm tra nếu OOM killed:

```sh
docker inspect --format '{{.State.OOMKilled}}' <container_id>
```

Nếu đầu ra là `true`, chắc chắn là vấn đề về bộ nhớ.

Kiểm tra biến môi trường:

```sh
docker inspect --format '{{.Config.Env}}' <container_id>
```

Đôi khi các biến môi trường được cấu hình sai—database connection strings, API keys, v.v.

Kiểm tra đường dẫn mount:

```sh
docker inspect --format '{{.Mounts}}' <container_id>
```

Xác minh rằng các tệp cấu hình và thư mục dữ liệu được mount chính xác.

Kiểm tra đường dẫn tệp log:

```sh
docker inspect --format='{{.LogPath}}' <container_id>
```

Nếu `docker logs` không hoạt động, bạn có thể tìm trực tiếp tệp log trên host.

### Bước 4: Xác Minh Khởi Động Tương Tác

Nếu bạn đã hoàn thành ba bước đầu tiên và vẫn chưa xác định được vấn đề, bạn cần tự vào container.

**Khởi động container tương tác**:

Nếu lệnh khởi động ban đầu của bạn là:

```sh
docker run -d my-app
```

Thay đổi `-d` thành `-it` để chạy container ở foreground:

```sh
docker run -it my-app
```

Điều này cho phép bạn xem tất cả đầu ra trong quá trình khởi động container theo thời gian thực. Nhiều lỗi sẽ hiển thị trực tiếp trên màn hình.

**Thủ công nhập container**:

Nếu container khởi động và lập tức thoát, bạn có thể sử dụng shell để nhập và thủ công thực thi các lệnh:

```sh
docker run -it my-app /bin/bash
```

Hoặc:

```sh
docker run -it my-app /bin/sh
```

Khi bên trong, bạn có thể:

*   Kiểm tra xem các tệp cấu hình có tồn tại không: `ls /etc/app/config.yaml`
*   Kiểm tra cú pháp tệp cấu hình: như `mysqld --verbose --help` của MySQL xác thực cấu hình
*   Thủ công chạy lệnh khởi động để xem các lỗi cụ thể
*   Kiểm tra kết nối dịch vụ phụ thuộc: `ping database`, `telnet redis 6379`

Phương pháp này đặc biệt tốt để khắc phục các vấn đề liên quan đến đường dẫn, quyền hạn và phụ thuộc.

Tôi biết điều này có vẻ như là rất nhiều bước. Nhưng tin tôi, trong thực tế, hầu hết các vấn đề được giải quyết ở bước 2 khi kiểm tra logs. Chỉ các trường hợp cạnh khó xử mới cần tất cả bốn bước.

## 5 Kịch Bản Lỗi Phổ Biến và Giải Pháp

Bây giờ chúng ta đã bao quát các phương pháp khắc phục sự cố, hãy xem xét các kịch bản thực tế. Tôi đã phân loại chúng thành năm loại bao quát hầu hết các vấn đề hàng ngày.

### Kịch Bản 1: Lỗi Tệp Cấu Hình hoặc Đường Dẫn Bị Thiếu

**Các triệu chứng điển hình**:

*   Exit Code 1
*   Logs hiển thị `No such file or directory`, `config file not found`, `syntax error`, v.v.

**Trường hợp thực tế**:

Một lần tôi triển khai một ứng dụng Node.js và container sẽ không khởi động. Logs hiển thị:

```sh
Error: ENOENT: no such file or directory, open '/app/config/prod.json'
```

Sau khi kiểm tra, tôi phát hiện ra rằng tôi đã viết đường dẫn mount trong lệnh `docker run` như:

```sh
-v /home/user/config:/app/conf  # Chú ý đó là "conf"
```

Nhưng app lại đọc từ `/app/config`. Một ký tự khác nhau, và app không thể tìm thấy tệp cấu hình, gây ra lỗi khởi động.

**Phương pháp khắc phục sự cố**:

1.  Sử dụng `docker inspect --format '{{.Mounts}}'` để kiểm tra đường dẫn mount
2.  Nhập container và `ls` để xác minh các tệp thực sự ở vị trí đó
3.  Nếu nó là lỗi cú pháp tệp cấu hình, hầu hết các apps sẽ chỉ định dòng nào trong logs

**Giải pháp**:

Sai đường dẫn mount:

```sh
# Ví dụ sai
docker run -v /host/path:/wrong/path my-app

# Cách tiếp cận chính xác
docker run -v /host/path:/app/config my-app
```

Lỗi cú pháp tệp cấu hình:

*   Đối với tệp YAML, sử dụng công cụ trực tuyến hoặc `yamllint` để kiểm tra cú pháp
*   Đối với tệp JSON, sử dụng `jq` để xác thực: `jq . config.json`
*   Đối với cấu hình MySQL, thực thi `mysqld --verbose --help` trong container để kiểm tra các lỗi cú pháp

### Kịch Bản 2: Hết Bộ Nhớ (OOM Killed)

**Các triệu chứng điển hình**:

*   Exit Code 137
*   `docker inspect --format '{{.State.OOMKilled}}'` trả về `true`
*   Logs có thể hiển thị `Cannot allocate memory`, `Out of memory`, v.v.

**Trường hợp thực tế**:

Tôi có một ứng dụng Java chạy tốt trong môi trường phát triển cục bộ, nhưng cứ khởi động lại khi triển khai trên máy chủ test. Kiểm tra logs:

```sh
OpenJDK 64-Bit Server VM warning: INFO: os::commit_memory failed; error='Cannot allocate memory' (errno=12)
```

Hóa ra Docker Desktop trên máy chủ test chỉ có giới hạn bộ nhớ 512MB, nhưng ứng dụng Java này cần 600MB chỉ để khởi động.

**Phương pháp khắc phục sự cố**:

```sh
# Xác nhận OOM
docker inspect --format '{{.State.OOMKilled}}' <container_id>

# Kiểm tra bộ nhớ của host
free -h

# Kiểm tra mức sử dụng bộ nhớ runtime của container
docker stats <container_id>
```

**Giải pháp**:

Tăng giới hạn bộ nhớ container:

```sh
docker run -m 1g my-app  # Giới hạn bộ nhớ tối đa là 1GB
docker run -m 512m --memory-swap 1g my-app  # Cũng đặt swap
```

Nếu sử dụng Docker Desktop, điều chỉnh trong cài đặt:

*   macOS: Docker Desktop → Preferences → Resources → Memory
*   Windows: Docker Desktop → Settings → Resources → Memory

Tối ưu hóa chính ứng dụng:

*   Ứng dụng Java có thể giới hạn kích thước JVM heap: `java -Xmx512m -jar app.jar`
*   Node.js có thể đặt: `node --max-old-space-size=512 app.js`
*   Kiểm tra mã để tìm memory leaks

Khuyến nghị môi trường production:

*   Đặt các giới hạn bộ nhớ hợp lý dựa trên nhu cầu thực tế của app
*   Cấu hình `--memory-reservation` cho các giới hạn mềm
*   Giám sát xu hướng sử dụng bộ nhớ, scale up một cách chủ động

### Kịch Bản 3: Xung Đột Port

**Các triệu chứng điển hình**:

*   Exit Code 1
*   Logs hiển thị `port is already allocated`, `address already in use`, `bind: address already in use`

**Trường hợp thực tế**:

Thứ Hai sáng tại văn phòng, tôi chạy `docker-compose up` và container Nginx sẽ không khởi động. Thông báo lỗi:

```sh
Error starting userland proxy: listen tcp4 0.0.0.0:80: bind: address already in use
```

Hóa ra tôi đã kiểm tra Nginx cục bộ trước khi rời vào thứ Sáu và quên tắt nó. Port 80 bị chiếm, vì vậy container mới không thể khởi động.

**Phương pháp khắc phục sự cố**:

Kiểm tra mức sử dụng port (Linux/macOS):

```sh
lsof -i :8080
netstat -tuln | grep 8080
```

Kiểm tra mức sử dụng port (Windows):

```sh
netstat -ano | findstr 8080
```

Kiểm tra ánh xạ port của các container khác:

```sh
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

**Giải pháp**:

**Lựa chọn 1**: Thay đổi port ánh xạ

```sh
# Lệnh gốc
docker run -p 8080:8080 my-app

# Thay đổi thành port khác
docker run -p 8081:8080 my-app
```

**Lựa chọn 2**: Dừng dịch vụ sử dụng port

```sh
# Tìm Process ID
lsof -i :8080

# Dừng process
kill -9 <PID>
```

**Lựa chọn 3**: Nếu container khác đang sử dụng, dừng cái đó trước tiên

```sh
docker stop <conflicting_container>
```

**Lưu ý quan trọng**: Nếu bạn sử dụng mode `--network=host`, container trực tiếp sử dụng mạng của host, làm tăng xác suất xung đột port. Trong mode này, các port của container không được xung đột với các port của host.

### Kịch Bản 4: Quyền Hạn Không Đủ

**Các triệu chứng điển hình**:

*   Exit Code 1
*   Logs hiển thị `Permission denied`, `Operation not permitted`, `chown: changing ownership failed`

**Trường hợp thực tế**:

Triển khai một container MongoDB, mount thư mục dữ liệu đến host. Container cứ không khởi động:

```sh
chown: changing ownership of '/data/db': Permission denied
```

Hóa ra thư mục host mà tôi mount thuộc sở hữu của user root, nhưng process MongoDB trong container chạy dưới người dùng mongodb (UID 999), không có quyền ghi vào thư mục đó.

**Phương pháp khắc phục sự cố**:

Kiểm tra quyền của thư mục host:

```sh
ls -la /host/data/path
```

Kiểm tra người dùng bên trong container:

```sh
docker run -it my-app /bin/bash
whoami
id
```

Kiểm tra SELinux (CentOS/RHEL):

```sh
getenforce  # Kiểm tra trạng thái SELinux
```

**Giải pháp**:

**Lựa chọn 1**: Điều chỉnh quyền của thư mục host

```sh
# Cho tất cả người dùng quyền đọc/ghi (không an toàn, chỉ dành cho môi trường dev)
chmod 777 /host/data/path

# Cách tiếp cận an toàn hơn: thay đổi chủ sở hữu
chown -R 999:999 /host/data/path  # 999 là UID của user trong container
```

**Lựa chọn 2**: Sử dụng privileged mode (hãy thận trọng)

```sh
docker run --privileged=true my-app
```

Lưu ý: Privileged mode cấp cho container gần như tất cả các quyền của host. Rủi ro bảo mật. Không được khuyến khích cho production.

**Lựa chọn 3**: Chỉ định user chạy

```sh
docker run --user 1000:1000 my-app  # Sử dụng UID/GID của host
```

**Lựa chọn 4**: Xử lý các vấn đề SELinux

```sh
# Phương pháp 1: Thêm nhãn Z (sửa đổi nhãn tệp của host)
docker run -v /host/path:/container/path:Z my-app

# Phương pháp 2: Thêm nhãn z (nhãn dùng chung)
docker run -v /host/path:/container/path:z my-app

# Phương pháp 3: Tạm thời vô hiệu hóa SELinux (không được khuyến khích cho production)
setenforce 0
```

### Kịch Bản 5: Dịch Vụ Phụ Thuộc Chưa Sẵn Sàng

**Các triệu chứng điển hình**:

*   Exit Code 1
*   Logs hiển thị lỗi kết nối database, timeout kết nối Redis, v.v.
*   `Connection refused`, `ECONNREFUSED`, `could not connect to server`

**Trường hợp thực tế**:

Sử dụng docker-compose để triển khai một ngăn xếp microservice với một container ứng dụng phụ thuộc vào database MySQL. Cả hai container đã khởi động gần như đồng thời, nhưng container ứng dụng luôn bị lỗi:

```sh
Error: connect ECONNREFUSED 172.18.0.2:3306
```

Vấn đề: mặc dù container MySQL đã khởi động, dịch vụ MySQL vẫn đang khởi tạo và chưa sẵn sàng chấp nhận các kết nối. Container ứng dụng khởi động quá nhanh, kết nối thất bại, sau đó thoát.

**Phương pháp khắc phục sự cố**:

Kiểm tra xem các dịch vụ phụ thuộc có chạy không:

```sh
docker ps  # Kiểm tra xem các container phụ thuộc có chạy không
```

Kiểm tra kết nối mạng:

```sh
docker exec my-app ping database
docker exec my-app telnet database 3306
docker exec my-app nc -zv database 3306
```

Kiểm tra cấu hình mạng Docker:

```sh
docker network ls
docker network inspect <network_name>
```

**Giải pháp**:

**Lựa chọn 1**: Sử dụng docker-compose health checks và depends_on

```yaml
version: '3.8'
services:
  database:
    image: mysql:8.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: my-app
    depends_on:
      database:
        condition: service_healthy  # Chờ health check của database vượt qua
```

**Lựa chọn 2**: Thêm retry logic ở tầng ứng dụng

Thêm retry logic ở mã ứng dụng:

```js
// Ví dụ Node.js
async function connectWithRetry(maxRetries = 5) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await db.connect();
      console.log('Database connected');
      return;
    } catch (err) {
      console.log(`Connection failed, retrying... (${i+1}/${maxRetries})`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
  throw new Error('Failed to connect to database');
}
```

**Lựa chọn 3**: Sử dụng startup wait script

Thêm một wait script trước khi khởi động container, giống như `wait-for-it.sh`:

```Dockerfile
# Trong Dockerfile
COPY wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

# Sử dụng khi khởi động
CMD ["wait-for-it.sh", "database:3306", "--", "node", "app.js"]
```

**Lựa chọn 4**: Cấu hình restart policy

Cho phép container tự động thử lại khi bị lỗi:

```sh
docker run --restart=on-failure:3 my-app  # Thử lại tối đa 3 lần khi bị lỗi
```

Trong docker-compose:

```yaml
services:
  app:
    restart: on-failure
```

Những giải pháp này có thể được kết hợp—health checks + application retry + restart policy cho bảo hiểm ba lớp.

## Các Biện Pháp Phòng Ngừa và Thực Hành Tốt Nhất

Mọi thứ ở trên là về sửa chữa các vấn đề sau khi chúng xảy ra. Nhưng thực tế, nếu bạn cấu hình các cơ chế nhất định từ đầu, nhiều vấn đề sẽ không xảy ra hoặc có thể tự phục hồi khi chúng xảy ra.

### Cấu Hình Health Checks (HEALTHCHECK)

Health checks là cơ chế tự chẩn đoán của Docker container. Bằng cách định kỳ chạy các lệnh kiểm tra, Docker có thể xác định xem container có thực sự hoạt động bình thường hay không, không chỉ là process còn sống.

Cấu hình trong Dockerfile:

```Dockerfile
FROM nginx:alpine

# Kiểm tra mỗi 30 giây, timeout 3 giây, đánh dấu không khỏe mạnh sau 3 lần thất bại liên tiếp
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
```

Đối với web services, kiểm tra HTTP endpoints:

```Dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s \
  CMD curl -f http://localhost:8080/health || exit 1
```

Đối với databases, sử dụng các lệnh chuyên dụng:

```Dockerfile
# MySQL
HEALTHCHECK CMD mysqladmin ping -h localhost || exit 1

# PostgreSQL
HEALTHCHECK CMD pg_isready -U postgres || exit 1

# Redis
HEALTHCHECK CMD redis-cli ping || exit 1
```

Lợi ích của health check:

*   **Kubernetes/Swarm orchestrators** tự động khởi động lại hoặc sắp xếp lại các container dựa trên trạng thái sức khỏe
*   **docker-compose depends_on** có thể chờ các dịch vụ thực sự khỏe mạnh trước khi khởi động các container phụ thuộc
*   **Monitoring systems** có thể cảnh báo dựa trên trạng thái sức khỏe

Xem trạng thái sức khỏe:

```sh
docker ps  # Cột STATUS hiển thị trạng thái sức khỏe
docker inspect --format='{{.State.Health.Status}}' <container_id>
```

### Đặt Restart Policies

Restart policies cho phép các container tự động phục hồi từ các lỗi mà không cần bạn thủ công khởi động lại lúc 3 giờ sáng.

Docker cung cấp bốn restart policies:

**no** (mặc định): Không tự động khởi động lại

```sh
docker run --restart=no my-app
```

Phù hợp cho các tác vụ một lần, các container hoàn thành và thoát.

**on-failure\[:max-retries\]**: Chỉ khởi động lại khi thoát bất thường

```sh
docker run --restart=on-failure:5 my-app  # Thử lại tối đa 5 lần
```

Phù hợp cho các dịch vụ có thể bị lỗi nhưng bạn không muốn thử lại vô hạn. Lưu ý: chỉ khởi động lại khi Exit Code không phải 0.

**always**: Luôn khởi động lại

```sh
docker run --restart=always my-app
```

Phù hợp cho các dịch vụ chạy lâu dài như web servers, API services. Ngay cả khi dừng thủ công, nó sẽ tự động khởi động khi Docker Daemon khởi động lại.

**unless-stopped**: Luôn khởi động lại trừ khi dừng thủ công

```sh
docker run --restart=unless-stopped my-app
```

Tương tự như always, nhưng nếu bạn thủ công `docker stop`, nó sẽ không tự động khởi động khi Docker Daemon khởi động lại. Đây là policy mà tôi sử dụng nhiều nhất—cho tôi một số kiểm soát.

**Lưu ý quan trọng**:

1.  **Quy tắc 10 giây**: Container phải chạy ít nhất 10 giây sau khi khởi động lần đầu tiên để restart policy hoạt động. Điều này ngăn chặn các vòng khởi động lại vô hạn do các lỗi cấu hình tiêu thụ tài nguyên hệ thống.
2.  **Bẫy khởi động lại vô hạn**: Nếu container cứ khởi động lại do lỗi cấu hình (như xung đột port), logs sẽ phát nổ. Hãy nhớ sử dụng với log rotation.

Đối với các container đang chạy, bạn có thể động thay đổi policy:

```sh
docker update --restart=unless-stopped <container_id>
```

Cấu hình trong docker-compose:

```yaml
services:
  web:
    image: nginx
    restart: unless-stopped  # Được khuyến khích cho production

  worker:
    image: my-worker
    restart: on-failure  # Có thể bị lỗi, nhưng không muốn thử lại vô hạn
```

### Quản Lý Log: Ngăn Chặn Đĩa Đầy

Docker theo mặc định lưu tất cả logs container trong các tệp JSON. Theo thời gian, những tệp log này có thể tiêu thụ hàng chục GB dung lượng đĩa. Tôi đã trải qua các trường hợp server production bị sự cố vì Docker logs lấp đầy đĩa.

Cấu hình log rotation (được khuyến khích):
Tạo hoặc chỉnh sửa `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",    // Tối đa 10MB mỗi tệp log
    "max-file": "3"       // Giữ tối đa 3 tệp log
  }
}
```

Khởi động lại Docker sau khi sửa đổi:

```sh
sudo systemctl restart docker
```

Theo cách này, mỗi container sử dụng tối đa 30MB không gian log (10MB × 3), logs cũ tự động xóa.

Cấu hình cho từng container riêng lẻ:

```sh
docker run --log-opt max-size=10m --log-opt max-file=3 my-app
```

Trong docker-compose:

```yaml
services:
  app:
    image: my-app
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

Các tùy chọn log driver khác:

*   **syslog**: Gửi đến system log
*   **journald**: Sử dụng journal của systemd
*   **fluentd**: Gửi đến Fluentd để quản lý tập trung
*   **none**: Không log (không được khuyến khích)

Kiểm tra vị trí và kích thước tệp log của container:

```sh
docker inspect --format='{{.LogPath}}' <container_id>
du -h $(docker inspect --format='{{.LogPath}}' <container_id>)
```

### Giám Sát và Alerts: Phát Hiện Vấn Đề Sớm

Đừng chờ cho đến khi các container crash để phát hiện ra. Giám sát chủ động ngăn chặn nhiều sự cố production.

**Giám sát cơ bản: docker stats**

```sh
docker stats  # Hiển thị thời gian thực mức sử dụng tài nguyên của tất cả containers
docker stats <container_id>  # Giám sát container cụ thể
```

Lệnh này hiển thị dữ liệu thời gian thực trên CPU, bộ nhớ, network IO, disk IO. Nếu bạn thấy mức sử dụng bộ nhớ tăng liên tục, có thể có memory leak—xử lý nó một cách chủ động.

**Môi trường production: Prometheus + Grafana**

Cách tiếp cận chuyên nghiệp hơn là sử dụng Prometheus để thu thập các số liệu, Grafana để trực quan hóa:

```yaml
# docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"

  cadvisor:  # Thu thập các số liệu container
    image: google/cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    ports:
      - "8080:8080"
```

Cấu hình các quy tắc cảnh báo cho các điều kiện như mức sử dụng bộ nhớ vượt quá 80%, khởi động lại container quá nhiều, v.v., để tự động gửi thông báo.

**Đơn giản và thô sơ: Script được lên lịch**

Nếu bạn nghĩ Prometheus quá phức tạp, viết một script đơn giản:

```sh
#!/bin/bash
# check-containers.sh

# Kiểm tra bất kỳ container nào ở trạng thái Exited
EXITED=$(docker ps -a -f "status=exited" --format "{{.Names}}")

if [ -n "$EXITED" ]; then
  echo "Warning: The following containers are exited:"
  echo "$EXITED"
  # Có thể gửi email hoặc thông báo push ở đây
fi
```

Thêm vào crontab để chạy mỗi 5 phút:

```sh
*/5 * * * * /path/to/check-containers.sh
```

### Danh Sách Kiểm Tra Cấu Hình Môi Trường Production

Cuối cùng, đây là danh sách kiểm tra cấu hình môi trường production. Thực hiện theo cái này và bạn sẽ tránh được hầu hết các vấn đề lớn:

```yaml
version: '3.8'
services:
  web:
    image: my-web-app:latest

    # Restart policy
    restart: unless-stopped

    # Giới hạn tài nguyên
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          memory: 512M

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s

    # Quản lý log
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

    # Biến môi trường (sử dụng secrets cho thông tin nhạy cảm)
    environment:
      - NODE_ENV=production

    # Ánh xạ port
    ports:
      - "8080:8080"

    # Phụ thuộc
    depends_on:
      database:
        condition: service_healthy

  database:
    image: postgres:14
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - db-data:/var/lib/postgresql/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  db-data:
```

Với cấu hình này, các container bị crash sẽ tự động khởi động lại, các quá tải tài nguyên sẽ bị giới hạn, logs sẽ không lấp đầy đĩa, và giám sát sẽ cung cấp cảnh báo sớm. Bạn có thể ngủ yên tâm.

## Kết Luận

Sau tất cả điều này, tôi hy vọng bạn nhớ: các lỗi khởi động container Docker không đáng sợ. Điều đáng sợ là không có một cách tiếp cận khắc phục sự cố có hệ thống.

Hãy tóm tắt lại nội dung cốt lõi:

**Hiểu mã thoát**: Thấy 137, hãy nghĩ về vấn đề bộ nhớ. Thấy 1, hãy nghĩ về vấn đề cấu hình hoặc phụ thuộc. Exit codes là những manh mối mà Docker để lại cho bạn—đừng bỏ qua chúng.

**Chẩn đoán 4 bước**:

1.  Kiểm tra trạng thái container (`docker ps -a`)
2.  Kiểm tra logs (`docker logs`)
3.  Kiểm tra cấu hình (`docker inspect`)
4.  Xác minh tương tác (`docker run -it`)

Hơn 90% các vấn đề được giải quyết ở bước 2.

**5 kịch bản phổ biến**: Lỗi cấu hình, thiếu bộ nhớ, xung đột port, vấn đề quyền hạn, phụ thuộc không sẵn sàng. Hãy nhớ những phương pháp khắc phục sự cố này và bạn sẽ được bao quát cho hầu hết các trường hợp.

**Phòng ngừa chủ động**: Cấu hình health checks, đặt restart policies, quản lý logs tốt, giám sát đúng cách. Những cơ chế này làm cho các container ổn định hơn và tự phục hồi khi các vấn đề xảy ra.

Cuối cùng, đây là một danh sách kiểm tra khắc phục sự cố nhanh mà bạn có thể chụp màn hình:

```
Danh Sách Kiểm Tra Khắc Phục Sự Cố Docker Container Khởi Động

□ Bước 1: docker ps -a kiểm tra trạng thái container và mã thoát
□ Bước 2: docker logs <container_id> kiểm tra logs chi tiết
□ Bước 3: docker inspect <container_id> kiểm tra cấu hình
□ Bước 4: docker run -it <image> xác minh tương tác

Xác định vấn đề nhanh cho các vấn đề phổ biến:
- Exit Code 1 + "No such file" → Kiểm tra đường dẫn mount và tệp cấu hình
- Exit Code 1 + "port already allocated" → Kiểm tra xung đột port
- Exit Code 1 + "Permission denied" → Kiểm tra quyền tệp và SELinux
- Exit Code 1 + "Connection refused" → Kiểm tra xem các dịch vụ phụ thuộc đã sẵn sàng chưa
- Exit Code 137 + OOMKilled=true → Tăng giới hạn bộ nhớ
- Exit Code 127 → Kiểm tra tính chính xác của đường dẫn CMD/ENTRYPOINT

Biện pháp phòng ngừa:
□ Cấu hình HEALTHCHECK
□ Đặt restart policy (khuyên dùng unless-stopped)
□ Cấu hình log rotation (max-size + max-file)
□ Giới hạn tài nguyên (-m memory limit)
□ Giám sát cảnh báo (docker stats hoặc Prometheus)
```
