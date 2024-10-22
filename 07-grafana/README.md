# Lab 7

In this lab we will continue with monitoring. The goal of this lab is to create a place where everyone can get overview of your infrastructure state.

## Task 1: Install MySQL exporter

Install MySQL exporter from Ubuntu package repository.

Create MySQL user dedicated for exporter.

Docs: https://github.com/prometheus/mysqld_exporter

Use ~/.my.cnf for passing auth data to MySQL exporter. Find under what user it runs and what folder is a home folder for that user. Nobody except user itself can read this file. Nobody can change the file.

Content of ~/.my.cnf:

    [client]
    user=your_user
    password=your_password

Make sure that exporter will be restarted in case username/password change.

**No cleartext passwords in repo**

Exporter tasks should be a part of `mysql` role.

## Task 2: Install Bind9 exporter

Install Bind9 exporter version 0.6.1 or newer.

Download archive to `/opt`.

Create a link to executable: `/usr/local/bin/prometheus-bind-exporter` -> `/opt/...`, put service definition to `/etc/systemd/system/`.

Don't forget to reload systemd after changing its config.

Expose Bind9 statistics for exporter.

Docs: https://github.com/prometheus-community/bind_exporter

Exporter tasks should be a part of `bind` role.

Ansible modules to use: unarchive, file, template.

## Task 3: Install Nginx exporter

Install Nginx exporter from Ubuntu package repository.

Make sure that Nginx exposes statistics to exporter.

Docs: https://github.com/nginxinc/nginx-prometheus-exporter

Exporter tasks should be a part of `nginx` role.

## Task 4: Install Grafana

Docs: https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/#install-from-apt-repository

Use steps for Grafana OSS.

Ansible modules to use: apt_key, apt_repository, apt.

## Task 5: Configure reverse proxy

Add necessary locations to Nginx config:

    - location /grafana -> localhost:(grafana_port)
    
Helpful docs for Grafana: https://grafana.com/tutorials/run-grafana-behind-a-proxy

Don't add locations that point to unexisting services. You can use this code for checking if we should expect some path on this VM or not:

    {% if inventory_hostname in groups['prometheus'] %}
    location /prometheus {
        proxy_pass http://localhost:xyz/;
    }
    {% endif %}

## Task 6: Create dashboard in Grafana

Create Grafana `Main` dashboard that will show:
 - CPU utilisation on VMs
 - Memory consumption on VMs
 - Bind9 status + amount of A DNS queries per minute (bind_resolver_queries_total)
 - MySQL status + amount of selects per minute (mysql_global_status_commands_total)
 - Nginx status + amount of requests per minute (nginx_http_requests_total)

Use Prometheus as datasource.

## Task 7: Configure Grafana provisioning

To avoid manual operations every time do the following during Grafana installation:

 - Configure Prometheus as default datasource (https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources)
 - Precreate `Main` dashboard (https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards)
 - Precreate user (your GH username) and password

**No cleartext passwords in repo**

## Expected result

Your repository contains these files and directories:

    ansible.cfg
    group_vars/all.yaml
    hosts
    infra.yaml
    roles/grafana/tasks/main.yaml
    roles/grafana/files/main.json

Your repository also contains all the required files from the previous labs.

Your repository **does not contain** Ansible Vault master password.

Grafana, exporters and reverse proxy are installed and configured with this command:

	ansible-playbook infra.yaml

Running the same command again does not make any changes to any of the managed
hosts.

After playbook execution you should be able to:

1. See grafana dashboard by using \<your_VM_http_link\>/grafana.

2. Check your Prometheus web-interface by using \<your_VM_http_link\>/prometheus (lab06).

3. Access Agama by using \<your_VM_http_link\> (lab04).
