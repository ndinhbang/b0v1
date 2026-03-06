# Docker Security Best Practices: Dừng Chạy Container Với Quyền Root · BetterLink Blog

Mục lục

*   [Tại Sao Không Nên Chạy Container Với Quyền Root](#tại-sao-không-nên-chạy-container-với-quyền-root)
*   [Container Escape: Từ Sandbox Tới Host Chỉ Một Bước](#container-escape-từ-sandbox-tới-host-chỉ-một-bước)
*   [Tại Sao Người Dùng Root Là Vi Phạm Bảo Mật Lớn Nhất](#tại-sao-người-dùng-root-là-vi-phạm-bảo-mật-lớn-nhất)
*   [Cấu Hình Người Dùng Non-Root: Bắt Đầu Với Dockerfile](#cấu-hình-người-dùng-non-root-bắt-đầu-với-dockerfile)
*   [Cách Đúng Để Tạo Người Dùng Non-Root](#cách-đúng-để-tạo-người-dùng-non-root)
*   [Những Lỗi Thường Gặp Và Giải Pháp](#những-lỗi-thường-gặp-và-giải-pháp)
*   [Các Tham Số Bảo Mật Runtime: —user Và Hơn Nữa](#các-tham-số-bảo-mật-runtime-user-và-hơn-nữa)
*   [Ghi Đè Cài Đặt Image Với —user](#ghi-đè-cài-đặt-image-với-user)
*   [Filesystem Chỉ Đọc: Kẻ Tấn Công Không Thể Ghi File](#filesystem-chỉ-đọc-kẻ-tấn-công-không-thể-ghi-file)
*   [Ngăn Chặn Privilege Escalation: no-new-privileges](#ngăn-chặn-privilege-escalation-no-new-privileges)
*   [Cấu Hình Production-Grade: Sự Kết Hợp](#cấu-hình-production-grade-sự-kết-hợp)
*   [Kiểm Soát Quyền Chi Tiết: Cơ Chế Capabilities](#kiểm-soát-quyền-chi-tiết-cơ-chế-capabilities)
*   [Capabilities Là Gì? Tại Sao Chúng An Toàn Hơn Root?](#capabilities-là-gì-tại-sao-chúng-an-toàn-hơn-root)
*   [Danh Sách Capabilities Nguy Hiểm (Không Bao Giờ Cấp!)](#danh-sách-capabilities-nguy-hiểm-không-bao-giờ-cấp)
*   [Cấu Hình Ưu Tiên Tối Thiểu Trong Thực Tế](#cấu-hình-ưu-tiên-tối-thiểu-trong-thực-tế)
*   [Cách Xác Định Ứng Dụng Cần Những Capabilities Nào?](#cách-xác-định-ứng-dụng-cần-những-capabilities-nào)
*   [Kiểm Soát Truy Cập Bắt Buộc: AppArmor Và SELinux](#kiểm-soát-truy-cập-bắt-buộc-apparmor-và-selinux)
*   [Những Cái Này Làm Gì? Nói Đơn Giản](#những-cái-này-làm-gì-nói-đơn-giản)
*   [AppArmor: Đơn Giản Và Đủ (Khuyến Nghị Cho Người Mới)](#apparmor-đơn-giản-và-đủ-khuyến-nghị-cho-người-mới)
*   [SELinux: Mạnh Hơn Nhưng Phức Tạp Hơn](#selinux-mạnh-hơn-nhưng-phức-tạp-hơn)
*   [Lời Khuyên Thực Tế: Dùng Cái Nào? Như Thế Nào?](#lời-khuyên-thực-tế-dùng-cái-nào-như-thế-nào)
*   [Xây Dựng Danh Sách Kiểm Tra Bảo Mật Hoàn Chỉnh](#xây-dựng-danh-sách-kiểm-tra-bảo-mật-hoàn-chỉnh)
*   [Giai Đoạn Build Image](#giai-đoạn-build-image)
*   [Giai Đoạn Quét Image](#giai-đoạn-quét-image)
*   [Kiểm Tra Cấu Hình Runtime](#kiểm-tra-cấu-hình-runtime)
*   [Kiểm Tra Các Hoạt Động Production](#kiểm-tra-các-hoạt-động-production)
*   [Những Vấn Đề Thường Gặp Và Giải Pháp](#những-vấn-đề-thường-gặp-và-giải-pháp)
*   [Q1: Lỗi Quyền Truy Cập Ứng Dụng Sau Khi Chuyển Sang Non-Root?](#q1-lỗi-quyền-truy-cập-ứng-dụng-sau-khi-chuyển-sang-non-root)
*   [Q2: Không Phù Hợp Quyền Volume Sau Khi Mount?](#q2-không-phù-hợp-quyền-volume-sau-khi-mount)
*   [Q3: Những Tình Huống Nào Thực Sự Cần Root? Hầu Như Không Có!](#q3-những-tình-huống-nào-thực-sự-cần-root-hầu-như-không-có)
*   [Q4: Image Của Bên Thứ Ba Chạy Với Quyền Root?](#q4-image-của-bên-thứ-ba-chạy-với-quyền-root)
*   [Kết Luận](#kết-luận)


> "76% các image trên Docker Hub chứa lỗ hổng bảo mật, 67% có các lỗ hổng nghiêm trọng."

## Tại Sao Không Nên Chạy Container Với Quyền Root

### Container Escape: Từ Sandbox Tới Host Chỉ Một Bước

Nhiều người nghĩ container bằng sandbox—bất kỳ điều gì xảy ra bên trong không thể ảnh hưởng đến host. Kiểm tra thực tế: cách cô lập container dựa vào các Linux namespaces và cgroups, không phải cô lập ở mức phần cứng như máy ảo. Với các sai cấu hình hoặc lỗ hổng kernel, sự cô lập này mỏng như giấy.

CVE-2024-21626 là một bài học đau đớn. Những kẻ tấn công phát hiện rằng runc (runtime bên dưới của Docker) rò rỉ một file descriptor trỏ tới filesystem của host khi xử lý các thư mục làm việc. Nghe có vẻ kỹ thuật? Nói đơn giản, những kẻ tấn công có thể đọc/ghi bất kỳ file host nào qua lỗ hổng này, thậm chí ghi đè các thực thi quan trọng như `/usr/bin/bash`. Hãy tưởng tượng container ứng dụng web của bạn bị hack, và những kẻ tấn công thay thế tất cả các container trên host bằng crypto miners—điều này không phải là giả thuyết, nó thực sự đã xảy ra.

Một vectơ tấn công phổ biến hơn là chế độ `--privileged`. Tham số này về cơ bản cho Docker biết: "Hãy cấp cho container này tất cả các quyền của host." Người dùng root bên trong nhận được tất cả các capabilities host root: mount thiết bị, tải các module kernel, sửa đổi cấu hình mạng… Nghiên cứu của NSFOCUS chi tiết một trường hợp mà những kẻ tấn công sử dụng một container có quyền để mount ổ cứng của host bằng một lệnh: `mount /dev/sda1 /mnt`, sau đó thêm một cron job để exfiltration dữ liệu. Tổng thời gian: dưới mười phút.

Một rủi ro khác trôi dạt: mount Docker Socket. Một số người, vì tiện lợi, mount `/var/run/docker.sock` vào các container để quản lý các container khác từ bên trong. Điều này trao cho những kẻ tấn công các chìa khóa để kiểm soát tất cả các container trên host. Sau khi breach một container như vậy, họ có thể tạo một container có quyền mới và escape để kiểm soát host. Đội bảo mật của Tencent Cloud đã ghi chép chính xác chuỗi tấn công này.

### Tại Sao Người Dùng Root Là Vi Phạm Bảo Mật Lớn Nhất

Vấn đề cốt lõi: **root UID 0 bên trong container cũng là người dùng root UID 0 trên host**.

Bạn có thể tự hỏi, chúng ta không có cô lập namespace sao? Có, nhưng UID namespaces không được bật theo mặc định (vì lý do tương thích). Khi các process container chạy với quyền root và cô lập namespace không thành công do các lỗ hổng kernel hoặc sai cấu hình, process đó xuất hiện dưới dạng root trên host. Tôi đã kiểm tra điều này: trong một container có SYS\_ADMIN Capability, sử dụng root để mount host procfs và ghi một reverse shell vào `/proc/sys/kernel/core_pattern`—thành công nhận được quyền truy cập root host. Đơn giản hơn mong đợi.

Báo cáo bảo mật của Alibaba Cloud đề cập năm nguyên nhân chính gây ra container escapes: lỗ hổng kernel, sai cấu hình, các image không bảo mật, lạm dụng quyền, và giao tiếp giữa các container không an toàn. Bốn trong số đó liên quan trực tiếp đến quyền root. Chạy với quyền non-root làm giảm ít nhất ba trong số những rủi ro này đi một nửa.

Dưới đây là một kịch bản thực tế: Nhiều ứng dụng Node.js muốn lắng nghe trên cổng 80, nhưng Linux hạn chế các cổng dưới 1024 cho root. Vì vậy mọi người chỉ chạy các ứng dụng với quyền root. Nhưng nếu code Express của bạn có lỗ hổng path traversal, những kẻ tấn công có thể đọc `/etc/passwd` và cố gắng SSH login vào host—không cần container escape, tấn công mạng trực tiếp trên host.

Đáng sợ, phải không? Nhưng giải pháp không phức tạp. Chìa khóa là: **nguyên tắc ưu tiên tối thiểu**. Chỉ cấp cho ứng dụng những quyền mà chúng cần, không mặc định là root.

## Cấu Hình Người Dùng Non-Root: Bắt Đầu Với Dockerfile

### Cách Đúng Để Tạo Người Dùng Non-Root

Hãy xem cách tiếp cận tiêu chuẩn:

```
FROM node:18-alpine

# Tạo người dùng và nhóm chuyên dụng (chỉ định UID/GID)
RUN addgroup -g 5000 appgroup \
    && adduser -D -u 5000 -G appgroup appuser

# Đặt thư mục làm việc
WORKDIR /app

# Sao chép các file và đặt chủ sở hữu (bước quan trọng!)
COPY --chown=appuser:appgroup package*.json ./
RUN npm install
COPY --chown=appuser:appgroup . .

# Chuyển sang người dùng non-root (tất cả các lệnh tiếp theo chạy dưới quyền appuser)
USER appuser

# Khởi động ứng dụng
CMD ["node", "server.js"]
```

Nghe có vẻ đơn giản, phải không? Nhưng mỗi dòng có mục đích.

**Tại Sao Chỉ Định UID Và GID?** Nhiều người không chỉ định số khi sử dụng `useradd`, để hệ thống tự động gán. Vấn đề là các container khác nhau có thể nhận được các UID khác nhau. Khi mount các data volumes, các file được tạo bởi container A có thể không truy cập được trong container B. Chỉ định một UID cố định (như 5000) giữ tất cả các container nhất quán, giảm đáng kể các vấn đề về quyền.

**Phép màu của `COPY --chown` là gì?** Nếu bạn sử dụng `COPY` bình thường rồi `RUN chown`, Docker tạo hai layer image: layer đầu tiên sao chép dưới quyền root (các file thuộc sở hữu của root), layer thứ hai chown chủ sở hữu. Tham số `--chown` đặt chủ sở hữu chính xác trong quá trình sao chép, tiết kiệm không gian và cải thiện bảo mật. Một lần tôi quên chown dẫn đến "Permission denied" khi khởi động—mất nửa giờ để debug.

**Vị trí chỉ thị USER rất quan trọng.** Các lệnh trước nó vẫn chạy với quyền root (như `RUN npm install` cần quyền ghi vào `/app`), chỉ sau khi chuyển sang appuser. Nhiều người đặt USER quá sớm, phá vỡ các lệnh cài đặt tiếp theo. Hãy nhớ: **các hoạt động yêu cầu root phải trước USER**.

### Những Lỗi Thường Gặp Và Giải Pháp

**Lỗi 1: Vấn Đề Ràng Buộc Cổng**

Bạn háo hức chuyển sang non-root, sau đó container không thành công với: `Error: listen EACCES: permission denied 0.0.0.0:80`. Vì các cổng dưới 1024 yêu cầu quyền.

Giải pháp:

1.  **Sử Dụng Các Cổng Cao** (được khuyến nghị): Có ứng dụng lắng nghe trên 3000 hoặc 8080, sử dụng Nginx hoặc load balancer cho reverse proxy
2.  **Sử Dụng NET\_BIND\_SERVICE Capability**: Chúng tôi sẽ đề cập sau, nó cho phép người dùng non-root ràng buộc các cổng thấp

```Dockerfile
# Thay đổi ứng dụng để lắng nghe trên cổng 3000
EXPOSE 3000
USER appuser
CMD ["node", "server.js"]  # Lắng nghe trên 3000 nội bộ
```

Sau đó map trong docker-compose hoặc K8s:

```yaml
ports:
  - "80:3000"  # Cổng host 80 map tới cổng container 3000
```

**Lỗi 2: Ghi File Log Và Temp**

Một lần tôi chuyển một ứng dụng Python sang non-root, và nó tiếp tục không thành công. Mất rất nhiều thời gian để nhận ra ứng dụng muốn ghi log vào `/var/log`, nhưng appuser không có quyền.

```Dockerfile
# Tạo thư mục log và phân quyền cho người dùng ứng dụng
RUN mkdir -p /var/log/myapp && \
    chown -R appuser:appgroup /var/log/myapp

USER appuser
```

Cách tiếp cận tốt hơn: **Có ứng dụng ghi vào stdout/stderr**, để Docker hoặc K8s xử lý thu thập log. Sửa đổi cấu hình ứng dụng:

```sh
# Không ghi log file
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
```

**Lỗi 3: Không Phù Hợp Quyền Volume Đã Mount**

Bạn có một thư mục `/data` trên host thuộc sở hữu của root, mount nó trong container nơi appuser (UID 5000) không thể truy cập.

```sh
# Ví dụ sai
docker run -v /data:/app/data myapp
# appuser trong container không thể đọc/ghi /app/data
```

Hai giải pháp:

```sh
# Giải pháp 1: Đặt trước quyền trên host
sudo chown -R 5000:5000 /data

# Giải pháp 2: Sử dụng named volumes (Docker quản lý quyền)
docker volume create appdata
docker run -v appdata:/app/data myapp
```

## Các Tham Số Bảo Mật Runtime: —user Và Hơn Nữa

### Ghi Đè Cài Đặt Image Với —user

Đôi khi bạn nhận được một image của bên thứ ba mà không có chỉ thị USER, tất cả chạy với quyền root. Xây dựng lại image rất tẻ nhạt? Tham số `--user` chỉ định người dùng tại runtime:

```sh
# Phương pháp 1: Trực tiếp chỉ định UID:GID
docker run --user=1001:1001 nginx:latest

# Phương pháp 2: Sử dụng người dùng host hiện tại (cài đặt động, tuyệt vời cho dev)
docker run --user="$(id -u):$(id -g)" -v "$PWD:/app" node:18 npm test

# Phương pháp 3: Sử dụng tên người dùng được biết đến (nếu người dùng tồn tại trong image)
docker run --user=nobody redis:alpine
```

Tôi đặc biệt thích phương pháp 2 cho phát triển cục bộ. Khi chạy các bài kiểm tra trong các container tạo báo cáo, sử dụng UID của bạn có nghĩa là các file được tạo có quyền chính xác trên host—không cần sudo để xóa file.

Lưu ý: **tham số —user ghi đè chỉ thị USER của Dockerfile**. Nếu một image được cấu hình cho non-root và bạn sử dụng `--user=0:0`, bạn lại quay lại root. Kiểm tra cấu hình mặc định của image khi sử dụng tham số này.

### Filesystem Chỉ Đọc: Kẻ Tấn Công Không Thể Ghi File

Hãy tưởng tượng những kẻ tấn công breach container của bạn và muốn trồng malware hoặc sửa đổi cấu hình—nếu filesystem chỉ đọc, hiệu quả tấn công của họ giảm đáng kể.

```sh
# Cấu hình chỉ đọc đơn giản nhất
docker run -d --read-only nginx:alpine

# Nhưng nhiều ứng dụng cần các file temp, sao bây giờ?
docker run -d \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /var/run \
  nginx:alpine
```

Tham số `--tmpfs` mount các filesystem bộ nhớ mất sau khi khởi động lại, hoàn hảo cho các file tạm. Tôi cấu hình một dịch vụ API theo cách này—log tới stdout, dữ liệu phiên trong Redis, không cần ghi liên tục. Filesystem chỉ đọc có nghĩa là ngay cả khi những kẻ tấn công lấy được shell access, họ không thể làm nhiều.

### Ngăn Chặn Privilege Escalation: no-new-privileges

Tham số này ngăn chặn các process bên trong container từ việc nâng cao quyền thông qua setuid, setgid, v.v. Nói một cách đơn giản, thậm chí nếu container có một `/bin/su` có SUID-bit, người dùng không thể sử dụng nó để nâng cao quyền thành root.

```sh
docker run --security-opt=no-new-privileges myapp
```

Hiệu quả thực tế: Tôi đã kiểm tra chạy `sudo` trong một container với tùy chọn này được bật—lỗi ngay lập tức "effective uid is not 0". Cực kỳ hiệu quả chống lại các cuộc tấn công nâng cao quyền.

### Cấu Hình Production-Grade: Sự Kết Hợp

Kết hợp các tham số này cho một cấu hình bảo mật được cứng hóa nghiêm túc:

```sh
docker run -d \
  --name secure-webapp \
  --user=5000:5000 \         # Người dùng non-root
  --read-only \               # Filesystem chỉ đọc
  --tmpfs /tmp:size=64M \     # 64MB không gian file tạm
  --security-opt=no-new-privileges \  # Ngăn chặn privilege escalation
  --cap-drop=ALL \            # Loại bỏ tất cả Capabilities
  --cap-add=NET_BIND_SERVICE \ # Chỉ thêm quyền ràng buộc cổng cần thiết
  -p 443:8443 \               # Mapping cổng
  -v appdata:/app/data \      # Data volume (vị trí duy nhất có thể ghi)
  --memory=512m \             # Giới hạn bộ nhớ
  --cpus=1.0 \                # Giới hạn CPU
  myapp:1.0.0
```

Trông như nhiều tham số, nhưng mỗi cái phục vụ một mục đích rõ ràng. Tôi đã chạy nhiều dịch vụ cốt lõi trong production với mẫu này trong hơn hai năm mà không có sự cố bảo mật. Chi phí duy nhất là việc debug khó hơn một chút—không thể exec vào các container để sửa đổi file, nhưng chi phí đó hoàn toàn xứng đáng.

Nhân tiện, người dùng K8s có thể cấu hình các chính sách tương tự trong Pod SecurityContext:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 5000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
    add: ["NET_BIND_SERVICE"]
```

## Kiểm Soát Quyền Chi Tiết: Cơ Chế Capabilities

### Capabilities Là Gì? Tại Sao Chúng An Toàn Hơn Root?

Các quyền Linux truyền thống là "tất cả hoặc không gì": bạn là root và có thể làm bất kỳ điều gì, hoặc bạn là một người dùng thông thường và không thể làm nhiều. Capabilities chia ra các siêu lực của root thành 40+ "khả năng" độc lập—bạn có thể chỉ cấp các quy trình những gì họ cần.

Ẩn dụ: root giống như có một thẻ chủ yếu tới tất cả các phòng, Capabilities cấp cho bạn các chìa khóa riêng lẻ chỉ cho các phòng bạn cần truy cập. Ngay cả khi những kẻ tấn công lấy được chìa khóa của bạn, họ chỉ có thể vào các phòng được phép, không phải trung tâm dữ liệu.

Docker theo mặc định bảo tồn 14 Capabilities cho các container, bao gồm:

*   **CHOWN**: Thay đổi quyền sở hữu file
*   **NET\_BIND\_SERVICE**: Ràng buộc các cổng dưới 1024
*   **SETUID/SETGID**: Thay đổi ID người dùng/nhóm
*   **KILL**: Gửi tín hiệu tới các quy trình khác
*   **DAC\_OVERRIDE**: Bỏ qua các kiểm tra quyền đọc/ghi file

Không nghe có vẻ nhiều? Đối với hầu hết các ứng dụng đó là đủ. Nhưng một số Capabilities đặc biệt nguy hiểm và phải bị loại bỏ.

### Danh Sách Capabilities Nguy Hiểm (Không Bao Giờ Cấp!)

**SYS\_ADMIN - Tương Đương Một Nửa Root**

Capability này có thể làm quá nhiều thứ: mount các filesystem, sửa đổi namespaces, tải các module kernel… Trường hợp tồi tệ nhất mà tôi từng thấy là một container với SYS\_ADMIN. Những kẻ tấn công tiến vào, sử dụng lệnh `unshare` để tạo một namespace mount mới, mount các ổ đĩa host. Trò chơi kết thúc.

```sh
# Không bao giờ làm điều này!
docker run --cap-add=SYS_ADMIN myapp  # ❌ Nguy Hiểm!
```

**NET\_ADMIN - Kiểm Soát Cấu Hình Mạng**

Có thể sửa đổi các bảng định tuyến, cấu hình tường lửa, snooping lưu lượng truy cập mạng. Trừ khi container của bạn là theo nghĩa đen một công cụ mạng (VPN, bộ định tuyến phần mềm, v.v.), đừng cấp nó.

**SYS\_MODULE - Tải Các Module Kernel**

Theo nghĩa đen có thể tiêm mã vào kernel. Hãy nghĩ về mức độ nguy hiểm của điều đó.

### Cấu Hình Ưu Tiên Tối Thiểu Trong Thực Tế

**Chiến lược 1: Loại bỏ Tất cả Trước, Thêm Theo Yêu Cầu (Được khuyến nghị)**

```sh
docker run -d \
  --cap-drop=ALL \          # Xóa tất cả Capabilities
  --cap-add=NET_BIND_SERVICE \  # Chỉ thêm ràng buộc cổng (nếu cần)
  --cap-add=CHOWN \         # Chỉ thêm thay đổi quyền sở hữu file (nếu cần)
  myapp
```

Đây là chiến lược phổ biến nhất của tôi. Bạn có thể gặp lỗi về các Capabilities còn thiếu ban đầu, sau đó thêm dựa trên các thông báo lỗi. Ví dụ, nếu ứng dụng của bạn cần thay đổi người dùng quy trình (các lệnh `setuid()`), bạn sẽ nhận được "Operation not permitted", sau đó thêm `--cap-add=SETUID`.

**Chiến lược 2: Chỉ Loại Bỏ Các Cái Nguy Hiểm (Cứng Hóa Nhanh Chóng)**

```sh
docker run -d \
  --cap-drop=SYS_ADMIN \
  --cap-drop=NET_ADMIN \
  --cap-drop=SYS_MODULE \
  --cap-drop=SYS_RAWIO \
  myapp
```

Phù hợp khi bạn không chắc chắn ứng dụng của bạn cần những Capabilities nào nhưng muốn nhanh chóng loại bỏ các cái rõ ràng nguy hiểm.

### Cách Xác Định Ứng Dụng Cần Những Capabilities Nào?

**Phương pháp 1: Thử Và Lỗi (Tồi Tệ Nhưng Hiệu Quả)**

```sh
# Bước 1: Loại bỏ tất cả và xem các lỗi
docker run --cap-drop=ALL myapp
# Lỗi: bind: permission denied

# Bước 2: Thêm NET_BIND_SERVICE
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp
# Tải thành công!
```

**Phương pháp 2: Sử Dụng Công Cụ capsh Để Phân Tích**

Chạy `capsh --print` bên trong container để xem Capabilities hiện tại:

```sh
$ docker run --rm -it --cap-drop=ALL ubuntu capsh --print
Current: =
# Trống, không có Capabilities

$ docker run --rm -it ubuntu capsh --print
Current: = cap_chown,cap_dac_override,cap_fowner,...
# Mặc định 14 Capabilities
```

**Phương pháp 3: Tham Khảo Yêu Cầu Ứng Dụng Phổ Biến**

| Loại Ứng Dụng | Capabilities Cần Thiết | Ghi Chú |
| --- | --- | --- |
| Ứng dụng web (cổng cao) | Không | Lắng nghe trên các cổng 3000+ không yêu cầu quyền đặc biệt |
| Ứng dụng web (cổng thấp) | NET\_BIND\_SERVICE | Cần cho 80/443 |
| Cơ sở dữ liệu (MySQL/Postgres) | Không | Các cổng mặc định là các cổng cao |
| Nginx/Caddy | NET\_BIND\_SERVICE | Nếu trực tiếp lắng nghe trên 80/443 |
| Công cụ VPN/mạng | NET\_ADMIN | Sửa đổi cấu hình định tuyến/NIC |

## Kiểm Soát Truy Cập Bắt Buộc: AppArmor Và SELinux

### Những Cái Này Làm Gì? Nói Đơn Giản

Capabilities kiểm soát "những hoạt động nào các quy trình có thể thực hiện", AppArmor/SELinux đi xa hơn, kiểm soát "những file và tài nguyên nào các quy trình có thể truy cập". Chúng là Mandatory Access Control (MAC) ở mức OS—thậm chí các quy trình có quyền root cũng phải tuân theo các quy tắc hồ sơ.

Ẩn dụ: Bạn là sếp của công ty (root), nhưng bạn vẫn cần phải vuốt thẻ truy cập của bạn để vào trung tâm dữ liệu—nếu thẻ thiếu quyền, bạn không thể vào. AppArmor/SELinux là hệ thống kiểm soát truy cập đó.

**Lựa Chọn Hệ Thống**:

*   Các hệ thống Debian/Ubuntu mặc định dùng AppArmor
*   Các hệ thống RHEL/CentOS mặc định dùng SELinux
*   Chọn một, không bật cả hai cùng lúc (chúng sẽ xung đột)

### AppArmor: Đơn Giản Và Đủ (Khuyến Nghị Cho Người Mới)

Docker tự động áp dụng một hồ sơ gọi là `docker-default` cho các container, đã khá nghiêm ngặt. Hầu hết thời gian bạn không cần cấu hình bất kỳ điều gì—nó im lặng bảo vệ bạn ở chế độ nền.

```sh
# Kiểm tra hồ sơ AppArmor của container
docker inspect mycontainer | grep -i apparmor
# "AppArmorProfile": "docker-default"
```

**docker-default làm gì?**

Hạn chế các container từ:

*   Mount các filesystem (mount)
*   Sửa đổi các tham số kernel (các file dưới /proc/sys/)
*   Truy cập các thiết bị host nhạy cảm (hầu hết các thiết bị dưới /dev/)
*   Sửa đổi cấu hình AppArmor của chính nó

Tôi đã kiểm tra điều này: trong một container với AppArmor được bật, thậm chí dưới quyền người dùng root, chạy `mount /dev/sda1 /mnt` lấy "Permission denied". Bảo vệ kép về Capabilities + AppArmor tăng độ khó container escape theo cấp số nhân.

### SELinux: Mạnh Hơn Nhưng Phức Tạp Hơn

Triết lý của SELinux là gắn nhãn trên mỗi file và quy trình với "nhãn", sau đó xác định nhãn nào có thể truy cập nhãn nào thông qua các chính sách.

```sh
# Kiểm tra nhãn SELinux của quy trình container
docker inspect mycontainer | grep -i selinux
# "ProcessLabel": "system_u:system_r:container_t:s0:c123,c456"
```

`c123,c456` trong các nhãn là danh mục—mỗi container có một danh mục kết hợp duy nhất, đảm bảo container A không thể truy cập các file của container B.

Thành thật mà nói, cấu hình SELinux có rào cản tham gia cao và các thông báo lỗi không thân thiện. Nếu bạn ở trên Ubuntu, AppArmor là đủ; nếu ở trên RHEL, SELinux đang bảo vệ bạn theo mặc định—hầu hết các tình huống không yêu cầu thay đổi.

### Lời Khuyên Thực Tế: Dùng Cái Nào? Như Thế Nào?

**Kịch Bản 1: Môi Trường Phát Triển**

*   Có thể tạm thời vô hiệu hóa (`apparmor=unconfined` hoặc `label=disable`) để giúp debug
*   Nhưng hãy suy nghĩ trước khi vô hiệu hóa: nếu bạn vô hiệu hóa trong quá trình debug, bạn có nhớ bật lại cho production không?

**Kịch Bản 2: Môi Trường Kiểm Tra**

*   Phải bật với hồ sơ mặc định
*   Mục tiêu là phát hiện sớm các xung đột giữa các cấu hình bảo mật và chức năng ứng dụng

**Kịch Bản 3: Môi Trường Production**

*   Phải bật, không có thương lượng
*   Sử dụng hồ sơ mặc định trừ khi có lý do thuyết phục để tùy chỉnh
*   Thường xuyên kiểm tra audit logs để kiểm tra các nỗ lực truy cập trái phép

Kinh nghiệm của tôi: 99% các hồ sơ DENIED nên bị từ chối—hoặc các cuộc tấn công hoặc thiết kế ứng dụng kém. Các kịch bản thực sự cần các quyền thoải mái là vô cùng hiếm.

## Xây Dựng Danh Sách Kiểm Tra Bảo Mật Hoàn Chỉnh

Hợp nhất tất cả những thứ trên thành một danh sách kiểm tra có thể thực thi được. Hãy tuân theo điều này và bảo mật container của bạn sẽ vượt trội hơn 80% những cái khác.

### Giai Đoạn Build Image

**Kiểm Tra Bảo Mật Dockerfile**:

*   ✅ Sử dụng các image cơ sở chính thức hoặc đáng tin cậy (tránh các nguồn không xác định)
*   ✅ Ghim các phiên bản image (sử dụng `node:18.17-alpine` không phải `node:latest`)
*   ✅ Tạo người dùng non-root chuyên dụng với UID/GID được chỉ định
*   ✅ Sử dụng `COPY --chown` để đặt quyền sở hữu file
*   ✅ Đặt chỉ thị `USER` sau các lệnh cài đặt, trước các lệnh khởi động
*   ✅ Ứng dụng lắng nghe trên các cổng cao (3000+) hoặc cấu hình Capabilities
*   ✅ Sử dụng các bản build nhiều giai đoạn để giảm kích thước image và bề mặt tấn công
*   ✅ Không bao gồm thông tin nhạy cảm trong các image (các chìa khóa, mật khẩu nên được truyền qua các biến env hoặc bí mật)

### Giai Đoạn Quét Image

**Quét Bảo Mật Bắt Buộc**:

```sh
# Sử dụng quét tích hợp của Docker (dựa trên Snyk)
docker scan myapp:latest

# Hoặc sử dụng Trivy (nhanh hơn và toàn diện hơn, được khuyến nghị)
trivy image myapp:latest

# Hoặc sử dụng Clair (tích hợp vào CI/CD)
# Cấu hình harbor registry cho quét tự động
```

Hãy nhớ, 76% các image trên Docker Hub có các lỗ hổng. Quét thường xuyên không phải là tùy chọn, đó là bắt buộc. Các quy tắc của nhóm chúng tôi:

*   Các lỗ hổng nghiêm trọng phải được sửa chữa trước production
*   Các lỗ hổng trung bình yêu cầu đánh giá rủi ro và giám sát
*   Các lỗ hổng thấp được ghi chép lại, kiểm tra định kỳ

### Kiểm Tra Cấu Hình Runtime

**Mẫu Docker-Compose Production**:

```yaml
services:
  myapp:
    image: myapp:1.0.0
    user: "5000:5000"           # Người dùng non-root
    read_only: true             # Filesystem chỉ đọc
    tmpfs:
      - /tmp:size=64M           # Mount bộ nhớ file tạm
    security_opt:
      - no-new-privileges:true  # Ngăn chặn privilege escalation
      - apparmor=docker-default # Hồ sơ AppArmor
    cap_drop:
      - ALL                     # Loại bỏ tất cả Capabilities
    cap_add:
      - NET_BIND_SERVICE        # Chỉ thêm những cái cần thiết
    volumes:
      - appdata:/app/data:rw    # Xác định rõ ràng quyền đọc/ghi
    deploy:
      resources:
        limits:
          cpus: '1.0'           # Giới hạn CPU
          memory: 512M          # Giới hạn bộ nhớ
    ports:
      - "8080:8080"
```

### Kiểm Tra Các Hoạt Động Production

**Giám Sát Hàng Ngày**:

*   ✅ Giám sát các khởi động lại container bất thường (có thể là các sự cố gây ra bởi tấn công)
*   ✅ Giám sát sử dụng tài nguyên bất thường (crypto miners tiêu thụ toàn bộ CPU)
*   ✅ Bật audit logging cho các hoạt động container

**Kiểm Tra Thường Xuyên**:

*   ✅ Quét hàng tháng các image đang chạy (không chỉ các image mới)
*   ✅ Kiểm tra các container sử dụng `--privileged` hoặc các Capabilities nguy hiểm
*   ✅ Kiểm tra các chính sách mạng container và các cổng được expose

## Những Vấn Đề Thường Gặp Và Giải Pháp

### Q1: Lỗi Quyền Truy Cập Ứng Dụng Sau Khi Chuyển Sang Non-Root?

**Các Bước Chẩn Đoán**:

1.  Kiểm tra thông báo lỗi cụ thể (quyền file hoặc ràng buộc cổng?)
2.  Nếu quyền file: Kiểm tra `--chown` của Dockerfile và quyền thư mục
3.  Nếu ràng buộc cổng: Sử dụng các cổng cao hoặc thêm NET\_BIND\_SERVICE Capability

**Các Lỗi Phổ Biến Và Sửa Chữa**:

```Dockerfile
# Lỗi: Error: EACCES: permission denied, open '/app/logs/app.log'
# Nguyên nhân: Thư mục log thiếu quyền ghi của appuser
# Sửa chữa:
RUN mkdir -p /app/logs && chown appuser:appgroup /app/logs

# Lỗi: Error: listen EACCES: permission denied 0.0.0.0:80
# Nguyên nhân: Non-root không thể ràng buộc các cổng thấp
# Sửa chữa 1: Thay đổi ứng dụng để lắng nghe trên 3000, sử dụng mapping cổng
EXPOSE 3000
# Sửa chữa 2: Thêm Capability
docker run --cap-add=NET_BIND_SERVICE myapp
```

### Q2: Không Phù Hợp Quyền Volume Sau Khi Mount?

Đây là vấn đề phổ biến nhất. Tôi đã tổng hợp ba giải pháp:

**Giải Pháp 1: Đặt Trước UID/GID Trên Host (Được Khuyến Nghị)**

```sh
# Đặt chủ sở hữu thư mục trên host thành 5000:5000 (khớp với UID người dùng container)
sudo chown -R 5000:5000 /data
docker run -v /data:/app/data myapp
```

**Giải Pháp 2: Sử Dụng Named Volumes, Để Docker Quản Lý Quyền**

```sh
docker volume create --opt o=uid=5000,gid=5000 appdata
docker run -v appdata:/app/data myapp
```

### Q3: Những Tình Huống Nào Thực Sự Cần Root? Hầu Như Không Có!

Nhiều người nghĩ một số tình huống cần root, nhưng các giải pháp thay thế tồn tại:

| Kịch Bản | Giải Pháp Non-Root |
| --- | --- |
| Ràng buộc các cổng 80/443 | Sử dụng NET\_BIND\_SERVICE Capability, hoặc ứng dụng lắng nghe trên cổng cao với load balancer mapping |
| Cài đặt các gói hệ thống | Cài đặt **trước** chỉ thị USER trong Dockerfile, runtime không nên cài đặt các gói |
| Sửa đổi cấu hình hệ thống | Cấu hình nên được tiêm qua các biến env hoặc file cấu hình, không sửa đổi runtime |
| Truy cập Docker Socket | Vô cùng nguy hiểm! Nếu thực sự cần, xem xét sử dụng Docker API hoặc K8s API thay vì mount socket |

Kịch bản root hợp pháp duy nhất mà tôi từng thấy: một công cụ di chuyển cơ sở dữ liệu kế thừa phải chạy với quyền root (nhà cung cấp hardcoded), và không thể thay đổi mã. Giải pháp là cách ly nó trong một container một lần riêng biệt, tiêu hủy sau khi di chuyển—không phải lâu dài.

### Q4: Image Của Bên Thứ Ba Chạy Với Quyền Root?

**Ưu Tiên Từ Cao Đến Thấp**:

1.  Tìm phiên bản non-root chính thức (nhiều image cung cấp các thẻ `-rootless` hoặc `-nonroot`)
2.  Ghi đè với tham số `--user`

```sh
docker run --user=65534:65534 third-party-image  # 65534 là người dùng nobody
```

3.  Viết Dockerfile mới dựa trên image gốc thêm USER

```Dockerfile
FROM third-party-image:latest
RUN adduser -D -u 5000 appuser
USER appuser
```

4.  Liên hệ với người duy trì image để cung cấp phiên bản non-root (đóng góp cho cộng đồng!)

## Kết Luận

Sau tất cả điều đó, thông điệp cốt lõi trong một câu: **Chạy container với quyền root = để lại những cánh cửa Trojan cho những kẻ tấn công**.

Hãy tóm tắt lại các điểm chính:

*   Container escape không phải là lý thuyết—CVE-2024-21626, mount container có quyền là các vectơ tấn công thực
*   Thêm chỉ thị USER trong Dockerfile hoặc tham số —user tại runtime—chi phí thấp, lợi ích khổng lồ
*   Capabilities cho phép kiểm soát quyền chính xác, loại bỏ tất cả + thêm theo yêu cầu là thực hành tốt nhất
*   Filesystem chỉ đọc, no-new-privileges, AppArmor kết hợp cung cấp bảo vệ đa tầng
*   76% các image có lỗ hổng, quét thường xuyên là cần thiết

Bắt đầu hôm nay, làm ba điều:

1.  **Kiểm tra Dockerfile của bạn**, thêm chỉ thị USER nếu thiếu
2.  **Kiểm tra các môi trường production**, tìm tất cả các container sử dụng `--privileged` hoặc chạy với quyền root, sửa lại ở đâu có thể
3.  **Thiết lập quy trình quét image**, đưa kiểm tra bảo mật vào CI/CD
