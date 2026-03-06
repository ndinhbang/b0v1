# Ánh Xạ Cổng Docker

Mục lục

*   [Ánh xạ cổng là cái gì vậy?](#ánh-xạ-cổng-là-cái-gì-vậy)
*   [Sự khác biệt giữa -p và -P là gì?](#sự-khác-biệt-giữa-p-và-p-là-gì)
*   [Khi các cổng bị chiếm dụng: Ba thủ thuật để tìm thủ phạm](#khi-các-cổng-bị-chiếm-dụng-ba-thủ-thuật-để-tìm-thủ-phạm)
*   [Thủ thuật 1: Kiểm tra xem Docker có đang sử dụng nó không](#thủ-thuật-1-kiểm-tra-xem-docker-có-đang-sử-dụng-nó-không)
*   [Thủ thuật 2: Xem ai đang sử dụng cổng đó trên host](#thủ-thuật-2-xem-ai-đang-sử-dụng-cổng-đó-trên-host)
*   [Thủ thuật 3: Chỉ cần sử dụng một cổng khác](#thủ-thuật-3-chỉ-cần-sử-dụng-một-cổng-khác)
*   [Ánh xạ nhiều cổng và ràng buộc IP](#ánh-xạ-nhiều-cổng-và-ràng-buộc-ip)
*   [Làm thế nào để ánh xạ nhiều cổng?](#làm-thế-nào-để-ánh-xạ-nhiều-cổng)
*   [Ràng buộc tới một địa chỉ IP cụ thể](#ràng-buộc-tới-một-địa-chỉ-ip-cụ-thể)
*   [Tôi đã ánh xạ cổng, tại sao vẫn không thể kết nối được?](#tôi-đã-ánh-xạ-cổng-tại-sao-vẫn-không-thể-kết-nối-được)
*   [Lỗi 1: Dịch vụ bên trong không lắng nghe trên 0.0.0.0](#lỗi-1-dịch-vụ-bên-trong-không-lắng-nghe-trên-0000)
*   [Lỗi 2: Tường lửa đang chặn bạn](#lỗi-2-tường-lửa-đang-chặn-bạn)
*   [Lỗi 3: Các nhóm bảo mật của máy chủ đám mây chưa được cấu hình](#lỗi-3-các-nhóm-bảo-mật-của-máy-chủ-đám-mây-chưa-được-cấu-hình)
*   [Lỗi 4: Chế độ mạng Docker sai](#lỗi-4-chế-độ-mạng-docker-sai)
*   [Quy trình khắc phục sự cố nhanh chóng](#quy-trình-khắc-phục-sự-cố-nhanh-chóng)
*   [Ánh xạ cổng có làm chậm hiệu suất không?](#ánh-xạ-cổng-có-làm-chậm-hiệu-suất-không)
*   [Tối ưu hoá 1: Sử dụng chế độ mạng host](#tối-ưu-hoá-1-sử-dụng-chế-độ-mạng-host)
*   [Tối ưu hoá 2: Vô hiệu hoá Userland Proxy](#tối-ưu-hoá-2-vô-hiệu-hoá-userland-proxy)
*   [Tối ưu hoá 3: Giảm ánh xạ cổng không cần thiết](#tối-ưu-hoá-3-giảm-ánh-xạ-cổng-không-cần-thiết)
*   [Khi nào nên quan tâm đến hiệu suất?](#khi-nào-nên-quan-tâm-đến-hiệu-suất)
*   [Suy nghĩ cuối cùng](#suy-nghĩ-cuối-cùng)

Bạn mở terminal và gõ lệnh docker run quen thuộc:

```sh
docker run -d -p 8080:80 nginx
```

Rồi nhấn Enter. Một dòng văn bản lỗi màu đỏ xuất hiện trên màn hình:

```
Error response from daemon: driver failed programming external connectivity on endpoint romantic_euler:
Bind for 0.0.0.0:8080 failed: port is already allocated.
```

Trái tim của bạn chìm xuống. Cổng 8080 bị chiếm dụng? Bởi cái gì? Tại sao? Giờ phải làm sao?

Nghe có quen không? Tôi chắc rằng ít nhất một nửa số người dùng Docker đã cau mày về lỗi này. Điều tệ hơn là bạn chỉ muốn chạy một container đơn giản, nhưng giờ bạn phải khắc phục sự cố về cổng, kiểm tra các tiến trình, đào sâu cấu hình tường lửa—lẽ ra phải mất 5 phút lại thành nửa tiếng.

## Ánh xạ cổng là cái gì vậy?

Thành thật mà nói, ánh xạ cổng nghe có vẻ bí ẩn, nhưng thực ra nó khá đơn giản.

Hãy tưởng tượng một container Docker như một tòa nhà chung cư. Bên trong container, có các "số phòng" (cổng)—ví dụ, nginx lắng nghe trên cổng 80 theo mặc định. Nhưng đây là vấn đề: tòa nhà này là cô lập—mọi người bên ngoài không biết những phòng nào ở bên trong và không thể vào được.

Ánh xạ cổng giống như thiết lập một "bộ dịch số" bên ngoài tòa nhà: khi ai đó gõ cửa số 3000, bộ dịch sẽ tự động đưa họ tới phòng 80 bên trong container. Đó chính là điều `-p 3000:80` làm—nó ánh xạ cổng 3000 trên host tới cổng 80 trên container.

Định dạng rất đơn giản: `-p host_port:container_port`. Khi tôi lần đầu học Docker, tôi luôn nhầm lẫn thứ tự của hai số này. Sau đó tôi nghĩ ra một câu nhớ: "người ngoài kết nối với người trong"—cổng bên ngoài đi trước, cổng bên trong đi sau.

### Sự khác biệt giữa -p và -P là gì?

Hai tham số này thường làm bối rối mọi người. `-p` (chữ thường) là ánh xạ thủ công—bạn chỉ định cổng nào sẽ ánh xạ. `-P` (chữ hoa) là chế độ lười—Docker tự động ánh xạ tất cả các cổng container được expose tới các cổng ngẫu nhiên trên host (thường trong khoảng 32768-61000).

Khi sử dụng `-P`, bạn cần kiểm tra cổng nào Docker đã gán bằng `docker ps` hoặc `docker port`:

```sh
docker run -d -P nginx
docker port <container_id>
```

Kết quả có thể trông như:

```sh
80/tcp -> 0.0.0.0:32768
```

Điều này có nghĩa là cổng 80 của container được ánh xạ tới cổng 32768 trên host. Khá tiện lợi, nhưng tôi không khuyên dùng trong production—những số cổng không thể dự đoán làm cho cấu hình rối rắm.

## Khi các cổng bị chiếm dụng: Ba thủ thuật để tìm thủ phạm

Quay lại kịch bản ban đầu—một cổng đã được sử dụng. Bạn sẽ làm gì?

### Thủ thuật 1: Kiểm tra xem Docker có đang sử dụng nó không

Đôi khi khi bạn khởi động lại một container, container cũ chưa hoàn toàn dừng và vẫn đang chiếm cổng. Trước tiên, sử dụng `docker ps -a` để kiểm tra các container zombie:

```sh
docker ps -a | grep 8080
```

Nếu tìm thấy, hãy kill nó:

```sh
docker rm -f <container_id>
```

### Thủ thuật 2: Xem ai đang sử dụng cổng đó trên host

Nếu Docker không sử dụng nó, thì một số tiến trình nào đó trên host đang sử dụng. Các hệ thống khác nhau sử dụng các lệnh khác nhau:

Trên Linux/Mac:

```sh
# Phương pháp 1: sử dụng lsof
sudo lsof -i :8080

# Phương pháp 2: sử dụng netstat
sudo netstat -tulnp | grep 8080

# Phương pháp 3: sử dụng ss (nhanh hơn)
sudo ss -tulnp | grep 8080
```

Kết quả có thể trông như:

```
COMMAND  PID  USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
node    1234  odensu   21u  IPv4  0x1234      0t0  TCP *:8080 (LISTEN)
```

Thấy chứ? PID là 1234, nó là một tiến trình node. Bạn có thể:

1.  Kill nó (nếu bạn chắc chắn bạn không cần nó): `kill -9 1234`
2.  Hoặc chạy container Docker trên một cổng khác

Trên Windows, nó phức tạp hơn một chút:

```sh
# Kiểm tra cổng
netstat -ano | findstr :8080

# Kết quả trông như:
# TCP    0.0.0.0:8080    0.0.0.0:0    LISTENING    1234

# Kiểm tra tiến trình
tasklist | findstr 1234

# Kill tiến trình
taskkill /PID 1234 /F
```

### Thủ thuật 3: Chỉ cần sử dụng một cổng khác

Thành thật mà nói, rất nhiều lần bạn không cần phải tìm cách để giải quyết tất cả những điều đó. Cổng 8080 bị chiếm dụng? Sử dụng 8081:

```sh
docker run -d -p 8081:80 nginx
```

Hoặc để Docker chọn:

```sh
docker run -d -p 0:80 nginx
```

Đặt cổng host thành 0, và Docker sẽ tự động gán một cổng có sẵn. Sau đó sử dụng `docker ps` để xem cổng nào được chọn.

## Ánh xạ nhiều cổng và ràng buộc IP

### Làm thế nào để ánh xạ nhiều cổng?

Đôi khi một container cần expose nhiều cổng. Ví dụ, một ứng dụng full-stack có frontend trên 3000, backend trên 8000, cơ sở dữ liệu trên 5432:

```sh
docker run -d \
  -p 3000:3000 \
  -p 8000:8000 \
  -p 5432:5432 \
  my-fullstack-app
```

Nhiều tham số `-p`, chỉ cần liệt kê chúng liên tiếp.

Cũng có một thủ thuật hay—ánh xạ phạm vi cổng:

```sh
docker run -d -p 8000-8010:8000-8010 my-app
```

Điều này ánh xạ các cổng host 8000-8010 tới các cổng container tương ứng. Nhưng thành thật mà nói, tôi hiếm khi sử dụng cái này—nó dễ nhầm lẫn khi quản lý.

### Ràng buộc tới một địa chỉ IP cụ thể

Theo mặc định, Docker ràng buộc các cổng tới `0.0.0.0`, có nghĩa là tất cả các giao diện mạng có thể truy cập nó. Nhưng nếu bạn chỉ muốn truy cập localhost, bạn có thể chỉ định 127.0.0.1:

```sh
docker run -d -p 127.0.0.1:8080:80 nginx
```

Bằng cách này, các mạng bên ngoài không thể truy cập container, chỉ máy cục bộ có thể. Nếu máy chủ của bạn có nhiều thẻ mạng, bạn cũng có thể ràng buộc tới một IP cụ thể:

```sh
docker run -d -p 192.168.1.100:8080:80 nginx
```

## Tôi đã ánh xạ cổng, tại sao vẫn không thể kết nối được?

Đây là câu hỏi phổ biến nhất mà tôi thấy. Ánh xạ cổng trông ổn, `docker ps` cho thấy ánh xạ thành công, nhưng trình duyệt vẫn không kết nối được. Hãy để tôi chia sẻ một số lỗi tôi gặp phải.

### Lỗi 1: Dịch vụ bên trong không lắng nghe trên 0.0.0.0

Đây là điều dễ bị bỏ qua nhất. Nhiều ứng dụng mặc định chỉ lắng nghe trên `127.0.0.1` (localhost), có nghĩa là chúng chỉ chấp nhận kết nối từ bên trong container—các yêu cầu từ bên ngoài không thể vào được.

Ví dụ, nếu bạn viết một ứng dụng Node.js:

```js
// Cách sai
app.listen(3000, 'localhost');  // Chỉ lắng nghe trên 127.0.0.1

// Cách đúng
app.listen(3000, '0.0.0.0');    // Lắng nghe trên tất cả các giao diện mạng
```

Tương tự với Python Flask:

```js
# Sai
app.run(host='127.0.0.1')

# Đúng
app.run(host='0.0.0.0')
```

Làm thế nào để kiểm tra? Vào container và xem:

```sh
docker exec -it <container_id> netstat -tulnp
```

Nếu bạn thấy `127.0.0.1:3000` thay vì `0.0.0.0:3000` hoặc `:::3000`, đó là vấn đề.

### Lỗi 2: Tường lửa đang chặn bạn

Trên các máy chủ Linux, tường lửa (firewalld hoặc ufw) có thể chặn cổng. Tôi đã gặp phải điều này trên CentOS—cấu hình ánh xạ cổng Docker là chính xác, nhưng truy cập bên ngoài vẫn không hoạt động.

Kiểm tra trạng thái tường lửa:

```sh
# CentOS/RHEL
sudo firewall-cmd --list-all

# Ubuntu/Debian
sudo ufw status
```

Nếu tường lửa bật, bạn cần cho phép cổng:

```sh
# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# Ubuntu/Debian
sudo ufw allow 8080/tcp
```

Hoặc nếu bạn chắc chắn môi trường an toàn (như máy dev), bạn có thể tạm thời vô hiệu hoá tường lửa để test:

```sh
# CentOS/RHEL
sudo systemctl stop firewalld

# Ubuntu/Debian
sudo ufw disable
```

Nhưng không bao giờ làm điều này trong production.

### Lỗi 3: Các nhóm bảo mật của máy chủ đám mây chưa được cấu hình

Nếu bạn sử dụng các máy chủ đám mây như Alibaba Cloud, AWS, hay Tencent Cloud, ngoài tường lửa hệ thống, còn có khái niệm "security group". Đây là bảo vệ tường lửa cấp đám mây có mức ưu tiên cao hơn tường lửa hệ thống.

Lần đầu tiên tôi sử dụng Alibaba Cloud ECS, tôi bị kẹt về vấn đề này—tường lửa hệ thống tắt, cấu hình Docker đúng, nhưng vẫn không thể truy cập. Hoá ra security group không có quy tắc inbound được cấu hình.

Giải pháp: Vào bảng điều khiển đám mây, tìm cài đặt security group, thêm các quy tắc inbound, và cho phép các cổng bạn cần. Mỗi nền tảng đám mây khác nhau một chút, nhưng nguyên tắc là như nhau.

### Lỗi 4: Chế độ mạng Docker sai

Docker có nhiều chế độ mạng: bridge (mặc định), host, none, container. Nếu bạn sử dụng `--network host`, các tham số ánh xạ cổng bị bỏ qua vì container sử dụng trực tiếp ngăn xếp mạng của host:

```sh
# Tham số -p bị bỏ qua ở đây
docker run -d --network host -p 8080:80 nginx
```

Với chế độ host, bất kỳ cổng nào dịch vụ bên trong container lắng nghe là những gì bạn sử dụng trên host—không cần ánh xạ. Chế độ này có hiệu suất tốt nhất nhưng có rủi ro xung đột cổng.

### Quy trình khắc phục sự cố nhanh chóng

Khi tôi gặp phải vấn đề kết nối cổng, tôi thường kiểm tra theo thứ tự này:

1.  `docker ps` - Xác nhận cấu hình ánh xạ cổng là chính xác
2.  `docker logs <container_id>` - Kiểm tra nhật ký container để xem có lỗi khởi động không
3.  `docker exec -it <container_id> netstat -tulnp` - Kiểm tra xem dịch vụ bên trong lắng nghe trên 0.0.0.0 không
4.  `curl localhost:8080` - Test trên host để loại trừ vấn đề mạng
5.  Kiểm tra quy tắc tường lửa hệ thống
6.  Kiểm tra cấu hình security group của nhà cung cấp đám mây

Theo quy trình này thường sẽ tìm ra vấn đề.

## Ánh xạ cổng có làm chậm hiệu suất không?

Thành thật mà nói, có. Nhưng bao nhiêu tùy thuộc vào tình huống.

Ánh xạ cổng Docker dựa trên iptables (Linux) hoặc userland proxy (chế độ tương thích đa nền tảng). Mỗi gói tin mạng đi qua ánh xạ cổng phải đi qua logic chuyển tiếp, vì vậy chắc chắn có một số overhead.

Tôi đã thực hiện một bài test đơn giản sử dụng `ab` (Apache Bench) để stress-test một container nginx:

*   Truy cập trực tiếp tới IP container (không có ánh xạ cổng): khoảng 50.000 yêu cầu/giây
*   Truy cập thông qua ánh xạ cổng: khoảng 45.000 yêu cầu/giây

Khoảng 10% chênh lệch. Đối với hầu hết các ứng dụng, overhead này có thể chấp nhận được. Nhưng nếu dịch vụ của bạn cực kỳ nhạy cảm với hiệu suất (như giao dịch tần số cao hoặc game servers), bạn có thể cần cân nhắc tối ưu hoá.

### Tối ưu hoá 1: Sử dụng chế độ mạng host

Như đã đề cập trước đó, với chế độ `--network host`, container sử dụng trực tiếp ngăn xếp mạng của host, không có overhead ánh xạ cổng:

```sh
docker run -d --network host nginx
```

Hiệu suất tốt nhất, nhưng có hai chi phí:

1.  Các cổng container có thể xung đột với các cổng host
2.  Bạn mất cách ly mạng bảo mật

Sử dụng cẩn thận trong production.

### Tối ưu hoá 2: Vô hiệu hoá Userland Proxy

Docker sử dụng cả iptables và userland proxy theo mặc định. Cái sau là một chương trình proxy được viết bằng Go—tương thích tốt nhưng hiệu suất kém. Nếu bạn chắc chắn rằng hệ thống của bạn hỗ trợ iptables (hầu hết các hệ thống Linux đều vậy), bạn có thể vô hiệu hoá nó:

Chỉnh sửa `/etc/docker/daemon.json`:

```js
{
  "userland-proxy": false
}
```

Khởi động lại Docker:

```sh
sudo systemctl restart docker
```

Điều này có thể giảm một số overhead, mặc dù sự cải thiện sẽ không đáng kể (có thể khoảng 5%).

### Tối ưu hoá 3: Giảm ánh xạ cổng không cần thiết

Một số dịch vụ chỉ được sử dụng bởi các container khác và không cần phải expose tới host. Ví dụ, một container cơ sở dữ liệu mà chỉ container ứng dụng truy cập không cần ánh xạ cổng:

```sh
# Không ánh xạ cổng, chỉ giao tiếp trong mạng Docker
docker run -d --name postgres --network mynet postgres

# Container ứng dụng kết nối tới cơ sở dữ liệu (thông qua tên container)
docker run -d --name app --network mynet -p 3000:3000 my-app
```

Giao tiếp giữa các container thông qua mạng Docker nhanh hơn nhiều so với ánh xạ cổng.

### Khi nào nên quan tâm đến hiệu suất?

Thành thật mà nói, trong hầu hết các tình huống, sự mất hiệu suất từ ánh xạ cổng là không đáng kể. Những gì bạn thực sự nên quan tâm là:

1.  Các nút cổ chai về hiệu suất ứng dụng (truy vấn cơ sở dữ liệu, logic code)
2.  Giới hạn tài nguyên container (CPU, bộ nhớ)
3.  I/O đĩa và băng thông mạng

Overhead ánh xạ cổng thường không xếp hạng cao. Trừ khi QPS của bạn trong hàng chục ngàn, hãy tối ưu hoá code ứng dụng trước tiên.

## Suy nghĩ cuối cùng

Nếu bạn gặp phải "port already allocated", trước tiên hãy sử dụng `docker ps -a` để kiểm tra các container cũ không được dọn dẹp, sau đó sử dụng `lsof` hoặc `netstat` để kiểm tra sử dụng cổng host. Nếu tất cả đều không thành công, hãy chuyển sang một cổng khác hoặc để Docker tự động gán (`-p 0:80`).

Nếu cổng được ánh xạ nhưng bạn không thể truy cập, hãy kiểm tra theo thứ tự này: địa chỉ lắng nghe dịch vụ bên trong container → tường lửa host → security group đám mây → chế độ mạng Docker. Chín lần trong mười, bạn sẽ tìm ra vấn đề.

Ánh xạ cổng là khu vực cơ bản nhất nhưng cũng dễ gặp lỗi nhất của Docker. Nhưng một khi bạn hiểu nguyên tắc và nắm vững các phương pháp khắc phục sự cố, bạn sẽ không tốn thời gian cho nó nữa.
