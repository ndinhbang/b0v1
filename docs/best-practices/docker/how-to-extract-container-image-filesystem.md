# How To Extract Container Image Filesystem Using Docker

Even though technically container images are represented as *layers of cumulative filesystem changes*, from a mere developer's standpoint, they are just simple holders of future container files. And developers often want to explore the contents of container images accordingly - with familiar tools like `cat`, `ls`, or `find`. In this tutorial, we'll see **how to extract the filesystem of a container image using nothing but the standard Docker means.**

![Container image to filesystem.](https://labs.iximiuz.com/content/files/tutorials/extracting-container-image-filesystem/__static__/image-to-filesystem-min.png)

## The not so helpful `docker save` command

The `docker help` output has just a few entries that look relevant for our task. The first one in the list is the `docker save` command:

```sh
Usage:  docker save [OPTIONS] IMAGE [IMAGE...]

Save one or more images to a tar archive (streamed to STDOUT by default)
```

Trying it out quickly shows that it's not something we need:

The `docker save` command, also known as `docker image save`, dumps the content of the image in its storage (i.e. layered) representation while we're interested in seeing the final filesystem the image would produce when the container is about to start.

## The almost working `docker export` command

The second command that looks relevant is `docker export`. Let's try our luck with it:

```sh
Usage:  docker export [OPTIONS] CONTAINER

Export a container's filesystem as a tar archive
```

Seems like a good candidate. However, an attempt to export the filesystem of the `nginx:alpine` image fails:

```sh
docker export ghcr.io/iximiuz/labs/nginx:alpine -o nginx.tar.gz
```

```sh
Error response from daemon: No such container: ghcr.io/iximiuz/labs/nginx:alpine
```

The problem with the `docker export` command is that it works with containers and not with their images. An obvious workaround would be to start an `nginx:alpine` container and repeat the export attempt:

```sh
CONT_ID=$(docker run -d ghcr.io/iximiuz/labs/nginx:alpine)

docker export ${CONT_ID} -o nginx.tar.gz
```

What's inside?

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

💡 **Pro Tip:** By default, extracting files from a tar archive sets the file ownership to the current user. If the original **file ownership** needs to be preserved, you can use the `--same-owner` flag while extracting the archive. Beware that you'll have to be sufficiently privileged for that.

Example: `sudo tar --same-owner -xf nginx.tar.gz -C rootfs`

Well, the output does look like what we need - just a regular folder with a bunch of files inside that we can explore as any other filesystem. **However, running a container just to see its image contents has significant downsides:**

*   The technique might be unnecessarily slow (e.g., heavy container startup logic).
*   Running arbitrary containers is potentially insecure.
*   Some files can be modified upon startup, spoiling the export results.
*   Sometimes, running a container is simply impossible (e.g., a broken image).

## The working `docker create` + `docker export` combo

Containers are stateful creatures - [they are as much about files as about processes](https://iximiuz.com/en/posts/containers-101-container-mgmt-commands/#process-file-duality). In particular, it means that when a containerized process dies, its execution environment, including the filesystem, is preserved on disk (unless you ran the container with the `--rm` flag, of course). Thus, using `docker export` for a stopped container should be possible, too. However, this approach suffers from pretty much the same set of drawbacks as exporting a filesystem of a running container - to get a stopped container, you need to run it first...

But wait a second! **There is another type of not-running containers - the ones that were created but haven't been started yet.**

The well-known `docker run` command is actually a shortcut for two less frequently used commands - `docker create <IMAGE>` and `docker start <CONTAINER>`. And since containers aren't (only) processes, the `docker create` command, in particular, prepares the root filesystem for the future container.

So, here is the trick:

```sh
CONT_ID=$(docker create ghcr.io/iximiuz/labs/nginx:alpine)

docker export ${CONT_ID} -o nginx.tar.gz
```

And a handy oneliner (assuming the target folder has already been created):

```sh
docker export $(docker create ghcr.io/iximiuz/labs/nginx:alpine) | tar -xC <dest>
```

Don't forget to `docker rm` the temporary container after the export is done 😉

## The more accurate `docker build -o` alternative

Most of the time, the `docker create` + `docker export` combo produces satisfactory results. However, you may still notice some tiny artifacts in the resulting filesystem. For instance, the exported filesystem may have the `/etc/hosts` file even when the original image would not have one. This is because the `docker create` command actually performs some additional modifications on top of the extracted original filesystem.

**But what if we want to get the original filesystem, without any modifications?**

Turns out that starting with Docker 18.09 (released ~early 2019), [it's possible to specify a custom output location for the `docker build` command using the `--output|-o` flag](https://docs.docker.com/reference/cli/docker/image/build/#output). So, here is the trick:

```sh
echo 'FROM ghcr.io/iximiuz/labs/nginx:alpine' > Dockerfile

# DOCKER_BUILDKIT=1 if you're running Docker < 23.0
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

Generally speaking, [building container images involves running intermediate containers](https://iximiuz.com/en/posts/you-need-containers-to-build-an-image/), but if the Dockerfile has no `RUN` instructions, as the one above, no containers will be spun up. So, the `docker build` command will just copy the `FROM` image contents into the anonymous image, and then save the result to the specified output location.

The `--output` flag works only if BuildKit is used as a builder engine, so if you're still on Docker < 23.0 (released ~early 2023), you'll either need to use `docker buildx build` or set the `DOCKER_BUILDKIT=1` environment variable.

⚠️ **Caveat:** It might be impossible to preserve the **file ownership** information using the `docker build -o` approach.

## The bonus `ctr image mount` method

As you probably know, Docker delegates more and more some of its container management tasks to another lower-level daemon called [*containerd*](https://github.com/containerd/containerd). It means that if you have a `dockerd` daemon running on a machine, most likely there is a `containerd` daemon somewhere nearby as well. And *containerd* often comes with its own command-line client, `ctr`, [that can be used, in particular, to inspect images](https://labs.iximiuz.com/courses/containerd-cli/ctr/image-management#advanced).

The cool part about *containerd* is that it provides a much more fine-grained control over the typical container management tasks than Docker does. For instance, you can **use `ctr` to mount a container image to a local folder, without even mentioning any containers:**

```sh
sudo ctr image pull ghcr.io/iximiuz/labs/nginx:alpine

mkdir rootfs

sudo ctr image mount ghcr.io/iximiuz/labs/nginx:alpine rootfs
```

In the above example, the resulting `rootfs` folder will contain the extracted filesystem of the `nginx:alpine` image, without any `docker create`\-like artifacts and without potentially confusing `docker build` tricks.

The downside of this approach is that you may need to pull the image explicitly before mounting it, even if it has been already pulled by Docker. Historically, `dockerd` and `containerd` used different image storage backends, and it was not possible to use `ctr` to access images owned by `dockerd`. A quick check (`ctr --namespace moby image ls`) shows that at least with Docker Engine 26.0 (~Q1 2024), it's still the case. However, things may have already improved in Docker Desktop, thanks to the [ongoing effort to offload more and more lower-level tasks from Docker to containerd](https://www.docker.com/blog/extending-docker-integration-with-containerd/).

## Summarizing

In this article, we've learned how to extract the filesystem of a container image using standard Docker commands. As usual, there are multiple ways to achieve the same goal, and it's important to understand the trade-offs of each one. Here is a quick summary of the methods we've covered:

*   `docker save` is unlikely the command you're looking for.
*   `docker export` works but requires a container in addition to the image.
*   `docker create` + `docker export` is a way to export the filesystem w/o starting the container.
*   `docker build -o` is a potentially surprising but a more accurate way to export the filesystem.
*   `ctr image mount` is a clever alternative method that also produces artifact-free results.
