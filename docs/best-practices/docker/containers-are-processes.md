# Containers are processes | iximiuz Labs

A core benefit of using containers is that most of the time you don’t have to think about what’s happening under the hood. Tools like Docker and Kubernetes do a great job of hiding complexity from their users.

However, when you need to debug and secure containerized environments, it can be very helpful to understand how to interact with containers at a low level. Fortunately, because most containerization tools are built on Linux, you can use existing Linux tools to interact with and debug them.

When securing containerized environments, it’s also vital to understand how containers use layers of isolation, and how those layers can fail, so you can mitigate any risks.

In this tutorial, we'll demonstrate that containers are processes, use Linux tools to interact with containers, and explore what this means for securing container environments.

## Containers are just processes

The first thing to understand about containers is that, from an operating system perspective, they’re processes just like any other application that runs directly on the host.

Let's start by checking if there are any active processes named `simple-webserver` on our tutorial playground. If you haven't already, click the "Start playground" button on the right. Then we can run the command below to look for instances of our simple webserver

This should return an empty list, as we don’t have any simple web servers running at the moment.

Now, let's start a Docker container by using the a simple webserver image from Docker Hub, which just starts a very basic webserver process that's good for demonstration.

```sh
docker run --name webserver -d ctrsec/swc
```

Once the container is up, we'll run our `ps` command again:

This time, we get back something like the below, which shows us that we now have a `simple-webserver` process now running on the machine. As far as our Linux machine is concerned, someone just ran that process on the host.

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc.png)

As we dig deeper into the notion that containers are processes, one initial question might be: how do you tell the difference between an process started from a Docker image and one that’s just been installed on a Virtual Machine? There are a couple of ways to do that, but the first, easiest one is to check for running containers with `docker ps`:

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc-docker-ps.png)

Alternatively, we could use Linux process tools to determine if the web server is running as a container for example with the `--forest` option on `ps`.

This lets us see a hierarchy of processes. In this case, our `simple-webserver` process has a parent process of `containerd-shim-runc-v2`. You should see a shim process for each container running on the host. This shim process is part of containerd and is used by Docker to manage contained processes. The goal of this shim process is to allow containerd or the Docker daemon to be restarted without having to restart all the containers running on the host.

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc-forest.png)

## Interacting with a container as a process

We now know that containers are just processes—but what does that mean in terms of how we can interact with them? Being able to interact with them as processes is useful for both troubleshooting their operation and investigating changes in running containers (for example, in a forensic investigation). There are a couple of things to keep in mind here, but the first is that we can use the `/proc` filesystem to get more information about our running containers.

The `/proc` filesystem in Linux is a virtual or pseudo filesystem. It doesn’t contain real files—instead, it is populated with information about the running system. As long as a user has the right privileges on a host that runs Docker, they can use `/proc` to access information about any container running on the host.

Let’s look at some information about the simple webserver container we started up earlier. first we'll get a note of the PID of our nginx container, this time using `docker inspect` which shows details of the running container

```sh
docker inspect --format '{{.State.Pid}}' webserver
```

Next we'll list the files in `/proc`.

We will see a numbered directory for every process on the host including the PID that you got as output from the `docker inspect` command. Each of these directories contains a variety of files and directories with information about that process, meaning that we can navigate into the directory for our container to find out more about our contained process.

It can also be helpful to use Linux tooling to work with containers that have been hardened to remove tools such as file editors or process monitors. Hardening container images is a common security recommendation, but it does make debugging trickier. You can edit files inside the container by accessing the container’s root filesystem from the `/proc` directory on the host. Navigating to `/proc/[PID]/root` will give you the directory listing of the contained process that has that PID.

You can run the command below, replacing `[PID]` with the process ID of your container to see that output.

The result should look a lot like this.

![](https://labs.iximiuz.com/content/files/tutorials/containers-are-processes-d17b1df8/__static__/swc-proc-ls.png)

We can confirm that this is the filesystem for our container, by creating a new file inside the container using `docker exec` and then seeing the result in the proc filesystem

First run this `docker exec` command to create a new file in the container

```sh
docker exec webserver touch /test_file
```

Then run the `ls` command again, replacing `[PID]` with the process ID of your container.

## Conclusion

One of the first steps to understanding how containers work and how their security isolation is implemented, is realising that they're just processes, as it opens up lots of routes for exploring and hacking with containers.
