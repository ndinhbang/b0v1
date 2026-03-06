# Cách Trích Xuất Filesystem Của Container Image Sử Dụng Docker

Mặc dù về mặt kỹ thuật các container image được đại diện dưới dạng *các tầng thay đổi cumulative filesystem*, từ quan điểm của các nhà phát triển, chúng chỉ đơn giản là những nơi giữ các file của container tương lai. Và các nhà phát triển thường muốn khám phá nội dung của các container image tương ứng - với các công cụ quen thuộc như `cat`, `ls`, hoặc `find`. Trong hướng dẫn này, chúng ta sẽ xem **cách trích xuất filesystem của một container image sử dụng không gì ngoài các phương tiện Docker tiêu chuẩn.**

![From container image to filesystem.](https://labs.iximiuz.com/content/files/tutorials/extracting-container-image-filesystem/__static__/image-to-filesystem-min.png)

## Lệnh `docker save` không quá hữu ích

Đầu ra của `docker help` chỉ có một vài mục nhập trông có liên quan đến tác vụ của chúng ta. Cái đầu tiên trong danh sách là lệnh `docker save`:

```sh
Usage:  docker save [OPTIONS] IMAGE [IMAGE...]

Save one or more images to a tar archive (streamed to STDOUT by default)
```

Thử nó nhanh chóng cho thấy rằng nó không phải là thứ chúng ta cần:

Lệnh `docker save`, còn được gọi là `docker image save`, xả nội dung của image trong bộ lưu trữ của nó (tức là biểu thị lớp) trong khi chúng ta quan tâm đến việc thấy filesystem cuối cùng mà image sẽ tạo ra khi container sắp khởi động.

## Lệnh `docker export` gần như hoạt động

Lệnh thứ hai trông có liên quan là `docker export`. Hãy thử vận may của chúng ta với nó:

```sh
Usage:  docker export [OPTIONS] CONTAINER

Export a container's filesystem as a tar archive
```

Có vẻ như một ứng cử viên tốt. Tuy nhiên, một nỗ lực xuất filesystem của image `nginx:alpine` không thành công:

```sh
docker export ghcr.io/iximiuz/labs/nginx:alpine -o nginx.tar.gz
```

```sh
Error response from daemon: No such container: ghcr.io/iximiuz/labs/nginx:alpine
```

Vấn đề với lệnh `docker export` là nó hoạt động với các container chứ không phải với các image của chúng. Một cách khắc phục rõ ràng sẽ là bắt đầu một container `nginx:alpine` và lặp lại nỗ lực xuất:

```sh
CONT_ID=$(docker run -d ghcr.io/iximiuz/labs/nginx:alpine)

docker export ${CONT_ID} -o nginx.tar.gz
```

Bên trong có gì?

```sh
mkdir rootfs

tar -xf nginx.tar.gz -C rootfs

ls -l rootfs
```

```sh
total 68
lrwxrwxrwx  1 root root    7 Mar 11 00:00 bin -> usr/bin
drwxr-xr-x  2 root root 4096 Jan 28 21:20 boot
drwxr-xr-x  4 root root 4096 Apr  9 09:43 dev
drwxr-xr-x  2 root root 4096 Mar 12 01:55 docker-entrypoint.d
...
drwxrwxrwt  2 root root 4096 Mar 11 00:00 tmp
drwxr-xr-x 12 root root 4096 Mar 11 00:00 usr
drwxr-xr-x 11 root root 4096 Mar 11 00:00 var
```

💡 **Mẹo Chuyên Nghiệp:** Theo mặc định, trích xuất các file từ một archive tar đặt quyền sở hữu file thành người dùng hiện tại. Nếu **quyền sở hữu file** gốc cần được bảo tồn, bạn có thể sử dụng cờ `--same-owner` khi trích xuất archive. Hãy lưu ý rằng bạn sẽ phải đủ quyền để làm điều đó.

Ví dụ: `sudo tar --same-owner -xf nginx.tar.gz -C rootfs`

Vâng, đầu ra trông giống như những gì chúng ta cần - chỉ là một thư mục bình thường với một loạt file bên trong mà chúng ta có thể khám phá như bất kỳ filesystem nào khác. **Tuy nhiên, chạy một container chỉ để xem nội dung image của nó có những nhược điểm đáng kể:**

*   Kỹ thuật này có thể không cần thiết chậm (ví dụ: logic khởi động container nặng).
*   Chạy các container tùy ý là có khả năng không an toàn.
*   Một số file có thể được sửa đổi khi khởi động, làm hỏng kết quả xuất.
*   Đôi khi, chạy một container đơn giản là không thể (ví dụ: một image bị hỏng).

## Sự kết hợp hoạt động `docker create` + `docker export`

Các container là những sinh vật có trạng thái - [chúng giống như các file cũng như các quy trình](https://iximiuz.com/en/posts/containers-101-container-mgmt-commands/#process-file-duality). Đặc biệt, điều này có nghĩa là khi một quy trình containerized chết, môi trường thực thi của nó, bao gồm filesystem, được bảo tồn trên đĩa (trừ khi bạn chạy container với cờ `--rm`, tất nhiên). Do đó, sử dụng `docker export` cho một container đã dừng cũng nên có thể được. Tuy nhiên, cách tiếp cận này gặp phải gần như cùng một bộ nhược điểm giống như xuất filesystem của một container đang chạy - để nhận được một container đã dừng, bạn cần chạy nó trước tiên...

Nhưng chờ một giây! **Có một loại khác của các container không chạy - những cái được tạo nhưng chưa được khởi động.**

Lệnh nổi tiếng `docker run` thực sự là một lối tắt cho hai lệnh ít được sử dụng hơn - `docker create <IMAGE>` và `docker start <CONTAINER>`. Và vì các container không (chỉ) là các quy trình, lệnh `docker create`, đặc biệt, chuẩn bị root filesystem cho container tương lai.

Vì vậy, đây là mẹo:

```sh
CONT_ID=$(docker create ghcr.io/iximiuz/labs/nginx:alpine)

docker export ${CONT_ID} -o nginx.tar.gz
```

Và một oneliner tiện lợi (giả định thư mục mục tiêu đã được tạo):

```sh
docker export $(docker create ghcr.io/iximiuz/labs/nginx:alpine) | tar -xC <dest>
```

Đừng quên `docker rm` container tạm thời sau khi xuất xong 😉

## Giải pháp thay thế `docker build -o` chính xác hơn

Hầu hết lúc, sự kết hợp `docker create` + `docker export` tạo ra kết quả thỏa đáng. Tuy nhiên, bạn vẫn có thể nhận thấy một số tạo tác nhỏ trong filesystem kết quả. Ví dụ, filesystem được xuất có thể có file `/etc/hosts` thậm chí khi image gốc sẽ không có. Điều này là vì lệnh `docker create` thực sự thực hiện một số sửa đổi bổ sung trên top của filesystem trích xuất gốc.

**Nhưng điều gì nếu chúng ta muốn có filesystem gốc, mà không có bất kỳ sửa đổi nào?**

Hóa ra rằng bắt đầu với Docker 18.09 (phát hành ~đầu 2019), [có thể chỉ định một vị trí đầu ra tùy chỉnh cho lệnh `docker build` sử dụng cờ `--output|-o`](https://docs.docker.com/reference/cli/docker/image/build/#output). Vì vậy, đây là mẹo:

```sh
echo 'FROM ghcr.io/iximiuz/labs/nginx:alpine' > Dockerfile

# DOCKER_BUILDKIT=1 nếu bạn đang chạy Docker < 23.0
docker build -o rootfs .

ls -l rootfs
```

```sh
total 84
drwxr-xr-x  2 vagrant vagrant 4096 Aug 22 00:00 bin
drwxr-xr-x  2 vagrant vagrant 4096 Jun 30 21:35 boot
drwxr-xr-x  4 vagrant vagrant 4096 Sep 12 14:07 dev
drwxr-xr-x  2 vagrant vagrant 4096 Aug 23 03:59 docker-entrypoint.d
...
drwxr-xr-x  2 vagrant vagrant 4096 Aug 23 03:59 tmp
drwxr-xr-x 11 vagrant vagrant 4096 Aug 22 00:00 usr
drwxr-xr-x 11 vagrant vagrant 4096 Aug 22 00:00 var
```

Nói chung, [xây dựng các container image liên quan đến việc chạy các container trung gian](https://iximiuz.com/en/posts/you-need-containers-to-build-an-image/), nhưng nếu Dockerfile không có hướng dẫn `RUN`, như cái trên, không có container nào được tạo. Vì vậy, lệnh `docker build` sẽ chỉ sao chép nội dung image `FROM` vào image ẩn danh, và sau đó lưu kết quả vào vị trí đầu ra được chỉ định.

Cờ `--output` chỉ hoạt động nếu BuildKit được sử dụng làm công cụ xây dựng, vì vậy nếu bạn vẫn ở Docker < 23.0 (phát hành ~đầu 2023), bạn sẽ cần phải sử dụng `docker buildx build` hoặc đặt biến môi trường `DOCKER_BUILDKIT=1`.

⚠️ **Cảnh báo:** Có thể không thể bảo tồn thông tin **quyền sở hữu file** sử dụng cách tiếp cận `docker build -o`.

## Phương pháp `ctr image mount` thêm độc quyền

Như bạn có thể biết, Docker ủy thác ngày càng nhiều một số tác vụ quản lý container của nó cho một daemon cấp thấp hơn khác được gọi là [*containerd*](https://github.com/containerd/containerd). Điều này có nghĩa là nếu bạn có một daemon `dockerd` chạy trên một máy, rất có thể có một daemon `containerd` ở đâu đó gần bên cạnh. Và *containerd* thường đi kèm với client dòng lệnh riêng của nó, `ctr`, [có thể được sử dụng, đặc biệt, để kiểm tra các image](https://labs.iximiuz.com/courses/containerd-cli/ctr/image-management#advanced).

Phần tuyệt vời về *containerd* là nó cung cấp điều khiển chi tiết hơn nhiều so với các tác vụ quản lý container điển hình hơn Docker. Ví dụ, bạn có thể **sử dụng `ctr` để mount một container image tới một thư mục cục bộ, thậm chí không cần nhắc đến bất kỳ container nào:**

```sh
sudo ctr image pull ghcr.io/iximiuz/labs/nginx:alpine

mkdir rootfs

sudo ctr image mount ghcr.io/iximiuz/labs/nginx:alpine rootfs
```

Trong ví dụ trên, thư mục `rootfs` kết quả sẽ chứa filesystem được trích xuất của image `nginx:alpine`, mà không có bất kỳ `docker create`\-như tạo tác và mà không có tiềm ẩn khó hiểu các thủ thuật `docker build`.

Nhược điểm của cách tiếp cận này là bạn có thể cần phải pull image một cách rõ ràng trước khi mount nó, thậm chí nếu nó đã được pulled bởi Docker. Về lịch sử, `dockerd` và `containerd` sử dụng các backends lưu trữ image khác nhau, và không thể sử dụng `ctr` để truy cập các image thuộc sở hữu của `dockerd`. Một kiểm tra nhanh (`ctr --namespace moby image ls`) cho thấy rằng ít nhất với Docker Engine 26.0 (~Q1 2024), nó vẫn là trường hợp. Tuy nhiên, mọi thứ có thể đã được cải thiện trong Docker Desktop, nhờ vào [nỗ lực đang diễn ra để giao thêm và thêm các tác vụ cấp thấp hơn từ Docker cho containerd](https://www.docker.com/blog/extending-docker-integration-with-containerd/).

## Tóm Tắt

Trong bài báo này, chúng tôi đã học cách trích xuất filesystem của một container image sử dụng các lệnh Docker tiêu chuẩn. Như thường lệ, có nhiều cách để đạt được cùng một mục tiêu, và điều quan trọng là hiểu những sự đánh đổi của mỗi cách. Đây là một tóm tắt nhanh chóng của các phương pháp chúng tôi đã đề cập:

*   `docker save` không có khả năng là lệnh bạn đang tìm kiếm.
*   `docker export` hoạt động nhưng yêu cầu một container ngoài image.
*   `docker create` + `docker export` là một cách để xuất filesystem mà không cần khởi động container.
*   `docker build -o` là một cách tuy ngạc nhiên nhưng chính xác hơn để xuất filesystem.
*   `ctr image mount` là một phương pháp giải pháp thay thế thông minh cũng tạo ra các kết quả không có tạo tác.
