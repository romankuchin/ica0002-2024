# Lab 12 demo: Docker basics

## Intro

First, we will need to install Docker daemon and client tools. There are multiple ways how to do it,
but we will use the simplest possible approach for the demo:

    - name: Docker package
      ansible.builtin.apt:
        name: docker.io

    - name: Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: true

Note the package name, `docker.io` -- this name is inspired by previous Docker website name and
chosen not to conflict with another package in Debian and Ubuntu repositories called `docker`; the
latter has nothing to do with containers:

    Package: docker
    Description: System tray for KDE3/GNOME2 docklet applications

    Package: docker.io
    Description: Linux container runtime

Also note that if you decide to install the package from the Docker own repository as described
[here](https://docs.docker.com/engine/install/ubuntu/) the DEB package name will be different again:
`docker-ce`.

For this demo a bit older Docker version from Ubuntu `universe` repository is just fine.

Next, let's make sure that Docker container runtime itself is up and running:

    systemctl status docker

... and the Docker client is working (this and the following need to be run as `root` in this demo):

    docker info


## First Docker container

Docker team has prepared one very simple container image to verify the Docker installation. Let's
download and run it:

    docker run hello-world

It should print something like

    Unable to find image 'hello-world:latest' locally
    latest: Pulling from library/hello-world
    c1ec31eb5944: Pull complete
    Digest: sha256:305243c734571da2d100c8c8b3c3167a098cab6049c9a5b066b6021a60fcb966
    Status: Downloaded newer image for hello-world:latest

    Hello from Docker!
    This message shows that your installation appears to be working correctly.

	...

Read the output carefully. It explains in details what Docker just did.

Docker Hub is a public Docker registry, in simple words, it is the "package repository" for Docker
where "package" is the container image.

The action above has left some artifacts on the Docker host, namely the downloaded container image:

    docker images

Now if you run `docker run hello-world` again it will not re-download the container but use the
local version instead:

    docker run hello-world


## Second Docker container

We cannot do much with this `hello-world` app. So let's run another container:

    docker run -it alpine /bin/sh

 - `alpine` here stands for image name; this is an image for container with
   [Alpine Linux](https://alpinelinux.org), a minimalist Linux distribution quite popular for
   containerized applications;
 - `-it` means `--interactive --tty` which instructs Docker daemon to start the interactive session
   with the container and allocate the pseudo-terminal for that; check `docker run --help` for more
   details;
 - `/bin/sh` is the command we asked Docker to run inside the container

As a result, terminal prompt should change to something like

    / #

This is the shell inside the container! Let's look around there:

    cat /etc/issue
    > Welcome to Alpine Linux 3.20
    > Kernel \r on an \m (\l)

    uname -a
    > Linux a271452da8e6 5.15.0-1051-kvm #56-Ubuntu SMP Thu Feb 8 23:30:16 UTC 2024 x86_64 Linux

The first command will print the system identification -- the system running in the container as
seen by applications is Alpine Linux v3.20.

The second command will print the Linux kernel version, and you can easily notice that the kernel
(Ubuntu) does not quite match the userspace (Alpine).

This is how operating system virtualization (or containerization) work: both host and guest systems
share the same Linux kernel but their userspaces are isolated from each other. Let's make some
damage in the container:

    # Make sure to run this in the container, *not* on the Docker host!
    rmdir /opt
    exit

Note that `/opt` directory is still present on the host; it was only removed from the container:

    ls -la /opt

Also note that the Linux kernel version on the host system is the same as was in the container:

    uname -a


## Containerized service example

Docker containers were designed to run services. Every container is expected to run exactly one
process. In previous example the process was `/bin/sh` and it was running in interactive mode. Once
we terminated the session the process was terminated as well. You can list the terminated Docker
containers with

    docker ps -a

Running processes can be listed with

    docker ps

Note that there are none. So let's start on of the processes in Alpine Linux container and leave it
running in daemon mode. This process could be a `top` utility:

    docker run -d alpine top

`-d` here means `--detach`: Docker will launch the container and leave it running without keeping
any interactive session open.

The process should now appear in the list of running Docker containers:

    docker ps

You can attach to the running container using its id:

    docker attach 4e411b27a685

You should see the `top` process running. Note that it is the only running process in this
container; although it is technically possible to launch more than one process in the same container
it is still a bit of a witchcraft, and Docker discourages these attempts.

You can detach from the process by pressing `Ctrl+C`. The process will be terminated, and so the
container that hosted it:

    docker ps
    docker ps -a


## Some real services

Now once we know the basics of the Docker container anatomy we can try running some real services,
containerized. One possible candidate is Nginx web server:

    docker run -d nginx
    docker ps

It will take some time to download, but in the end you should see the Nginx container running and
listening on port 80/tcp. But if you check the local processes listening on port 80 you will find
none:

    ss -lnpt

(If there is something listening on port 80, it may be another Nginx installed locally -- not the
one from the container.)

This is another example of process isolation. By default Docker containers will not bind to host
system ports automatically, this needs to be allowed explicitly. Let's stop the running Nginx
container and launch it again, this time providing the port configuration:

    docker stop bb5f196693ea
    docker run -d -p8081:80 nginx

`-p8081:80` here means `--publish 8081:80` -- this exposes container's port 80 and binds it to
host's port 8081. This is done by another service called Docker proxy that listens on port 8081 on
the Docker host and forwards all the incoming traffic to the port 80 of the container:

    ss -lnpt

It should now be possible to communicate with the Nginx process running in the container via port
8081 on the Docker host:

    curl http://localhost:8081

should return the page served by Nginx.


## Grafana container

Let's get it further and deploy the entire Grafana in Docker container:

    docker run -d -p3001:3000 --name=grafana grafana/grafana

Note the `--name=grafana` part. We are naming the container `grafana` -- otherwise Docker will
generate some random name for it. You can find the container name in the rightmost column of
`docker ps` output.

Grafana will listen on the port 3000 in the container but we've instructed Docker proxy to bind to
port 3001 on the Docker host and forward all the incoming traffic to the port 3000 in the container:

    ss -lnpt

We can access Grafana login page from the same host now:

    curl http://localhost:3001
    curl -L http://localhost:3001

At this point it makes sense to stop doing the damage manually and switch to Ansible. Yes, there is
a module to manage Docker containers:
[docker_container](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html)!

Let's take the last demonstarted `docker run` commands and reimplement then with Ansible:

    - name: Grafana Docker container
      community.docker.docker_container:
        name: grafana
        image: grafana/grafana
        published_ports: 3001:3000

As you remember we've set up a Nginx proxy on the previous labs to serve Grafana from a custom path
like `http://193.40.156.67:xx80/grafana`, and that required additional Grafana configuration in
`grafana.ini` file. This file is now located in the Docker container now, and although it's possible
to change it dynamically -- there is a better way.

Certain files and directories from the host system can shared with the container. Docker implements
this as "volume mounting", so that shared directory is seen as a volume inside container. Actually
some files are already mounted inside container; you can check it by running

    docker exec grafana df

`docker exec` followed by a container name (or id) tells Docker daemon to execute this command
(`df` in this example) inside the container. Note that it doesn't kill the main process as when
using `attach`.

You'll notice a few rows like these:

    /dev/root  7941576  4222376  3702816  53%  /etc/resolv.conf
    /dev/root  7941576  4222376  3702816  53%  /etc/hostname
    /dev/root  7941576  4222376  3702816  53%  /etc/hosts

These are virtual volumes as container sees them, and are actually just files Docker daemon
generated and mounted inside the container. Note that these files are _not_ the same as on host
system:

    docker exec grafana cat /etc/hostname  # this shows the file in the container
    cat /etc/hostname                      # this shows the file on the host system

So let's create Grafana configuration directory, and mount it inside the container:

    - name: Grafana directory
      ansible.builtin.file:
        name: /opt/grafana
        state: directory

    - name: Grafana Docker container
      community.docker.docker_container:
        name: grafana
        image: grafana/grafana
        volumes: /opt/grafana:/etc/grafana    # <-- added this
        published_ports: 3001:3000

`/opt/grafana:/etc/grafana` means that `/opt/grafana` directory from the host system is mounted as
virtual volume inside the container to `/etc/grafana`. Run the Ansible and check the result:

    docker exec grafana df

Oh no! The container is not running! Why? What happened?

    docker ps -a

You can find the reason in the container logs; it also workes with the stopped containers:

    docker logs grafana

You'll find the problem pretty quickly:

    GF_PATHS_CONFIG='/etc/grafana/grafana.ini' is not readable.
    failed to parse "/etc/grafana/grafana.ini": open /etc/grafana/grafana.ini: no such file or directory

The directory we have mounted is empty, and it has "overwritten" existing `/etc/grafana` directory
from the container. So Grafana could not read the `grafana.ini` file because, well, there were _no_
such file in the container! We have this file created on the previous labs, let's add it:

    - name: Grafana configuration
      ansible.builtin.template:
        src: grafana.ini.j2
        dest: /opt/grafana/grafana.ini   # note that path is changed form /etc/ to /opt/
      no_log: true

Grafana container should be running now, and configuration directory should be mounted inside:

    docker ps
    docker exec grafana df

We're missing one more step to access the Grafana: Nginx proxy configuration needs to be changed to
serve Grafana from the Docker container:

    location /grafana {
        proxy_pass http://localhost:3001;  # <-- here
        proxy_set_header Host $http_host;
    }

After Ansible is run to apply the changes Grafana should be available on one of your public URLs:
http://193.40.156.67:xxx80/grafana

You should be able to log in to Grafana with password you specified in `grafana.ini`. Or, if you
didn't change it in `grafana.ini`, default login credentials are `admin:admin`.

Further Grafana configuration will be covered in the upcoming lab.


## Summary

In this demo we have discussed main Docker container lifecycle stages.

We've also learned how to

 - start Docker containers with `docker run` and with Ansible module `docker_container`
 - publish container ports to Docker host
 - mount directories from the Docker host to the containers
 - list running Docker containers with `docker ps` and failed containers with `docker ps -a`
 - run commands inside containers with `docker exec`
 - read container logs with `docker logs`
 - stop containers with `docker stop`
 - list available Docker images with `docker images`


## Final notes

This is a very basic demo on how to handle Docker containers. We did not create any container
images, yet, but only used available, ready made images from Docker Hub.

Images we used:
 - https://hub.docker.com/_/hello-world
 - https://hub.docker.com/_/alpine
 - https://hub.docker.com/_/nginx
 - https://hub.docker.com/r/grafana/grafana

**SECURITY NOTE ABOUT DOCKER HUB**

Do not blindly trust images from Docker Hub!

If downloading an image, make sure it is an official Docker image!

See also: https://docs.docker.com/docker-hub/official_images

Sometimes it is hard to tell if the image is released buy Docker team or the product team. Check out
these two and carefully inspect the pages:

 - https://hub.docker.com/_/nginx
 - https://hub.docker.com/r/grafana/grafana

Only one of them is official Docker image as it is built by Docker team. Another, although also
called 'official', is not provided by Docker but by the product developers. Both teams interpret the
word 'official' differently; you should understand this difference if working with Docker Hub.

**Only use Docker Hub images from the authors whom you trust!**
