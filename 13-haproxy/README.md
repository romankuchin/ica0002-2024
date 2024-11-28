# Lab 13

In this lab we will install Keepalived and HAProxy in front of our Docker containers.

## Task 1. Run Agama in Docker containers

Start at least 2 containers with Agama app on each VM. Reuse role from lab12. Your code should support creation as many containers as desired by configuration.

## Task 2. Install Keepalived

Keepalived will assign to pair of your VMs additional virtual IP. That IP will be assigned to one VM at a time, that VM will be MASTER. Second VM will become BACKUP and, in case MASTER is dead, will promote itself to MASTER and assign that additional virtual IP to its own interface.

Some configuration should be done before. After you install `keepalived` with APT module there won't be any configuration template provided, but in order to start, Keepalived needs non-empty `/etc/keepalived/keepalived.conf`.

Here is an example of `keepalived.conf` with some comments:

    vrrp_script check_haproxy {                 
        script "path-to-check-script" 
        weight 20                              
        interval 1               
    }
    vrrp_instance XXX {             
        interface ens3
        virtual_router_id XXX
        priority XXX
        advert_int 1                            
        virtual_ipaddress {                     
            192.168.100.XX/24                   
        }
        unicast_peer {                          
            192.168.42.XX
        }
        track_script {
            check_haproxy
        }
    }

Some comments to config example:

`vrrp_script` will add some weight to node priority if it was executed sucessfully. Put check script to `keepalived_script` user home folder. Script that will success in case port 88 is open and return 1 in case nothing listens on that port:

    #!/bin/bash
    ss -ntl | grep -q ':88 '

`virtual_router_id` should be the same on different VMs.

`priority` should be different of different VMs. Use if-else-endif statements in Jinja2 template.

`virtual_ipaddress` should be the same on different VMs.
If `your-name-1` VM has IP 192.168.42.35, virtual IP will be 192.168.100.35 (3rd octet changed from 42 to 100).
If `your-name-1` VM has IP 192.168.43.35, virtual IP will be 192.168.101.35 (3rd octet changed from 43 to 101).

`unicast_peer` should contain IP of another VM. Multicast is default message format for VRRP, but it doesn't work in most of public clouds, you should specify IPs of your other VMs here that VRRP can start use unicast messages. Use Ansible facts to get IPs.

If all done correctly, command `ip a` on VM with higher priority will show that there are 2 IPs on ens3 interface. No changes on VM with lower priority.

Hints:

After `service keepalived stop` on MASTER, BACKUP should become a MASTER and `ip a` will show that `192.168.10X.Y` was assigned to another VM.

If everything done correctly you should NOT see these logs on keepalived start:

    WARNING - default user 'keepalived_script' for script execution does not exist - please create.
    SECURITY VIOLATION - scripts are being executed but script_security not enabled.

If you see these log lines on keepalived restart - please take your time and fix the issue.

Add authentication to keepalived messsages to avoid any interaction with other students keepalived.

IPs are allowed in Keepalived configuration.

## Task 3. Install HAProxy

Can be installed with APT module as easy as Keepalived.

Clear installation will provide you config template in `/etc/haproxy/haproxy.cfg`.

Copy blocks `global` and `default` to your template.

Add section `frontend` and `backend` to template. Example of section:

    frontend my_ha_frontend
        bind :88
        default_backend my_ha_backend
    
    backend my_ha_backend
        server docker1 web-server1:8081 check
        server docker2 web-server2:7785 check

Port should be `88` because our NAT is configured to forward all requests to `192.168.100.X:88` and `192.168.101.X:88`.

88 is not the default HTTP port, but in our labs ports 80 and 8080 already have some services running, so we decided to use 88 to avoid any binding conflicts.

Usage of IPs is not allowed here.

If all done correctly, `Public HA URLs` of `your-name-1` should show you Agama app. Stopping HAProxy service on any VM should not affect Agama service reachability.

## Task 4. Add HAProxy monitoring

Install `prometheus-haproxy-exporter` using APT module. Add correct `haproxy.scrape-uri` to ARGS in `/etc/default/prometheus-haproxy-exporter`. Don't forget to expose HAProxy stats on that uri, find examples [here](https://www.haproxy.com/blog/the-four-essential-sections-of-an-haproxy-configuration/).

Use port 9188 to expose HAProxy stats. Do not expose stats to the internet!

## Task 5. Add Keepalived monitoring

There are a few Keepalived exporters available, we propose to use this one: https://github.com/mehdy/keepalived-exporter. Sometimes we get banned by GitHub, so you can download the file from our local backup server: http://backup/keepalived-exporter_1.4.0_linux_amd64.deb

Make sure service `prometheus-keepalived-exporter` is running. Exporter user should be `root` because Keepalived runs from `root`, Keepalived won't expose any stats to anyone else.

## Task 6. Grafana dashboard

Add new metrics to your main Grafana dashboard. Should be panels for each node with those metrics:
  
  - haproxy_up (last value)
  - haproxy_server_up (last value for each container)
  - keepalived_up (last value)
  - keepalived_vrrp_state (last value)

Hint:

If you don't see these metrics in Grafana drop-down, make sure you have added HAProxy and Keepalived exporters to Prometheus configuration.

Don't forget to update your Grafana provisioning files after dashboard changes.

## Expected result

Your repository contains these files:

    infra.yaml
    roles/haproxy/tasks/main.yaml
    roles/keepalived/tasks/main.yaml


Your Agama application is accessible on VM-1 public HA URL.
Even if almost all containers are down. Even if one HAproxy is stopped.
Even if one Keepalived is stopped.

Your Agama application is accessible on both public non-HA URLs.

Your Grafana and Prometheus are accessible on one public non-HA URLs.
