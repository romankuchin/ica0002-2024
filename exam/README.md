This is the exam task for IT Instastructure Services 2024 course.

Intro
-----

Our application is ready to be released!

Today is the release day, link to Agama app was published in the Internet and
you start to serve your first happy customers. You monitor all your
insfastructure components and ready to react on any problems.

Of course everything that could go wrong -- goes wrong! Suddenly one of your DNS
instances just died without any reason. While you were checking the logs one
HAProxy crashed! And Docker containers with Agama app just start to disappear!

Luckily, you did a great job in the last few months to build fault-tolerant
infrastructure and happy customers didn't notice any problems with Agama app
during that time. Great job, you got many benefits and congratulations. But the
most important thing: now you can tell everyone that you sucessfully finished
"IT Infrastructure services" course in TalTech.

Sounds great?

There is one last step though -- put all the bits and pieces together to build
this infrastructure one last time.


Infrastructure
--------------

You will have 3 virtual machines to use: use "-1" and "-2" for the
main application stack, "-3" for internal services.

Each application stack machine should have these services set up and running:
 - Agama in the Docker containers
 - HAProxy
 - Keepalived
 - MySQL (master on "-1" machine, replica on "-2")
 - Secondary Bind
 - Prometheus exporters

Remaining machine should have these services set up and running:
 - Primary Bind
 - InfluxDB
 - Telegraf
 - Agama-client
 - Prometheus
 - Grafana
 - Nginx as frontend for Grafana and Prometheus


Differences with previous tasks
-------------------------------

We tried to make this infrastructure as similar as possible to what you did
during the course, however there are a few differences worth pointing out.

There is one primary Bind and _two_ secondary Binds now; don't add primary
address to `/etc/resolv.conf` -- only both secondary addresses. For example, in this
setup:

	192.168.42.35   # Bind secondary
	192.168.42.87   # Bind secondary
	192.168.42.124  # Bind primary

`/etc/resolv.conf` could look like this:

	nameserver 192.168.42.35
	nameserver 192.168.42.87
	search mydomain.tld

Put _all_ your Nginx configuration to single file: `sites-enabled/default`. There should not be any other files in that folder.

Also, as there are three machines now, so your Grafana dashboards, backup
scripts and documentation should reflect and support it.


Task
----

Read exam requirements [here](./meta.md).

Update your Ansible playbook named `infra.yaml` to deploy the infrastructure
described above.

Provide the backup SLA document (`backup_sla.md`)
and backup restore instructions for every service that is being backed up
(`backup_restore.md`).


Requirements
------------

1. After the infrastructure is deployed, running `ansible-playbook infra.yaml`
   command again should not produce any changes on the managed hosts
2. Every variable should be defined exactly once -- in `hosts`,
   `group_vars/all.yaml` or some other file if you feel needed. If value can be retrieved from Ansible facts, it should be taken from there
3. No active plain text passwords should be found anywhere in your repository
   (including history); note that it's okay to have old passwords in the code
   -- but only if you changed them already
4. No IP addresses should be used in configurations, except Bind and Keepalived
   configuration and `/etc/resolv.conf`. Should you address local machine, use
   `localhost` -- not `127.0.0.1`!
5. Your microphone and screen sharing should work in Discord calls


Presenting your solution
------------------------

If you have run the Ansible command mentioned above, and it did not trigger any
changes, you are ready to present your solution.

[Here](./meta.md#Testing) you can find more details on how we will test your
submission.

**But make sure to test it yourself first!**


Good luck!
----------

![](./unicorn.jpeg)
