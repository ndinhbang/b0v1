# Giải Thích Các Chế Độ Mạng Docker: So Sánh Hiệu Năng và Lựa Chọn Kịch Bản cho bridge/host/none/container

Mục Lục

*   [Đầu Tiên, Hiểu "Nền Tảng" của Docker Networking—Bridge docker0](#đầu-tiên-hiểu-nền-tảng-của-docker-networkingbridge-docker0)
*   [docker0 là gì? "Gateway" của Container của Bạn](#docker0-là-gì-gateway-của-container-của-bạn)
*   [veth pair: "Bộ Đàm Thoại Hai Chiều" của Container](#veth-pair-bộ-đàm-thoại-hai-chiều-của-container)
*   [Bridge Mode—"Lựa Chọn Mặc Định" của Docker](#bridge-modelựa-chọn-mặc-định-của-docker)
*   [Tại sao bridge là mặc định?](#tại-sao-bridge-là-mặc-định)
*   [Default bridge vs Custom bridge: Một Điểm Khác Biệt Quan Trọng](#default-bridge-vs-custom-bridge-một-điểm-khác-biệt-quan-trọng)
*   [Bí Mật Đằng Sau -p: NAT Forwarding](#bí-mật-đằng-sau--p-nat-forwarding)
*   [Các Trường Hợp Sử Dụng Bridge Mode](#các-trường-hợp-sử-dụng-bridge-mode)
*   [Host Mode—"Hiệu Năng Được Ưu Tiên"](#host-modehiệu-năng-được-ưu-tiên)
*   [Host Mode là gì? "Bare Metal" Trực Tiếp](#host-mode-là-gì-bare-metal-trực-tiếp)
*   [Lợi Thế Hiệu Năng Ở Đâu?](#lợi-thế-hiệu-năng-ở-đâu)
*   [Những Cạm Bẫy và Lợi Đổi của Host Mode](#những-cạm-bẫy-và-lợi-đổi-của-host-mode)
*   [Khi Nào Sử Dụng Host Mode?](#khi-nào-sử-dụng-host-mode)
*   [None và Container Modes—"Chỉ Dành Cho Mục Đích Đặc Biệt"](#none-và-container-modeschỉ-dành-cho-mục-đích-đặc-biệt)
*   [None Mode: Sandbox Cách Ly Mạng Hoàn Chỉnh](#none-mode-sandbox-cách-ly-mạng-hoàn-chỉnh)
*   [Khi Nào Sử Dụng None Mode?](#khi-nào-sử-dụng-none-mode)
*   [Container Mode: Hai Container "Chia Sẻ Mạng"](#container-mode-hai-container-chia-sẻ-mạng)
*   [Ứng Dụng Điển Hình của Container Mode: Kubernetes Pods](#ứng-dụng-điển-hình-của-container-mode-kubernetes-pods)
*   [Vai Trò của Hai Chế Độ Này](#vai-trò-của-hai-chế-độ-này)
*   [Ra Quyết Định Thực Tế: Chọn Chế Độ Mạng Đúng](#ra-quyết-định-thực-tế-chọn-chế-độ-mạng-đúng)
*   [Biểu Đồ Quyết Định](#biểu-đồ-quyết-định)
*   [Tham Chiếu Nhanh Đề Xuất Kịch Bản](#tham-chiếu-nhanh-đề-xuất-kịch-bản)
*   [Ba Hiểu Lầm Phổ Biến](#ba-hiểu-lầm-phổ-biến)
*   [Mẹo Nâng Cao](#mẹo-nâng-cao)
*   [Kết Luận](#kết-luận)

Lúc 2 giờ sáng. Tôi nhìn chằm chằm vào dòng xanh "Container started" trong terminal của mình. Dịch vụ đã chạy, nhưng curl liên tục timeout. Kiểm tra docker logs ba lần—không có lỗi. Port mapping -p 8080:80 đã được cấu hình. Network routing ổn, firewall tắt.

Có gì không ổn?

Hóa ra, tôi đã cấu hình sai chế độ mạng. Tôi nghĩ `docker run -p` là tất cả những gì bạn cần, hoàn toàn không biết rằng Docker có bốn chế độ mạng—bridge, host, none, và container—hoạt động đằng sau hậu trường. Thậm chí còn xấu hổ hơn: sau hai năm sử dụng Docker, tôi không thể giải thích được docker0 bridge thực sự là gì.

Nếu bạn từng gặp phải tình trạng "container chạy nhưng không thể truy cập" hoặc cảm thấy bối rối về Docker networking, bài viết này là dành cho bạn. Tôi sẽ giải thích sự khác biệt, các nguyên tắc, và các trường hợp sử dụng của bốn chế độ mạng này bằng tiếng Anh đơn giản. Không có lý thuyết Linux network namespace phức tạp—chỉ những thứ thực tế bạn thực sự cần biết.

## Đầu Tiên, Hiểu "Nền Tảng" của Docker Networking—Bridge docker0

### docker0 là gì? "Gateway" của Container của Bạn

Khi bạn cài đặt Docker, một giao diện mạng ảo gọi là `docker0` sẽ tự động xuất hiện. Hãy coi nó như cổng của một tòa nhà chung cư của bạn—tất cả các container (cư dân) cần phải đi qua nó để truy cập internet.

Mở terminal của bạn và hãy thử lệnh này:

```sh
ip addr show docker0
```

Bạn sẽ thấy output như thế này:

```sh
docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

Thấy `172.17.0.1` kia không? Đó là địa chỉ IP của docker0. Docker sẽ gán cho mỗi container mới một IP từ subnet `172.17.0.0/16`, như `172.17.0.2`, `172.17.0.3`, v.v.

Bây giờ kiểm tra danh sách mạng của Docker:

```sh
docker network ls
```

```sh
NETWORK ID     NAME      DRIVER    SCOPE
7f8a2b3c9d4e   bridge    bridge    local
```

Mạng `bridge` mặc định sử dụng `docker0` bridge ở dưới lót.

### veth pair: "Bộ Đàm Thoại Hai Chiều" của Container

`docker0` một mình là không đủ. Làm thế nào để một container ở "phòng riêng" của nó (về mặt kỹ thuật gọi là network namespace) giao tiếp với `docker0`?

Câu trả lời là veth pair. Hãy coi nó như một cặp bộ đàm thoại: một đầu bên trong container gọi là `eth0`, đầu kia trên host gọi là `vethXXX` (như veth9a7b4c), nói chuyện với nhau.

Bắt đầu một container và xem:

```sh
docker run -d --name test-nginx nginx
```

Kiểm tra các giao diện mạng của host:

```sh
ip addr | grep veth
```

Bạn sẽ thấy một thiết bị mới bắt đầu bằng veth. Bây giờ hãy nhìn vào bên trong container:

```sh
docker exec test-nginx ip addr
```

Container có giao diện `eth0` với IP `172.17.0.2`. `eth0` này và `vethXXX` của host được ghép nối. Các gói dữ liệu rời `eth0`, tức thì đến `vethXXX`, đi qua `docker0`, sau đó thoát qua card mạng của host (như `eth0` hoặc `ens33`) để đến internet.

Toàn bộ đường dẫn trông như thế này:

```
Container (172.17.0.2)
  ↓ eth0
  ↓ (veth pair)
  ↓ vethXXX
  ↓
docker0 bridge (172.17.0.1)
  ↓ NAT forwarding
  ↓
Host network card (e.g., 192.168.1.100)
  ↓
Internet
```

Trông phức tạp, nhưng thực ra nó rất nhanh. Ping một IP của container và bạn sẽ thấy độ trễ khoảng vài phần mười miligiây.

Thành thật mà nói, tôi bị bối rối về veth pair một lúc. Sau đó nó đã nhấp nháy: nó chỉ là một sợi cáp ảo, một đầu cắm vào container, đầu kia cắm vào docker0. Thế thôi.

## Bridge Mode—"Lựa Chọn Mặc Định" của Docker

### Tại sao bridge là mặc định?

Nếu bạn không chỉ định chế độ mạng, Docker sẽ tự động sử dụng bridge. Lý do rất đơn giản: **nó là điểm ngọt giữa cách ly và khả năng sử dụng**.

Bridge mode cung cấp cho mỗi container IP riêng của nó, tránh xung đột cổng trong khi cho phép dễ dàng exposed dịch vụ thông qua tham số -p. Đối với hầu hết các tình huống, điều này là đủ.

Ví dụ với hai container Nginx:

```sh
docker run -d -p 8080:80 --name web1 nginx
docker run -d -p 8081:80 --name web2 nginx
```

Cả hai container đều lắng nghe trên cổng `80`, nhưng chúng ở trong các không gian mạng riêng biệt, vì vậy không có xung đột. Truy cập chúng trên host thông qua `8080` và `8081`—Docker xử lý NAT port forwarding ở phía sau.

Kiểm tra cấu hình mạng với `docker inspect web1`:

```json
"Networks": {
    "bridge": {
        "IPAddress": "172.17.0.2",
        "Gateway": "172.17.0.1"
    }
}
```

Ở đây: container nhận IP riêng `172.17.0.2`, và gateway là `172.17.0.1` của docker0.

### Default bridge vs Custom bridge: Một Điểm Khác Biệt Quan Trọng

Đây là một cạm bẫy. Mạng bridge mặc định (`docker0`) **chỉ hỗ trợ giao tiếp dựa trên IP giữa các container, không hỗ trợ container name resolution**.

Thử cái này:

```sh
docker run -d --name db mysql
docker run -it --name app alpine ping db
```

Nó sẽ không hoạt động. Bạn phải sử dụng `ping 172.17.0.2` với IP cụ thể.

Nhưng nếu bạn tạo một custom bridge network:

```sh
docker network create mynet
docker run -d --name db --network mynet mysql
docker run -it --name app --network mynet alpine ping db
```

Bây giờ nó hoạt động. Custom bridge networks có built-in DNS resolution—container names hoạt động như tên miền.

Đây là **lý do tại sao các môi trường production nên sử dụng custom networks thay vì docker0 mặc định**—service discovery dễ dàng hơn nhiều mà không cần các IP hardcoded.

### Bí Mật Đằng Sau -p: NAT Forwarding

Khi bạn sử dụng `-p 8080:80`, Docker sẽ thêm một quy tắc NAT vào iptables của host:

```sh
iptables -t nat -L -n | grep 8080
```

Bạn sẽ thấy output như:

```sh
DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080 to:172.17.0.2:80
```

Dịch: tất cả lưu lượng truy cập đến cổng `8080` của host được chuyển tiếp đến `172.17.0.2:80` của container.

Đó là lý do tại sao truy cập `http://host-ip:8080` đạt được dịch vụ bên trong container—Docker xử lý chuyển đổi địa chỉ cho bạn.

### Các Trường Hợp Sử Dụng Bridge Mode

Tóm lại, bridge mode phù hợp với những tình huống này:

*   **Microservices architecture**: Nhiều container cộng tác cần cách ly và giao tiếp (sử dụng custom bridge networks)
*   **Development environment**: Kiểm tra dịch vụ nhanh chóng, bridge mặc định hoạt động tốt
*   **Web apps cần port mapping**: Như chạy một blog hoặc dịch vụ API

Về hiệu suất, bridge mode có một số overhead NAT và veth pair, nhưng thành thật mà nói, đối với hầu hết các ứng dụng điều này là có thể bỏ qua. Các nút thắt hiệu suất thực sự hiếm, vì vậy đừng lo lắng về điều đó trước.

## Host Mode—"Hiệu Năng Được Ưu Tiên"

### Host Mode là gì? "Bare Metal" Trực Tiếp

Host mode thực sự đơn giản: container bỏ qua việc có mạng riêng của nó và trực tiếp sử dụng stack mạng của host.

Bắt đầu một container với `--net=host`:

```sh
docker run -d --net=host --name web nginx
```

Bây giờ container không có IP độc lập, không có giao diện `eth0`—nó chia sẻ các giao diện mạng của host. Cấu hình mạng bên trong container khớp chính xác với output `ip addr` của host.

Quan trọng hơn: **không cần port mapping -p**. Nếu dịch vụ của container lắng nghe trên cổng `80`, truy cập bên ngoài đến `host-ip:80` đạt được nó trực tiếp.

### Lợi Thế Hiệu Năng Ở Đâu?

Host mode bỏ qua `docker0` bridge và veth pair, loại bỏ NAT forwarding. Các gói dữ liệu đi trực tiếp qua card mạng của host, tương đương với việc chạy quy trình trực tiếp trên host.

Các kiểm tra cho thấy host mode nhanh hơn khoảng 5-10% so với bridge mode trong các tình huống high-concurrency. Không nghe có vẻ như nhiều, nhưng đối với các ứng dụng nhạy cảm với độ trễ (như giao dịch tần số cao hoặc máy chủ trò chơi thời gian thực), sự khác biệt đó rất quan trọng.

Tôi từng có một trường hợp: sử dụng Nginx làm reverse proxy xử lý hàng chục ngàn request mỗi giây. Chuyển sang host mode giảm P99 latency từ 12ms xuống 9ms. Tiết kiệm chỉ 3 miligiây, nhưng đối với dự án đó, những 3 miligiây đó trị giá hàng chục ngàn đô la.

### Những Cạm Bẫy và Lợi Đổi của Host Mode

Hiệu suất tốt hơn, nhưng có rất nhiều cạm bẫy:

**Cạm Bẫy 1: Xung Đột Cổng**

Vì bạn đang sử dụng các cổng của host trực tiếp, việc bắt đầu nhiều container lắng nghe trên cùng một cổng sẽ thất bại ngay lập tức:

```sh
docker run -d --net=host nginx  # lắng nghe trên 80
docker run -d --net=host nginx  # cũng 80, lỗi: Address already in use
```

Giống như chạy hai instance Nginx trực tiếp trên host. Muốn nhiều instance? Hoặc thay đổi cổng lắng nghe bên trong container, hoặc không sử dụng host mode.

**Cạm Bẫy 2: Dịch Vụ Container Phải Lắng Nghe Trên 0.0.0.0**

Nếu dịch vụ của container chỉ lắng nghe trên `127.0.0.1`, truy cập bên ngoài sẽ không hoạt động. Nó phải lắng nghe trên `0.0.0.0` để có thể truy cập từ bên ngoài.

Tôi từng chạy một dịch vụ Node.js ở host mode với `app.listen(3000, 'localhost')` trong code. Kết nối bên ngoài thất bại hoàn toàn. Phải thay đổi thành `app.listen(3000, '0.0.0.0')` để sửa.

**Cạm Bẫy 3: Mất Cách Ly Mạng**

Các container có thể trực tiếp truy cập tất cả các tài nguyên mạng của host—rủi ro bảo mật cao. Nếu bạn đang chạy code bên thứ ba không đáng tin cậy trong một container, việc sử dụng host mode là tự đào hố chôn mình.

### Khi Nào Sử Dụng Host Mode?

Thành thật mà nói, **chỉ xem xét host mode khi bạn có một nút thắt riêng hiệu năng**. Trong hầu hết các tình huống, overhead của bridge mode đơn giản là không phải vấn đề.

Host mode phù hợp với những tình huống này:

*   **Monitoring tools**: Prometheus, Grafana, ELK stack cần truy cập trực tiếp tài nguyên host
*   **High-performance proxies**: Nginx, HAProxy cho load balancing khi theo đuổi latency tối thiểu
*   **Databases**: MySQL, Redis cho các dịch vụ nhạy cảm với mạng (nhưng cẩn thận với bảo mật)

Nếu ứng dụng của bạn xử lý vài ngàn request mỗi giây, đừng bận tâm đến host mode—bridge là được.

## None và Container Modes—"Chỉ Dành Cho Mục Đích Đặc Biệt"

### None Mode: Sandbox Cách Ly Mạng Hoàn Chỉnh

None mode rất theo nghĩa đen: container không có mạng nào cả.

```sh
docker run -it --net=none alpine sh
```

Chạy `ip addr` bên trong container—bạn sẽ chỉ thấy loopback interface (lo). Không internet, không truy cập từ các container khác.

### Khi Nào Sử Dụng None Mode?

Nói thành thật, tôi gần như không bao giờ sử dụng none mode trong công việc thực tế. Các trường hợp sử dụng của nó cực kỳ hẹp:

*   **Security testing**: Chạy code không đáng tin cậy với cách ly mạng hoàn chỉnh để ngăn chặn rò rỉ dữ liệu
*   **Offline data processing**: Container chỉ thực hiện tính toán cục bộ, không cần giao tiếp mạng
*   **Manual network configuration**: Các trường hợp hiếm cần setup mạng hoàn toàn tùy chỉnh (như sử dụng các công cụ như pipework để cấu hình veth thủ công)

Nếu bạn không đang làm nghiên cứu bảo mật hoặc có nhu cầu cấu hình mạng đặc biệt, bạn cơ bản sẽ không sử dụng none mode.

### Container Mode: Hai Container "Chia Sẻ Mạng"

Container mode cho phép một container sử dụng network namespace của container khác. Nghe có vẻ phức tạp, nhưng một ví dụ sẽ làm rõ:

```sh
# Bắt đầu một container trước
docker run -d --name web nginx

# Container thứ hai chia sẻ mạng của web
docker run -it --net=container:web alpine sh
```

Bây giờ cả hai container chia sẻ cùng một cấu hình mạng: cùng IP, cùng không gian cổng, cùng giao diện mạng. Trong container thứ hai, `localhost:80` truy cập trực tiếp nginx.

### Ứng Dụng Điển Hình của Container Mode: Kubernetes Pods

Kubernetes Pods thực sự được triển khai bằng cách sử dụng container mode. Một Pod có nhiều container chia sẻ một "pause" container's network.

Ví dụ, một Pod có một application container và một sidecar log collector—chúng giao tiếp qua localhost mà không exposed port bên ngoài.

Nhưng nếu bạn chỉ sử dụng Docker mà không có Kubernetes, container mode hiếm khi được sử dụng. Bridge mode trực tiếp + custom networks có thể đạt được liên lạc giữa các container với nhiều tính linh hoạt hơn.

### Vai Trò của Hai Chế Độ Này

Tóm lại: none và container giống như "khả năng low-level" hơn là giải pháp hàng ngày. Chúng cung cấp tính linh hoạt cho các tình huống đặc biệt, nhưng bạn sẽ không cần chúng 80% thời gian.

Ghi nhớ:

*   **None mode**: Cho cách ly mạng hoàn chỉnh (rất hiếm)
*   **Container mode**: Phổ biến trong Kubernetes và các công cụ orchestration khác, hiếm khi sử dụng với Docker một mình

## Ra Quyết Định Thực Tế: Chọn Chế Độ Mạng Đúng

### Biểu Đồ Quyết Định

Đối mặt với một dự án cụ thể, bạn nên sử dụng chế độ mạng nào? Đây là một luồng quyết định đơn giản tôi đã tóm tắt:

```
Cần cách ly mạng?
│
├─ Không → Có nút thắt hiệu năng?
│       │
│       ├─ Có → Sử dụng Host mode (cẩn thận rủi ro bảo mật)
│       └─ Không  → Sử dụng Bridge mode (an toàn hơn)
│
└─ Có → Container cần giao tiếp theo tên?
        │
        ├─ Có → Custom Bridge network
        └─ Không  → Default Bridge network
```

**Các tình huống đặc biệt**:

*   Hoàn toàn không cần mạng → None mode
*   Container Pod trong Kubernetes → Container mode

### Tham Chiếu Nhanh Đề Xuất Kịch Bản

| Kịch Bản | Chế Độ Được Đề Xuất | Lý Do |
| --- | --- | --- |
| Microservices (multi-container) | Custom bridge | Hỗ trợ name resolution, cách ly tốt |
| Single web app | Default bridge | Đủ đơn giản, setup một lệnh |
| High-performance database/cache | Host | Giảm overhead mạng, nhưng đánh giá bảo mật |
| Monitoring tools (Prometheus/ELK) | Host | Cần truy cập trực tiếp host resources |
| Load balancer (Nginx/HAProxy) | Host | Theo đuổi minimal latency |
| Dev/test environment | Default bridge | Startup nhanh, không cấu hình phức tạp |
| K8s Pod sidecar containers | Container | Chia sẻ mạng với container chính |
| Security sandbox/offline tasks | None | Cách ly mạng hoàn chỉnh |

### Ba Hiểu Lầm Phổ Biến

**Hiểu Lầm 1: "Host mode luôn là tốt nhất"**

Sai. Host mode hy sinh cách ly và tính linh hoạt cho những lợi ích hiệu năng thường có thể bỏ qua trong nhiều tình huống.

Tôi đã thấy những người chạy tất cả các container ở host mode, kết thúc với xung đột cổng và các vấn đề bảo mật ở khắp nơi. Hiệu suất thực sự tốt hơn một chút, nhưng chi phí bảo trì tăng gấp mười lần.

**Sự Thật**: 80% ứng dụng hoạt động tốt với bridge mode. Đừng bị lừa bởi "hiệu năng tốt hơn".

**Hiểu Lầm 2: "Default bridge là đủ tốt"**

Không được khuyến khích cho production. Default bridge không hỗ trợ container name resolution. Khi nhiều dịch vụ giao tiếp, bạn phải hardcode IP hoặc chuyển IP qua environment variables—rất dễ gãi.

Tạo custom bridge network rất đơn giản:

```sh
docker network create mynet
# Trong docker-compose.yml chỉ cần chỉ định network
```

**Sự Thật**: Dành 2 phút cấu hình custom network, tiết kiệm hàng giờ gỡ lỗi.

**Hiểu Lầm 3: "Vấn đề mạng Container luôn là lựa chọn chế độ sai"**

Không phải lúc nào. Thường nó là firewall, cấu hình iptables, hoặc vấn đề DNS.

Các bước gỡ lỗi:

1.  Ping gateway (IP của docker0) từ bên trong container
2.  Ping external IP của host
3.  Kiểm tra quy tắc iptables cho DROP
4.  Kiểm tra cấu hình daemon Docker (/etc/docker/daemon.json)

**Sự Thật**: Mode chỉ là bước một; gỡ lỗi mạng cần phải có hệ thống.

### Mẹo Nâng Cao

**Mẹo 1: Tham Gia Container Vào Nhiều Network**

Đôi khi các container cần kết nối đến hai network (như frontend và backend networks):

```sh
docker network create frontend
docker network create backend

docker run -d --name web --network frontend nginx
docker network connect backend web
```

Bây giờ container web ở cả hai network frontend và backend.

**Mẹo 2: Kiểm Soát Phân Bổ IP Chính Xác**

Khi tạo custom networks, chỉ định subnet và gateway:

```sh
docker network create \
  --driver bridge \
  --subnet 192.168.10.0/24 \
  --gateway 192.168.10.1 \
  mynet

docker run -d --network mynet --ip 192.168.10.100 nginx
```

Hữu ích cho các tình huống cần IP cố định (như firewall whitelists).

**Mẹo 3: Network Troubleshooting Tools**

Để gỡ lỗi vấn đề mạng bên trong container, những công cụ này rất hữu ích:

```sh
# Cài đặt network tools
docker exec -it <container> apk add curl netcat-openbsd

# Kiểm tra kết nối
docker exec <container> nc -zv <host> <port>

# Xem bảng định tuyến
docker exec <container> ip route

# Phân tích packet capture (cần host privileges)
docker exec <container> tcpdump -i eth0
```

## Kết Luận

Sau tất cả điều đó, đây là một khóa lại nhanh gọn bốn chế độ mạng:

*   **Bridge mode**: Lựa chọn mặc định, phù hợp với hầu hết các tình huống, sử dụng custom bridge networks trong production
*   **Host mode**: Ưu tiên hiệu năng, nhưng hy sinh cách ly—chỉ sử dụng khi bạn có thực sự vấn đề về hiệu năng
*   **None mode**: Cách ly mạng hoàn chỉnh, hiếm khi sử dụng
*   **Container mode**: Chia sẻ mạng, chủ yếu được sử dụng trong Kubernetes

Ghi nhớ một điều: **Không có chế độ tốt nhất, chỉ có chế độ phù hợp nhất**.

Nếu bạn mới quen Docker, bắt đầu với bridge mặc định. Điều chỉnh khi bạn gặp vấn đề cụ thể: chuyển sang custom bridge nếu service discovery là vấn đề, xem xét host nếu hiệu năng thực sự không đủ. Đừng ám ảnh xem chế độ nào là "tối ưu" từ đầu.
