# Lab 12

In this lab we will install Docker, and redeploy a few services to run in Docker containers.

We'll learn how to launch a container from Docker Hub image, and also how to build the Docker image
locally.

Some hints common for all tasks:
 1. should you need to debug something inside the container you can run most standard Linux commands
   there as `docker exec <container-name> <command>`, for example
   `docker exec grafana cat /etc/resolv.conf`
 2. container name can be found in the `docker ps` output (last column)
 3. DNS requests won't work from the container running on the _same_ host as Bind server unless you
   authorize requests from the container network; check [lab 5](../05-dns-server) for details on how
   to configure Bind access rules, and `docker exec <container-name> ip a` to find the network
   address of the container (starts with `172.`)


## Task 1

Add another role named `docker` that will install Docker on your managed host.

Note: double check the package name you are installing! Package named `docker` in Ubuntu package
repository has nothing to do with containers. You will need a package named `docker.io` (yes, with
dot). You can find the details about the package by running these commands on a managed host:

    apt show docker
    apt show docker.io

You will also need to install another package to allow Ansible to manage Docker resources. The
package name is `python3-docker`, it is a Python library that allows Ansible modules to execute
Docker commands and manage your Docker resources.

Ensure that the Docker daemon is running and is enabled to start on system boot.

You can check if Docker daemon is running with this command run as root on the managed host:

    docker info


## Task 2

Rename the existing Grafana files:

    roles/grafana/handlers/main.yaml --> roles/grafana/handlers/apt.yaml
    roles/grafana/tasks/main.yaml --> roles/grafana/tasks/apt.yaml

You won't need them anymore for any further labs on this course, but we recommend to keep the files
in your repository; you might find them useful in your future endeavors.

If you have already installed Grafana to one of your managed servers as described in
[lab 7](../07-grafana) -- stop and uninstall it; run these commands manually as root:

    service grafana-server stop
    apt purge grafana
    rm -rf /etc/grafana
    rm -rf /var/lib/grafana
    rm /etc/apt/sources.list.d/grafana.list

Create the new file `roles/grafana/tasks/main.yaml` that will install and start the Grafana in the
Docker container. Use Docker image named [grafana/grafana](https://hub.docker.com/r/grafana/grafana))
from the Docker Hub, and Ansible module
[docker_container](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html).

Make sure the container you start is named exactly `grafana`. If you don't set the name Docker will
create a random name for the container, and it will make the debugging harder.

Update the playbook `infra.yaml` and add the `docker` role to the Grafana play role list, before the
`grafana` role. Run Ansible to apply the changes:

    ansible-playbook infra.yaml

If you have done everything correctly, Grafana container should be started now. You can check if the
container is running with this command:

    docker ps

Example output:

    CONTAINER ID  IMAGE            COMMAND    CREATED  STATUS         PORTS     NAMES
    4edd5904d11d  grafana/grafana  "/run.sh"  ...      Up 42 seconds  3000/tcp  grafana


'Up 42 seconds' here means that Grafana container is running. If it's not, you can probably find
your container in the failed state:

    docker ps -a

Example output (note the 'STATUS' column):

    CONTAINER ID  IMAGE            COMMAND    CREATED  STATUS                     PORTS  NAMES
    6596819763cb  grafana/grafana  "/run.sh"  ...      Exited (1) 42 seconds ago         grafana

If the container is not starting, or not working as expected you can check its logs with:

    docker logs grafana

Hint: it also supports the "follow" mode:

    docker logs -f grafana    # exit with Ctrl+C


## Task 3

Configure Grafana and provision datasources.

Previously we installed Grafana from the APT package, and it created needed files and directories
automatically. It does so in the container as well, but we cannot change these files there. Instead,
we can pre-create the needed files on Docker host, and mount them into container as _volume_.

For that, update `roles/grafana/tasks/main.yaml` to create the needed files and directories on
Docker hosts before the Grafana container is started.

Directories:

    /opt/grafana/provisioning/dashboards
    /opt/grafana/provisioning/datasources

Files:

    /opt/grafana/grafana.ini
    /opt/grafana/provisioning/dashboards/default.yaml
    /opt/grafana/provisioning/dashboards/backups.json
    /opt/grafana/provisioning/dashboards/main.json
    /opt/grafana/provisioning/dashboards/mysql.json
    /opt/grafana/provisioning/dashboards/syslog.json
    /opt/grafana/provisioning/datasources/default.yaml

Purpose of these directory and files should be familiar to you from the lab 7.

 - use your old tasks file `tasks/apt.yaml` as an example
 - create both directories in one task; use `loop` construct -- check out lab 11 for examples

Example:

      name: "/opt/grafana/conf/provisioning/{{ item }}"
      state: directory
    loop:
      - ...
      - ...

Update the dashboard provisioning configuration file (`provisioning/dashboards/default.yaml`) and
change the provider path to `/etc/grafana/provisioning/dashboards`. Check Grafana provisioning
reference for details:
https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards

Note that in this lab we keep both dashboard provisioning configuration and the dashboards
themselves (JSON files) in the same directory. Grafana is not allowed to change these files in our
setup anyway, so there is no point to keep them in `/var/lib/grafana`.

Update the `grafana.ini` file to set the Grafana admin password if you haven't done it yet.
Check Grafana configuration reference for details:
https://grafana.com/docs/grafana/latest/administration/configuration/#admin_password

Add a new handler to restart the Grafana docker container to `roles/grafana/handlers/main.yaml`:
 - reuse your old handler from `roles/grafana/handlers/apt.yaml` -- copy it to a new file and
   modify the code to restart the _container_, not the service
 - check out the `restart` parameter of the `docker_container` module -- it does exactly what is
   needed here

Update your `docker_container` task in the `grafana` role and mount the Grafana configuration
directory; add this parameter to the `docker_container` module:

    volumes: /opt/grafana:/etc/grafana

Run Ansible to apply the changes. Make sure that Grafana container is restarted and is still
running after your changes are applied:

    docker ps

Note the time in 'STATUS' column. If the container was not restarted, trigger the restart by
modifying the `grafana.ini` file (add or remove empty line) and running Ansible again.


## Task 4

Configure public access to the Grafana.

So far Grafana is only accessible from inside the Docker container; we need to expose it by binding
the container port to the Docker host port, and configuring the Nginx proxy to forward requests to
this host port.

Grafana is configured to run behind proxy already -- you've done it in the lab 7, and reused the
same configuration file (`grafana.ini`) for the Docker container.

Next, update your `docker_container` to bind the container port Grafana is listening on (3000) to
port 3001 of the Docker host. Make this number a variable so you can change it later:

    published_ports: "{{ grafana_port }}:3000"

Also make sure to update the Nginx proxy configuration accordingly, for example:

    proxy_pass: http://localhost:{{ grafana_port }};

Run the Ansible to apply the changes. If you've done everything correctly, Grafana should be now
available on one of your public URLs, for example, http://193.40.156.67:11180/grafana (yours will be
different).

 - you should see the Grafana login form there
 - use password set in `grafana.ini` to log in
 - all datasources (Prometheus, InfluxDB) and dashboards (Backups, Main, MySQL, Syslog) should be there

If the dashboards or datasources are not there, re-check if you've done task 3 fully and correctly.

If you don't see Grafana login form, check that:
 1. You are accessing the correct URL
 2. You have configured the Nginx proxy correctly
 3. Grafana container is running, and needed port is published to the Docker host

You can check that Grafana container is running with this command:

    docker ps

Note the 'PORTS' column, and make sure that correct ports are published:

    0.0.0.0:3001->3000/tcp


## Task 5

Rename the existing Agama tasks file:

    roles/agama/tasks/main.yaml --> roles/agama/tasks/apt.yaml

If you have already installed Agama and/or uWSGI to one of your managed servers as described in
[lab 3](../03-web-server) -- stop and uninstall it; run these commands manually as root:

    service uwsgi stop
    apt purge python3-flask python3-pymysql uwsgi
    apt autoremove
    rm -rf /etc/uwsgi
    rm -rf /opt/agama
    userdel -r agama

Install the new Agama that runs in Docker container. For that, create the new `main.yaml` file in
`roles/agama/tasks`.

Create a directory `/opt/agama`. This time it shouldn't be owned by user `agama` as in lab 3;
in fact, we don't need a user `agama` at all on this host. Don't set the directory ownership in
Ansible -- it will be owned by root by default.

Agama does not have an image in the Docker Hub, so it needs to be built on the managed host.

You will still need `/opt/agama/agama.py` file. But this time it won't be run by uWSGI, but copied
to Docker image instead. You have Ansible task already that downloads the file in `tasks/apt.yaml`
-- copy it to the new tasks file `tasks/main.yaml`.

Dockerfile can be found in the Agama repository:
https://github.com/hudolejev/agama/blob/master/Dockerfile -- click 'Raw' to get the direct download
URL. You will need to download it to the managed host -- use Ansible module
[get_url](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/get_url_module.html)
for that.

Save this file as `/opt/agama/Dockerfile`.

Downloading both files can be done in one task, using `loop`. You can use task 3 solution (Grafana
provisioning) as an example.

Build Docker image from this file using Ansible module
[docker_image](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_image_module.html)

It has many arguments but don't get too excited with that. Something simple like this would work
just fine:

    name: agama
    source: build
    build:
      path: /opt/agama

 - build directory (path) should be `/opt/agama`
 - image name should be `agama`
 - building the image will take a few minutes...

Please **do not** push the image to Docker Hub.

Once done, use `docker_container` module to start the container from the built image, similarly as
you did for the Grafana. Make sure to use the same image name (`agama`) in `docker_image` and
`docker_container` modules so that Docker would use your local image instead of downloading it from
Docker Hub.

Note that you will need to provide additional environment variable to the container with MySQL
connection URL for Agama, similarly as you did for uWSGI in the [lab 4](../04-troubeshooting); add
this parameter to the `docker_container` module:

    env:
      AGAMA_DATABASE_URI: mysql+pymysql://<...>

You can reuse the connection string from the `uwsgi` role.

**Note: this task now contains sensitive data (MySQL password) that should not be logged!**

Bind the container port to port 8001 of the Docker host.

Update your Nginx configuration for Agama proxy accordingly. Note that  Agama from Docker is exposed
as _HTTP service_ (similar to Prometheus and Grafana), not uWSGI.

Once installed, new dockerized AGAMA should be accessible on the same URL as the old one before, via
Nginx proxy.


## Expected result

Your repository contains these files:

    infra.yaml
    roles/
        agama/tasks/main.yaml
        docker/tasks/main.yaml
        grafana/tasks/main.yaml

Your Agama application is accessible on its public URL.

Your Grafana is accessible on its public URL.

Agama and Grafana are both running in Docker containers; no local services named `grafana-server` or
`uwsgi` are running on any of your managed hosts.
