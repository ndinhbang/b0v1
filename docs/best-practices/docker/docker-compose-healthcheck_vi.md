# Docker Compose Service Dependencies: Giải Quyết Chuỗi Khởi Động Cơ Sở Dữ Liệu Với Healthchecks

Mục lục

*   [Tại Sao depends\_on Không Đủ: Bắt Đầu ≠ Sẵn Sàng](#tại-sao-depends_on-không-đủ-bắt-đầu-sẵn-sàng)
*   [Khoảng Thời Gian Giữa Khởi Động Container Và Sẵn Sàng Dịch Vụ](#khoảng-thời-gian-giữa-khởi-động-container-và-sẵn-sàng-dịch-vụ)
*   [Ba Điều Kiện Của depends\_on](#ba-điều-kiện-của-depends_on)
*   [Tại Sao service\_healthy Không Phải Mặc Định?](#tại-sao-service_healthy-không-phải-mặc-định)
*   [Hướng Dẫn Cấu Hình Healthcheck Hoàn Chỉnh](#hướng-dẫn-cấu-hình-healthcheck-hoàn-chỉnh)
*   [Cấu Hình Healthcheck Hoàn Chỉnh](#cấu-hình-healthcheck-hoàn-chỉnh)
*   [test: Lệnh Kiểm Tra](#test-lệnh-kiểm-tra)
*   [interval: Khoảng Thời Gian Kiểm Tra](#interval-khoảng-thời-gian-kiểm-tra)
*   [timeout: Timeout Của Kiểm Tra Đơn](#timeout-timeout-của-kiểm-tra-đơn)
*   [retries: Số Lần Thử Lại Khi Thất Bại](#retries-số-lần-thử-lại-khi-thất-bại)
*   [start\_period: Giai Đoạn Ân Ứ Khởi Động (Dễ Bị Bỏ Qua Nhất)](#start_period-giai-đoạn-ân-ứ-khởi-động-dễ-bị-bỏ-qua-nhất)
*   [Lỗi Thường Gặp Và Hướng Dẫn Tránh Bẫy](#lỗi-thường-gặp-và-hướng-dẫn-tránh-bẫy)
*   [Cấu Hình Thực Tế PostgreSQL Healthcheck](#cấu-hình-thực-tế-postgresql-healthcheck)
*   [Cấu Hình Cơ Bản (Được Khuyến Nghị)](#cấu-hình-cơ-bản-được-khuyến-nghị)
*   [Lệnh pg\_isready Được Giải Thích](#lệnh-pg_isready-được-giải-thích)
*   [Cấu Hình Nâng Cao: Thêm Query Thực Tế](#cấu-hình-nâng-cao-thêm-query-thực-tế)
*   [Hiệu Ứng Chạy Thực Tế](#hiệu-ứng-chạy-thực-tế)
*   [Khắc Phục Sự Cố: Container Luôn Unhealthy](#khắc-phục-sự-cố-container-luôn-unhealthy)
*   [Cấu Hình Thực Tế MySQL Healthcheck](#cấu-hình-thực-tế-mysql-healthcheck)
*   [Cấu Hình Cơ Bản (Được Khuyến Nghị)](#cấu-hình-cơ-bản-được-khuyến-nghị-1)
*   [Lệnh mysqladmin ping Được Giải Thích](#lệnh-mysqladmin-ping-được-giải-thích)
*   [Xử Lý Mật Khẩu Chính Xác](#xử-lý-mật-khẩu-chính-xác)
*   [Cân Nhắc Đặc Biệt Của MySQL 8.0](#cân-nhắc-đặc-biệt-của-mysql-80)
*   [Các Vấn Đề Phổ Biến](#các-vấn-đề-phổ-biến)
*   [Healthchecks Cho Các Cơ Sở Dữ Liệu Khác Và Dịch Vụ](#healthchecks-cho-các-cơ-sở-dữ-liệu-khác-và-dịch-vụ)
*   [Redis](#redis)
*   [MongoDB](#mongodb)
*   [RabbitMQ](#rabbitmq)
*   [Dịch Vụ HTTP Chung](#dịch-vụ-http-chung)
*   [Dịch Vụ Không Có Công Cụ Chuyên Dụng](#dịch-vụ-không-có-công-cụ-chuyên-dụng)
*   [Các Script wait-for-it: Vẫn Cần?](#các-script-wait-for-it-vẫn-cần)
*   [Cách Tiếp Cận wait-for-it Truyền Thống](#cách-tiếp-cận-wait-for-it-truyền-thống)
*   [Tại Sao Không Được Khuyến Nghị Nữa?](#tại-sao-không-được-khuyến-nghị-nữa)
*   [Khi Nào Vẫn Cần wait-for-it?](#khi-nào-vẫn-cần-wait-for-it)
*   [Các Công Cụ Thay Thế Khác](#các-công-cụ-thay-thế-khác)
*   [Danh Sách Kiểm Tra Khắc Phục Sự Cố Và Thực Hành Tốt Nhất](#danh-sách-kiểm-tra-khắc-phục-sự-cố-và-thực-hành-tốt-nhất)
*   [Lệnh Chẩn Đoán Nhanh](#lệnh-chẩn-đoán-nhanh)
*   [Cây Quyết Định Các Vấn Đề Phổ Biến](#cây-quyết-định-các-vấn-đề-phổ-biến)
*   [Thực Hành Tốt Nhất Môi Trường Production](#thực-hành-tốt-nhất-môi-trường-production)
*   [Mẹo Gỡ Lỗi](#mẹo-gỡ-lỗi)
*   [Kết Luận](#kết-luận)

Tối thứ Sáu, 22 giờ. Tôi nhìn chằm chằm vào các log lỗi cuộn qua terminal của tôi, tính toán về mặt tinh thần liệu tôi có về nhà kịp không.

```
web_1  | Error: connect ECONNREFUSED 127.0.0.1:5432
web_1  | at TCPConnectWrap.afterConnect
db_1   | PostgreSQL init process complete; ready for start up.
web_1  | Exited with code 1
web_1  | Restarting...
```

Container ứng dụng tiếp tục khởi động lại. Cơ sở dữ liệu đã bắt đầu, nhưng nó luôn chậm một nhất định. Tôi kiểm tra docker-compose.yml—depends\_on được cấu hình. Tại sao nó không hoạt động?

Vấn đề này đã làm phiền vô số nhà phát triển. Bạn có thể đã trải qua nó: chạy docker-compose up trong môi trường phát triển cục bộ của bạn, và hai nỗ lực đầu tiên luôn không thành công. Bạn chờ khoảng mười giây để có một vài khởi động lại trước khi mọi thứ chạy bình thường. Khi các đồng nghiệp mới hỏi "điều này có bình thường không?" bạn chỉ có thể nói một cách trái ý "cố gắng thêm vài lần nữa."

Nguyên nhân gốc rễ là đơn giản: **depends\_on của Docker chỉ quản lý thứ tự khởi động container, không phải liệu các dịch vụ có thực sự sẵn sàng hay không**.

Trong bài viết này, tôi sẽ hướng dẫn bạn qua:

*   Ba cấu hình điều kiện cho depends\_on (90% mọi người chỉ biết mặc định)
*   Cấu hình healthcheck chính xác cho PostgreSQL và MySQL (với các ví dụ hoàn chỉnh)
*   Các giải pháp thay thế hiện đại cho các script wait-for-it
*   Một danh sách kiểm tra khắc phục sự cố để làm cho các khởi động container của bạn vững chắc

## Tại Sao depends\_on Không Đủ: Bắt Đầu ≠ Sẵn Sàng

Có một báo giáo đặc biệt quan trọng trong tài liệu chính thức Docker rất dễ bỏ sót:

> Compose không chờ đợi cho đến khi một container "sẵn sàng", chỉ đến khi nó đang chạy.

Nói cách khác: Compose chỉ chờ đợi container chạy, không phải liệu dịch vụ có thực sự có thể sử dụng được hay không.

### Khoảng Thời Gian Giữa Khởi Động Container Và Sẵn Sàng Dịch Vụ

Hãy tưởng tượng quá trình khởi động container PostgreSQL:

1.  **0 giây**: Docker bắt đầu container, quá trình postgres khởi chạy ← depends\_on được phát hành tại đây
2.  **2 giây**: Khởi tạo thư mục dữ liệu
3.  **5 giây**: Tải các file cấu hình
4.  **8 giây**: Thực hiện các script init (nếu có)
5.  **12 giây**: Cuối cùng sẵn sàng chấp nhận kết nối

Có một khoảng 12 giây. Nếu ứng dụng web của bạn cố gắng kết nối với cơ sở dữ liệu tại giây thứ 1, kết quả chắc chắn sẽ là "Connection refused."

Các trường hợp thực tế còn cực đoan hơn. Tôi từng duy trì một dự án kế thừa trong đó script khởi tạo cơ sở dữ liệu phải nhập 500MB dữ liệu thử nghiệm—một mình quá trình đó mất 40 giây. Với cấu hình depends\_on mặc định, container ứng dụng phải crash và khởi động lại ít nhất 5 lần trước khi kết nối.

### Ba Điều Kiện Của depends\_on

Nhiều người không biết rằng depends\_on thực sự hỗ trợ ba điều kiện:

```yaml
services:
  web:
    depends_on:
      db:
        condition: service_started  # Mặc định, container bắt đầu là được
        # condition: service_healthy  # Chờ healthcheck vượt qua
        # condition: service_completed_successfully  # Chờ container kết thúc thành công (cho init containers)
```

**service\_started** (mặc định): Tiếp tục miễn là container ở trạng thái đang chạy. Đây là lý do tại sao depends\_on vẫn gây ra vấn đề.

**service\_healthy**: Phải chờ healthcheck vượt qua và trạng thái container trở thành "healthy" trước khi tiếp tục. Đây là những gì chúng ta thực sự cần.

**service\_completed\_successfully**: Chờ container thoát thành công (exit code 0). Phù hợp cho các tác vụ một lần như di chuyển dữ liệu.

### Tại Sao service\_healthy Không Phải Mặc Định?

Bạn có thể hỏi, nếu service\_healthy rất hữu ích, tại sao nó không phải mặc định?

Hai lý do:

1.  Không phải tất cả các dịch vụ đều cần healthchecks (như các worker stateless tương tự)
2.  Healthchecks yêu cầu cấu hình của bạn—Docker không biết cách dịch vụ của bạn xác định "sẵn sàng"

Điều này đưa chúng ta đến chủ đề tiếp theo: cách cấu hình healthchecks.

## Hướng Dẫn Cấu Hình Healthcheck Hoàn Chỉnh

Nguyên tắc healthcheck rất đơn giản: Docker định kỳ chạy một lệnh. Nếu nó trả về 0, nó là healthy; nếu nó trả về 1, nó là unhealthy.

### Cấu Hình Healthcheck Hoàn Chỉnh

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]  # Lệnh kiểm tra
      interval: 10s       # Kiểm tra mỗi 10 giây
      timeout: 5s         # Timeout của kiểm tra đơn là 5 giây
      retries: 3          # Đánh dấu là unhealthy sau 3 lần thất bại
      start_period: 30s   # Các lỗi trong 30 giây sau khởi động không tính vào retries
```

Tất cả năm tham số đều quan trọng. Hãy đi qua chúng từng cái một.

### test: Lệnh Kiểm Tra

Hai định dạng:

```yaml
# Phương pháp 1: Sử dụng shell (được khuyến nghị)
test: ["CMD-SHELL", "pg_isready -U postgres"]

# Phương pháp 2: Thực hiện lệnh trực tiếp (không có shell)
test: ["CMD", "pg_isready", "-U", "postgres"]
```

CMD-SHELL hoạt động trong hầu hết các trường hợp vì bạn có thể sử dụng các tính năng shell như pipes và redirects.

**Bẫy thường gặp**: Các công cụ trong lệnh kiểm tra phải tồn tại trong image. Ví dụ, sử dụng curl để kiểm tra các giao diện HTTP khi curl không được cài đặt trong image có nghĩa là healthcheck sẽ luôn không thành công. Tôi đã mắc phải lỗi này trước đây—mất nửa giờ trước khi nhận ra tôi cần thêm `RUN apk add curl` vào Dockerfile.

### interval: Khoảng Thời Gian Kiểm Tra

Cách thường xuyên để kiểm tra. Quá thường xuyên lãng phí tài nguyên, quá chậm làm chậm phản ứng.

*   **10 giây** là một mặc định tốt cho hầu hết các tình huống
*   Các dịch vụ quan trọng như cơ sở dữ liệu có thể được đặt thành 5 giây
*   Các dịch vụ nhẹ có thể sử dụng 15-30 giây

### timeout: Timeout Của Kiểm Tra Đơn

Timeout cho một kiểm tra duy nhất. Nếu lệnh bị treo, Docker sẽ chờ lâu như vậy trước khi từ bỏ.

Quá ngắn gây ra dương tính giả, quá lâu ảnh hưởng đến tốc độ phát hiện sự cố. **5-10 giây** là một phạm vi an toàn.

### retries: Số Lần Thử Lại Khi Thất Bại

Bao nhiêu lần thất bại liên tiếp trước khi đánh dấu là unhealthy.

Đây là một cơ chế debounce. Jitter mạng tình cờ hoặc quá tải cơ sở dữ liệu ngắn có thể gây ra các lỗi kiểm tra duy nhất—các lần thử lại làm cho hệ thống mạnh mẽ hơn.

**3-5 lần** là hợp lý. retries=1 quá nhạy cảm, retries=10 quá chậm.

### start\_period: Giai Đoạn Ân Ứ Khởi Động (Dễ Bị Bỏ Qua Nhất)

Đây là tham số dễ bỏ sót nhất và dễ gây lỗi nhất.

Các lỗi trong start\_period không tính vào retries. Nói cách khác, nó cung cấp một "bộ đệm khởi động" cho dịch vụ.

Tại sao nó quan trọng? Cơ sở dữ liệu cần thời gian để bắt đầu. PostgreSQL khởi tạo thư mục dữ liệu, MySQL tải các chỉ mục bảng. Không có start\_period, healthchecks bắt đầu không thành công tại giây 2, và dịch vụ có thể được đánh dấu unhealthy trước khi retries hết.

**Giá trị được khuyến nghị**:

*   PostgreSQL/MySQL: **30-60 giây**
*   Dịch vụ nhẹ (Redis): 15-30 giây
*   Với các script khởi tạo mở rộng: Có thể đặt thành 120 giây

Tôi thường đặt 60 giây—tốt hơn là chờ lâu hơn một chút so với gặp dương tính giả.

### Lỗi Thường Gặp Và Hướng Dẫn Tránh Bẫy

**Lỗi 1: Tham Chiếu Biến Môi Trường Không Chính Xác**

```yaml
# ❌ Sai: Compose interpolates trước khi khởi động, container nhận giá trị biến host
test: ["CMD", "mysqladmin", "ping", "-p$MYSQL_ROOT_PASSWORD"]

# ✅ Đúng: Sử dụng escape $$ để cho phép shell container phân tích cú pháp
test: ["CMD-SHELL", "mysqladmin ping -p$$MYSQL_ROOT_PASSWORD"]
```

**Lỗi 2: start\_period Quá Ngắn**

```yaml
# ❌ Cơ sở dữ liệu chưa được khởi tạo nhưng đếm các lỗi, nhanh chóng đánh dấu unhealthy
healthcheck:
  test: ["CMD", "pg_isready"]
  interval: 5s
  retries: 3
  start_period: 10s  # Quá ngắn!

# ✅ Cung cấp đủ thời gian khởi động
healthcheck:
  start_period: 60s  # Tốt hơn nhiều
```

**Lỗi 3: Công Cụ Kiểm Tra Không Tồn Tại**

Lỗi này đặc biệt trôi dạt vì Docker chỉ không thành công im lặng.

```yaml
# ❌ Nếu image không có curl, healthcheck luôn không thành công
test: ["CMD", "curl", "-f", "http://localhost/health"]

# ✅ Đảm bảo công cụ tồn tại, hoặc sử dụng các công cụ tích hợp sẵn
test: ["CMD", "wget", "--spider", "http://localhost/health"]  # Hình ảnh Alpine có wget
```

Với healthcheck được cấu hình, hãy xem cách cấu hình các cơ sở dữ liệu cụ thể.

## Cấu Hình Thực Tế PostgreSQL Healthcheck

Image chính thức của PostgreSQL đi kèm với một viên ngọc: **pg\_isready**.

Công cụ này được thiết kế đặc biệt để kiểm tra xem PostgreSQL có sẵn sàng hay không—đáng tin cậy hơn nhiều so với việc viết các truy vấn SQL của riêng bạn.

### Cấu Hình Cơ Bản (Được Khuyến Nghị)

```yaml
version: '3.8'

services:
  web:
    image: node:20-alpine
    depends_on:
      db:
        condition: service_healthy  # Chìa khóa: chờ healthcheck vượt qua
        restart: true  # Khởi động lại ứng dụng khi cơ sở dữ liệu khởi động lại
    environment:
      DATABASE_URL: postgresql://postgres:password@db:5432/myapp
    command: npm start

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 60s
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Lệnh pg\_isready Được Giải Thích

```sh
pg_isready -U postgres -d myapp
```

*   `-U`: Chỉ định tên người dùng, phải là một người dùng hiện có thực tế
*   `-d`: Chỉ định tên cơ sở dữ liệu (tùy chọn nhưng được khuyến nghị)

Tại sao thêm `-U`? Không có nó, pg\_isready cố gắng kết nối bằng người dùng hệ thống hiện tại, điền đầy log bằng các cảnh báo. Không ảnh hưởng đến chức năng, nhưng nó khó chịu.

### Cấu Hình Nâng Cao: Thêm Query Thực Tế

pg\_isready chỉ kiểm tra xem cổng có thể truy cập được hay không, không phải cơ sở dữ liệu có thực sự có thể thực hiện các truy vấn hay không. Nếu bạn cần kiểm tra nghiêm ngặt hơn:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres && psql -U postgres -d myapp -c 'SELECT 1'"]
  interval: 10s
  timeout: 10s  # Lưu ý timeout cần tăng lên do truy vấn bổ sung
  retries: 3
  start_period: 60s
```

`SELECT 1` là truy vấn đơn giản nhất. Nếu nó thực execute thành công, cơ sở dữ liệu không chỉ bắt đầu mà còn có thể xử lý SQL bình thường.

Tuy nhiên, đối với hầu hết các tình huống, pg\_isready cơ bản là đủ.

### Hiệu Ứng Chạy Thực Tế

Sau khi cấu hình, hãy bắt đầu nó:

```sh
$ docker-compose up

Creating network "myapp_default" ... done
Creating myapp_db_1 ... done
Waiting for myapp_db_1 to be healthy...  ← Chú ý dòng này
Creating myapp_web_1 ... done

db_1   | PostgreSQL init process complete; ready for start up.
db_1   | database system is ready to accept connections
web_1  | Server listening on port 3000  ← Ứng dụng bắt đầu sau khi cơ sở dữ liệu sẵn sàng
```

Bạn sẽ thấy một pause đáng chú ý—Docker đang chờ đợi container db trở thành healthy. Quá trình này có thể mất 30-60 giây, nhưng nó dẫn đến sự khởi động không thành công bằng không.

### Khắc Phục Sự Cố: Container Luôn Unhealthy

Nếu container cơ sở dữ liệu tiếp tục hiển thị unhealthy, hãy kiểm tra log healthcheck:

```sh
# Xem trạng thái sức khỏe container
$ docker inspect --format='{{json .State.Health}}' myapp_db_1 | jq

{
  "Status": "unhealthy",
  "FailingStreak": 5,
  "Log": [
    {
      "Start": "2024-12-17T03:15:30Z",
      "End": "2024-12-17T03:15:30Z",
      "ExitCode": 1,
      "Output": "pg_isready: could not connect to server: Connection refused"
    }
  ]
}
```

Nguyên nhân thường gặp:

1.  **start\_period quá ngắn**: Cơ sở dữ liệu vẫn đang khởi tạo khi đếm lỗi bắt đầu
2.  **Tên người dùng hoặc tên cơ sở dữ liệu sai**: pg\_isready không thể kết nối
3.  **Khởi động PostgreSQL không thành công**: Kiểm tra log container `docker logs myapp_db_1`

## Cấu Hình Thực Tế MySQL Healthcheck

MySQL healthcheck sử dụng **mysqladmin ping**, công cụ quản lý tích hợp của MySQL.

### Cấu Hình Cơ Bản (Được Khuyến Nghị)

```yaml
version: '3.8'

services:
  web:
    image: node:20-alpine
    depends_on:
      db:
        condition: service_healthy
        restart: true
    environment:
      DATABASE_URL: mysql://root:password@db:3306/myapp
    command: npm start

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: myapp
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 60s
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

### Lệnh mysqladmin ping Được Giải Thích

```sh
mysqladmin ping -h localhost -u root -ppassword
```

*   `-h`: Địa chỉ host (sử dụng localhost bên trong container)
*   `-u`: Tên người dùng
*   `-p`: Mật khẩu (lưu ý không có khoảng trắng giữa `-p` và mật khẩu)

Nếu MySQL bình thường, lệnh này trả về:

```sh
mysqld is alive
```

Exit code là 0, healthcheck vượt qua.

### Xử Lý Mật Khẩu Chính Xác

**Phương pháp 1: Ghi Mật Khẩu Trực Tiếp (Phù Hợp Cho Phát Triển)**

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
```

Đơn giản và trực tiếp, nhưng mật khẩu được hardcoded trong cấu hình.

**Phương pháp 2: Sử Dụng Biến Môi Trường (Được Khuyến Nghị)**

```yaml
db:
  environment:
    MYSQL_ROOT_PASSWORD: password
  healthcheck:
    test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root -p$$MYSQL_ROOT_PASSWORD"]
    # Lưu ý: Sử dụng $$ chứ không phải $
```

Có một bẫy ở đây: phải sử dụng `$$` không phải `$`.

Tại sao? Vì Docker Compose phân tích cú pháp các biến môi trường trước khi khởi động. Nếu bạn sử dụng `$MYSQL_ROOT_PASSWORD`, Compose tìm kiếm biến này trên máy host của bạn, không phải bên trong container. Sử dụng `$$` cho Docker Compose biết "hãy để nó yên, để shell container phân tích cú pháp nó."

**Phương pháp 3: Kiểm Tra Không Mật Khẩu (Đơn Giản Nhất, Nhưng Gây Tranh Cãi)**

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
```

Một số cấu hình MySQL cho phép các kết nối không mật khẩu cục bộ—đơn giản nhất trong trường hợp này. Tuy nhiên, không được khuyến nghị cho production.

### Cân Nhắc Đặc Biệt Của MySQL 8.0

MySQL 8.0 mặc định dùng plugin xác thực `caching_sha2_password`, nó có thể ngăn cản một số client cũ hơn kết nối. Nếu ứng dụng của bạn báo cáo lỗi xác thực, bạn có thể buộc phương pháp xác thực cũ:

```yaml
db:
  image: mysql:8.0
  command: --default-authentication-plugin=mysql_native_password
  environment:
    MYSQL_ROOT_PASSWORD: password
    MYSQL_DATABASE: myapp
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 60s
```

### Các Vấn Đề Phổ Biến

**Vấn Đề 1: Quyền Truy Cập Bị Từ Chối Cho Người Dùng 'root'@'localhost'**

Mật khẩu sai, hoặc biến môi trường không có hiệu lực. Kiểm tra:

1.  MYSQL\_ROOT\_PASSWORD được viết đúng chính tả không
2.  Mật khẩu trong healthcheck có khớp không
3.  Bạn có sử dụng escape `$$` không

**Vấn Đề 2: Container Khởi Động Chậm, Luôn Ở Trạng Thái Starting**

MySQL cần thời gian để khởi tạo thư mục dữ liệu, đặc biệt là lần khởi động đầu tiên. Đảm bảo start\_period được đặt đủ lớn—60 giây thường hoạt động. Nếu bạn có các script init nhập nhập rất nhiều dữ liệu, có thể cần 120 giây hoặc hơn.

**Vấn Đề 3: Healthcheck Vượt Qua Nhưng Ứng Dụng Không Thể Kết Nối Với Cơ Sở Dữ Liệu**

Có thể là vấn đề mạng hoặc vấn đề cấu hình ứng dụng. Kiểm tra:

1.  Chuỗi kết nối ứng dụng có đúng không (sử dụng tên dịch vụ như `db` cho hostname, không phải `localhost`)
2.  Mapping cổng có đúng không (giao tiếp giữa các container sử dụng cổng nội bộ (3306), không phải cổng được map)
3.  Cấu hình mạng có bình thường không (xác nhận tất cả các dịch vụ trên cùng một mạng)

## Healthchecks Cho Các Cơ Sở Dữ Liệu Khác Và Dịch Vụ

Sau khi làm chủ PostgreSQL và MySQL, các dịch vụ khác theo tự nhiên. Đây là một tham chiếu nhanh chóng.

### Redis

```yaml
redis:
  image: redis:7-alpine
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 15s
```

`redis-cli ping` trả về `PONG`, exit code 0. Redis khởi động nhanh, start\_period có thể ngắn hơn.

### MongoDB

```yaml
mongo:
  image: mongo:7
  healthcheck:
    test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 30s
```

Lưu ý: MongoDB 6.0+ thay thế lệnh `mongo` cũ bằng `mongosh`. Cho các phiên bản cũ hơn:

```yaml
test: ["CMD", "mongo", "--eval", "db.adminCommand('ping')"]
```

### RabbitMQ

```yaml
rabbitmq:
  image: rabbitmq:3-management-alpine
  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "ping"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 40s
```

RabbitMQ khởi động tương đối chậm, khuyến nghị start\_period của 40+ giây.

### Dịch Vụ HTTP Chung

Nếu một dịch vụ cung cấp các điểm cuối healthcheck HTTP (như `/health` hoặc `/ping`), sử dụng wget hoặc curl:

```yaml
api:
  image: myapp:latest
  healthcheck:
    test: ["CMD", "wget", "--spider", "--quiet", "http://localhost:8080/health"]
    # Hoặc sử dụng curl (nếu có sẵn trong image)
    # test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 20s
```

`--spider` làm cho wget chỉ kiểm tra mà không tải xuống, `--quiet` loại bỏ đầu ra log.

**Lưu ý**: Đảm bảo image có wget hoặc curl. Các image Alpine có wget theo mặc định, các image Debian/Ubuntu có curl.

### Dịch Vụ Không Có Công Cụ Chuyên Dụng

Nếu một dịch vụ thiếu các công cụ healthcheck, sử dụng netcat (nc) để kiểm tra các cổng:

```yaml
service:
  image: some-service:latest
  healthcheck:
    test: ["CMD-SHELL", "nc -z localhost 9000 || exit 1"]
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 30s
```

`nc -z` chỉ kiểm tra xem cổng có mở hay không mà không thiết lập kết nối thực tế. Tuy nhiên, điều này chỉ kiểm tra các cổng, không thể xác nhận dịch vụ có thực sự sẵn sàng hay không—thô hơn so với các phương pháp trước.

## Các Script wait-for-it: Vẫn Cần?

Nếu bạn tìm kiếm thứ tự khởi động Docker, bạn có thể sẽ thấy nhiều bài viết khuyến nghị các script wait-for-it hoặc wait-for.

Các script này hoạt động bằng cách thêm logic chờ vào entrypoint của container ứng dụng, kiểm tra xem các cổng dịch vụ phụ thuộc có thể truy cập được hay không.

### Cách Tiếp Cận wait-for-it Truyền Thống

```yaml
web:
  image: node:20-alpine
  depends_on:
    - db  # Chỉ depends_on thông thường, không kiểm tra trạng thái sức khỏe
  volumes:
    - ./wait-for-it.sh:/wait-for-it.sh  # Mount script
  command: ["/wait-for-it.sh", "db:5432", "--", "npm", "start"]
```

wait-for-it.sh vòng lặp kiểm tra cổng db:5432 cho đến khi có thể kết nối được trước khi thực hiện `npm start`.

### Tại Sao Không Được Khuyến Nghị Nữa?

Thực hành tốt nhất năm 2024: **Sử dụng native healthcheck thay vì các script bất cứ khi nào có thể**.

Các lý do:

1.  **Cấu hình rõ ràng hơn**: Logic kiểm tra sức khỏe ở dịch vụ cơ sở dữ liệu, các mối quan hệ phụ thuộc ngay lập tức rõ ràng
2.  **Không có file bổ sung**: Không cần duy trì các script hoặc mount các volume
3.  **Mạnh mẽ hơn**: Healthcheck có thể kiểm tra sự sẵn sàng dịch vụ thực tế, kiểm tra cổng TCP quá thô sơ
4.  **Tái sử dụng tốt hơn**: Cấu hình healthcheck một lần, tất cả các dịch vụ phụ thuộc vào nó tự động hưởng lợi

Có một bài viết nổi tiếng trong cộng đồng có tiêu đề theo nghĩa đen là "Quên wait-for-it, hãy sử dụng docker-compose healthcheck và depends\_on thay vào đó."

### Khi Nào Vẫn Cần wait-for-it?

Hai trường hợp đặc biệt:

**Trường Hợp 1: Không Thể Sửa Đổi Image Hoặc Cấu Hình Compose**

Ví dụ, sử dụng các image của bên thứ ba mà không có healthcheck và không có quyền thêm nó. Thêm wait-for-it ở phía ứng dụng là lựa chọn duy nhất.

**Trường Hợp 2: Cần Chờ Đợi Nhiều Dịch Vụ**

```sh
./wait-for-it.sh db:5432 redis:6379 rabbitmq:5672 -- npm start
```

Mặc dù depends\_on cũng có thể cấu hình nhiều dịch vụ, wait-for-it ngắn gọn hơn. Tuy nhiên, tình huống này hiếm.

### Các Công Cụ Thay Thế Khác

Bên cạnh wait-for-it, có nhiều công cụ tương tự:

*   **dockerize**: Được viết bằng Go, dự giới hơn, hỗ trợ các mẫu tính năng biến môi trường
*   **wait-for**: Phiên bản đơn giản của wait-for-it, triển khai shell thuần túy
*   **docker-compose-wait**: Được viết bằng Python, hỗ trợ kiểm tra HTTP

Nhưng thành thật mà nói, vào năm 2024, chỉ cần sử dụng healthcheck và đừng phiền với những cái này.

## Danh Sách Kiểm Tra Khắc Phục Sự Cố Và Thực Hành Tốt Nhất

Vẫn không hoạt động sau khi cấu hình? Hãy tuân theo danh sách kiểm tra này—giải quyết 90% vấn đề.

### Lệnh Chẩn Đoán Nhanh

```sh
# 1. Xem tất cả các trạng thái container
$ docker-compose ps

NAME       COMMAND    SERVICE   STATUS              PORTS
myapp_db   postgres   db        healthy             5432/tcp
myapp_web  npm start  web       running             0.0.0.0:3000->3000/tcp

# 2. Xem chi tiết healthcheck
$ docker inspect --format='{{json .State.Health}}' myapp_db_1 | jq

# 3. Xem log container
$ docker-compose logs db
$ docker-compose logs web

# 4. Theo dõi log trong thời gian thực
$ docker-compose logs -f --tail=100
```

### Cây Quyết Định Các Vấn Đề Phổ Biến

**Vấn Đề: Container Luôn Hiển Thị starting, Không Bao Giờ Trở Thành Healthy**

1.  Kiểm tra xem start\_period có quá ngắn không → Cố gắng thay đổi thành 60s
2.  Xem lệnh healthcheck có đúng không → Sử dụng `docker inspect` để xem lệnh thực tế
3.  Nhập container và thực hiện lệnh healthcheck theo cách thủ công → `docker exec -it myapp_db_1 pg_isready -U postgres`

**Vấn Đề: Container Trở Thành Unhealthy Sau Đó Phục Hồi Healthy, Lật Tật**

1.  interval quá ngắn, tài nguyên không đủ → Thay đổi thành 10s hoặc 15s
2.  retries quá ít, các lỗi tình cờ trigger → Thay đổi thành 5
3.  Cơ sở dữ liệu thực sự có vấn đề hiệu suất → Kiểm tra log cơ sở dữ liệu

**Vấn Đề: Healthcheck Vượt Qua Nhưng Ứng Dụng Vẫn Không Thể Kết Nối Với Cơ Sở Dữ Liệu**

1.  Chuỗi kết nối ứng dụng có đúng không → Sử dụng tên dịch vụ (như `db`) cho hostname, không phải `localhost`
2.  Mapping cổng có đúng không → Giao tiếp giữa các container sử dụng cổng nội bộ (5432), không phải cổng đã map
3.  Cấu hình mạng có bình thường không → Xác nhận tất cả các dịch vụ trên cùng một mạng

### Thực Hành Tốt Nhất Môi Trường Production

**1. Giá Trị Tham Số Được Khuyến Nghị (Cấu Hình Bảo Thủ)**

```yaml
healthcheck:
  interval: 10s          # Cân bằng tốc độ phản ứng và tiêu thụ tài nguyên
  timeout: 5s            # Cung cấp cho lệnh thời gian thực hiện đủ
  retries: 5             # Dung thứ các lỗi tình cờ
  start_period: 60s      # Cung cấp cho cơ sở dữ liệu thời gian khởi động đủ
```

Bộ tham số này ổn định trong hầu hết các tình huống. Nếu cơ sở dữ liệu của bạn có các script khởi tạo mở rộng, start\_period có thể được đặt thành 120s.

**2. Sử Dụng Chiến Lược Khởi Động Lại**

```yaml
web:
  depends_on:
    db:
      condition: service_healthy
      restart: true  # Khởi động lại ứng dụng khi cơ sở dữ liệu khởi động lại
  restart: unless-stopped  # Tự động khởi động lại sau khi container thoát
```

`restart: true` đảm bảo rằng khi cơ sở dữ liệu nâng cấp hoặc khởi động lại, các dịch vụ phụ thuộc cũng khởi động lại và kết nối lại.

**3. Giới Hạn Tài Nguyên**

Healthchecks tiêu thụ tài nguyên, mặc dù rất ít. Nếu tài nguyên hệ thống chặt chẽ:

```yaml
healthcheck:
  interval: 30s  # Kéo dài khoảng thời gian kiểm tra
  timeout: 3s    # Rút ngắn timeout
```

Thành thật mà nói, overhead healthcheck thường không đáng kể trừ khi chạy hàng trăm container.

**4. Giám Sát Trạng Thái Sức Khỏe**

Đối với production, sử dụng các công cụ giám sát để theo dõi trạng thái healthcheck. Các sự kiện Docker healthcheck có thể được thu thập bởi Prometheus, Grafana và các công cụ khác.

```yaml
# docker-compose.yml
services:
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 60s
    labels:
      - "prometheus.io/scrape=true"  # Để Prometheus thu thập trạng thái sức khỏe
```

**5. Cấu Hình Đa Môi Trường**

Các cấu hình phát triển và production có thể khác nhau:

```yaml
# docker-compose.yml (phát triển)
db:
  healthcheck:
    start_period: 30s  # Môi trường phát triển có ít dữ liệu hơn, khởi động nhanh hơn

# docker-compose.prod.yml (production)
db:
  healthcheck:
    start_period: 120s  # Môi trường production có nhiều dữ liệu hơn, khởi động chậm hơn
    interval: 5s        # Kiểm tra thường xuyên hơn
```

Chỉ định các file cấu hình khi sử dụng:

```sh
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

### Mẹo Gỡ Lỗi

**Mẹo 1: Kiểm Tra Thủ Công Lệnh Healthcheck**

Nhập container và chạy lệnh healthcheck theo cách thủ công để xem có gì sai:

```sh
$ docker exec -it myapp_db_1 sh
/# pg_isready -U postgres -d myapp
/var/run/postgresql:5432 - accepting connections
/# echo $?
0  ← Trả về 0 có nghĩa là thành công
```

**Mẹo 2: Tạm Thời Vô Hiệu Hóa Healthcheck**

Khi gỡ lỗi, nhận xét healthcheck và sử dụng depends\_on thông thường để loại trừ chính healthcheck:

```yaml
web:
  depends_on:
    - db  # Tạm thời sử dụng chế độ đơn giản
    # db:
    #   condition: service_healthy
```

Sau khi xác nhận ứng dụng có thể kết nối với cơ sở dữ liệu bình thường, hãy thêm lại healthcheck.

**Mẹo 3: Xem Docker Event Logs**

Docker ghi lại tất cả các sự kiện container, bao gồm các thay đổi trạng thái healthcheck:

```sh
$ docker events --filter 'event=health_status'

2024-12-17T03:15:30.123456789Z container health_status: healthy (name=myapp_db_1)
2024-12-17T03:16:45.987654321Z container health_status: unhealthy (name=myapp_db_1)
```

Điều này giúp xác định khi nào các container trở thành unhealthy, kết hợp với dấu thời gian log để xác định vấn đề.

## Kết Luận

Quay lại câu hỏi mở đầu của bài viết: Tại sao depends\_on không hoạt động?

Câu trả lời trong ba từ: **Không đủ**.

depends\_on theo mặc định chỉ quản lý khởi động container, không phải sự sẵn sàng dịch vụ. Container cơ sở dữ liệu chạy không có nghĩa là nó có thể chấp nhận các kết nối—khoảng cách này là nguyên nhân gốc rễ của những rắc rối của chúng ta.

Giải pháp cũng rất đơn giản:

1.  **Cấu hình healthcheck cho cơ sở dữ liệu**, sử dụng pg\_isready hoặc mysqladmin ping để kiểm tra sẵn sàng thực tế
2.  **Sử dụng điều kiện service\_healthy**, làm cho ứng dụng chờ đợi healthcheck vượt qua
3.  **Đặt start\_period hợp lý** (tối thiểu 60 giây), cung cấp cho cơ sở dữ liệu đủ thời gian khởi tạo

Ba bước này về cơ bản loại bỏ các lỗi khởi động container.

Cuối cùng, một số gợi ý hành động nhanh:

*   **Làm ngay bây giờ**: Sao chép cấu hình PostgreSQL hoặc MySQL từ bài viết này vào dự án của bạn, sửa đổi các biến môi trường và bạn đã sẵn sàng
*   **Tối nay**: Nâng cấp tất cả depends\_on trong các dự án nhóm lên service\_healthy, một lần và mãi mãi
*   **Cuộc họp nhóm tuần tới**: Chia sẻ với các đồng nghiệp, tiêu chuẩn hóa các tiêu chuẩn cấu hình nhóm
