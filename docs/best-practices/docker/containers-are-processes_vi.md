# Containers Là Các Process | iximiuz Labs

Một lợi ích cốt lõi của việc sử dụng các container là hầu hết lúc bạn không phải suy nghĩ về những gì đang xảy ra dưới mui xe. Các công cụ như Docker và Kubernetes làm việc rất tốt của việc ẩn độ phức tạp từ người dùng của họ.

Tuy nhiên, khi bạn cần gỡ lỗi và bảo mật các môi trường containerized, nó có thể rất hữu ích để hiểu cách tương tác với các container ở mức thấp. May mắn thay, vì hầu hết các công cụ containerization được xây dựng trên Linux, bạn có thể sử dụng các công cụ Linux hiện tại để tương tác với và gỡ lỗi chúng.

Khi bảo mật các môi trường containerized, cũng rất quan trọng để hiểu cách các container sử dụng các lớp cô lập, và cách những lớp đó có thể thất bại, để bạn có thể giảm thiểu bất kỳ rủi ro nào.

Trong hướng dẫn này, chúng ta sẽ chứng minh rằng các container là các process, sử dụng các công cụ Linux để tương tác với các container, và khám phá những gì điều này có nghĩa là cho việc bảo mật các môi trường container.

## Containers Chỉ Là Các Process

Điều đầu tiên để hiểu về các container là, từ góc độ hệ điều hành, chúng là các process giống như bất kỳ ứng dụng nào khác chạy trực tiếp trên host.

Hãy bắt đầu bằng cách kiểm tra xem có bất kỳ quá trình hoạt động nào có tên `simple-webserver` trên sân chơi hướng dẫn của chúng ta. Nếu bạn chưa làm được, hãy nhấp vào nút "Start playground" ở bên phải. Sau đó, chúng ta có thể chạy lệnh dưới đây để tìm kiếm các trường hợp máy chủ web đơn giản của chúng ta

Điều này sẽ trả về một danh sách trống, vì chúng ta không có bất kỳ máy chủ web đơn giản nào chạy vào lúc này.

Bây giờ, hãy bắt đầu một container Docker bằng cách sử dụng hình ảnh máy chủ web đơn giản từ Docker Hub, nó chỉ bắt đầu một quá trình máy chủ web rất cơ bản tốt cho minh họa.

```sh
docker run --name webserver -d ctrsec/swc
```

Khi container lên, chúng ta sẽ chạy lệnh `ps` của chúng ta lại:

Lần này, chúng ta nhận được một cái gì đó như dưới đây, cho chúng ta biết rằng chúng ta bây giờ có một process `simple-webserver` đang chạy trên máy. Theo quan điểm của máy Linux của chúng ta, ai đó vừa chạy process đó trên host.

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc.png)

Khi chúng ta đào sâu hơn vào khái niệm rằng các container là các process, một câu hỏi ban đầu có thể là: làm thế nào bạn có thể phân biệt giữa một process bắt đầu từ một Docker image và một process chỉ được cài đặt trên một Virtual Machine? Có một vài cách để làm điều đó, nhưng cách đầu tiên, dễ nhất là kiểm tra các container chạy bằng `docker ps`:

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc-docker-ps.png)

Ngoài ra, chúng ta có thể sử dụng các công cụ Linux process để xác định xem máy chủ web có chạy như một container hay không chẳng hạn với tùy chọn `--forest` trên `ps`.

Điều này cho chúng ta thấy một phân cấp của các process. Trong trường hợp này, process `simple-webserver` của chúng ta có một process cha của `containerd-shim-runc-v2`. Bạn sẽ thấy một process shim cho mỗi container chạy trên host. Process shim này là một phần của containerd và được Docker sử dụng để quản lý các process được chứa. Mục tiêu của process shim này là cho phép containerd hoặc Docker daemon được khởi động lại mà không phải khởi động lại tất cả các container chạy trên host.

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc-forest.png)

## Tương Tác Với Một Container Như Một Process

Bây giờ chúng ta biết rằng các container chỉ là các process—nhưng điều đó có ý nghĩa gì trong các điều khoản của cách chúng ta có thể tương tác với chúng? Có khả năng tương tác với chúng như các process rất hữu ích cho cả việc khắc phục sự cố hoạt động của chúng và điều tra các thay đổi trong các container chạy (ví dụ, trong một cuộc điều tra pháp y). Có một vài điều cần ghi nhớ ở đây, nhưng cái đầu tiên là chúng ta có thể sử dụng filesystem `/proc` để có được thêm thông tin về các container chạy của chúng ta.

Filesystem `/proc` trong Linux là một filesystem ảo hoặc pseudo. Nó không chứa các file thực—thay vào đó, nó được điền với thông tin về hệ thống đang chạy. Miễn là một người dùng có các đặc quyền phù hợp trên một host chạy Docker, họ có thể sử dụng `/proc` để truy cập thông tin về bất kỳ container nào chạy trên host.

Hãy xem một số thông tin về container máy chủ web đơn giản mà chúng ta bắt đầu trước đó. trước tiên chúng ta sẽ lấy một ghi chú về PID của container nginx của chúng ta, lần này sử dụng `docker inspect` cho thấy chi tiết của container chạy

```sh
docker inspect --format '{{.State.Pid}}' webserver
```

Tiếp theo, chúng ta sẽ liệt kê các file trong `/proc`.

Chúng ta sẽ thấy một thư mục được đánh số cho mỗi process trên host bao gồm PID mà bạn nhận được làm output từ lệnh `docker inspect`. Mỗi một trong số những thư mục này chứa nhiều file và thư mục với thông tin về process đó, có nghĩa là chúng ta có thể điều hướng vào thư mục cho container của chúng ta để tìm hiểu thêm về process được chứa của chúng ta.

Nó cũng có thể hữu ích để sử dụng các công cụ Linux để làm việc với các container được cứng hóa để loại bỏ các công cụ như các trình soạn thảo file hoặc các trình giám sát process. Cứng hóa các hình ảnh container là một khuyến nghị bảo mật phổ biến, nhưng nó làm cho việc gỡ lỗi khó hơn. Bạn có thể chỉnh sửa các file bên trong container bằng cách truy cập filesystem gốc của container từ thư mục `/proc` trên host. Điều hướng để `/proc/[PID]/root` sẽ cung cấp cho bạn danh sách thư mục của filesystem container đó có PID đó.

Bạn có thể chạy lệnh dưới đây, thay thế `[PID]` bằng ID process của container của bạn để xem output đó.

Kết quả sẽ trông giống như thế này.

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc-proc-ls.png)

Chúng ta có thể xác nhận rằng đây là filesystem cho container của chúng ta, bằng cách tạo một file mới bên trong container sử dụng `docker exec` và sau đó thấy kết quả trong filesystem proc

Trước tiên chạy lệnh `docker exec` này để tạo một file mới trong container

```sh
docker exec webserver touch /test_file
```

Sau đó chạy lệnh `ls` lại, thay thế `[PID]` bằng ID process của container của bạn.

## Kết Luận

Một trong những bước đầu tiên để hiểu cách các container hoạt động và cách cách cô lập bảo mật của chúng được thực hiện, là nhận ra rằng chúng chỉ là các process, vì nó mở ra nhiều tuyến đường để khám phá và hack các container.
