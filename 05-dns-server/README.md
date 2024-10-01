# Lab 5

In this lab we will install our local DNS server. After this lab we won't use IP addresses for service communication in the internal network.

## Task 1: Get your startup name

As you might remember, in this course you play a role of Infrastructure Engineer in a small startup. Last week the first app was launched, now it's time to publish it!

For startup name creation you can use:
1. Your head
2. Use startup name generator [example](https://namelix.com/)
3. Use random string generator [like that](https://www.random.org/passwords) and just add -ly or -fy to the end

Create your domain name using some fancy root zone:
1. .io
2. .ttu
3. .{yourname}
4. .{anything}

Example of what you should get: *pythox.io* or *junglezilla.rk* (rk came from Roman Kuchin)

## Task 2: Install Bind9 on VM-2

Simply install "bind9" package and ensure that service is running even after VM restart.

## Task 3: Configure DNS forwarders

Check default /etc/bind/named.conf.options file to understand how to configure DNS forwarders.

*List* of DNS forwarders should come from variables.

Examples of public DNS forwarders:
 - 1.1.1.1
 - 8.8.8.8
 - 9.9.9.9

## Task 4: Configure access rules for DNS server

Allow queries to your DNS server only from our local network and localhost: 192.168.42.0/23 and 127.0.0.0/8.

That networks are subject to change, means that values should come from variables section.

Use Bind9 docs, they have good config examples on page 25. [Link](https://downloads.isc.org/isc/bind9/cur/9.18/doc/arm/Bv9ARM.pdf)

Default config file location: /etc/bind/named.conf.options

## Task 5: Configure master zone

Expected file location on DNS server: /var/cache/bind/db.{startup_name}

Structure of the file you can find in 05-demo or in /etc/bind/db.local on your vm.

Check Bind9 docs page 26 to learn how to reference primary(master) zone from config file.

Use variables to feed your master zone file:
    {{ hostvars[<vm_name>]['ansible_default_ipv4']['address'] }}
Where '<vm_name>' is your managed host name as defined in inventory file (for example, romankuchin-1).

You can get these variables values by running Ansible module "setup" without parameters. [Docs](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/setup_module.html)

Check what variables were collected with Ansible "debug" module. [Docs](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/debug_module.html)

Example of playbook:

	- name: Init
	  hosts: all  # Play runs on all hosts
	  roles:
        - init

	- name: DNS servers
	  hosts: dns_server  # Play runs only on DNS server
	  roles:
	    - bind

## Task 6: Update your VMs DNS settings

By default DNS settings in Ubuntu are managed by service called "systemd-resolved". If you want to manage DNS settings manually, you have to stop this service and make sure it won't start after VM restart.

List of DNS servers should be in /etc/resolv.conf.

Example of /etc/resolv.conf file:

    nameserver 192.168.42.117
    search pythox.io

Use variables to populate this files: {{ hostvars[<vm_with_bind9>]['ansible_default_ipv4']['address'] }} and {{ startup_name }}.

Make sure you that you have IPs of *working* DNS servers in /etc/resolv.conf at any given point of time.

## Task 7: Update AGAMA MySQL connection

Change IP address to VM name in `mysql_host` variable.

Since now it is not allowed to use IP addresses in configuration files unless explicitly specified.

## Hints:

Don't forget to restart service after config changes. Use Ansible "service" module for that.

Primary(master) zone file with DNS records is *not* a config file. After DB file update use command "rndc reload". You can use Ansible "command" module in a handler.

Use "named-checkconf" to check syntax of your Bind9 configs. Use "named-checkzone" to check syntax of your zone files.

Use online Jinja2 compiler to try your templates: https://j2live.ttl255.com/

## Expected result

Your repository contains these files and directories:

	ansible.cfg
	group_vars/all.yaml
	hosts
	infra.yaml
	roles/bind/tasks/main.yaml

Your repository also contains all the required files from the previous labs.

Your repository **does not contain** Ansible Vault master password.

DNS server is installed and configured on one of VMs and DNS settings on all VMs are set to use local DNS server with this command:

	ansible-playbook infra.yaml

Running the same command again does not make any changes to any of the managed hosts.

After playbook execution these commands should work from both your VMs (not from Ansible host):

    ping <your_github_username>-1.<your_startup_domain>
    ping <your_github_username>-2.<your_startup_domain>
    ping <your_github_username>-1
    ping <your_github_username>-2

AGAMA web application is available on
[your public URL](http://193.40.156.67/students.html) -- only on this host that you set up as a web
server, and not on the other one.
