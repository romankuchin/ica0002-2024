Exam related information
------------------------

Exam task: [README.md](./README.md)


Access
------

Exam times are listed on the [main course page](../README.md).

You can choose any 2 times to take the exam in addition to week 16 exam attempt,
3 attempts in total.

To get access to the exam you need to:

1. Complete all the 14 lab tasks
2. Get your solution verified by Judge Dredd:
    http://193.40.156.67/students.html > your-name > Results should be all green

Once done, you will soon get a third virtual machine to prepare and test your
solution.


Rules
-----

Exam starts strictly at the announced time and lasts for exactly
**3 hours and 15 minutes** (195 minutes) -- not a minute longer.

Submissions are checked on first-come-first-served basis using screen sharing.

This is open-everything exam: you can use whatever materials you want while
writing the code, testing it or presenting.


Pre-testing
-----------

Before taking the exam you should verify your solution yourself.

Run script `pre-exam.sh` when you have *empty VMs*. It will create a file `pre_exam.txt` -- commit it to `main` branch. Just a reminder: commiting your passwords is a bad idea. If playbook execution failed -- fix your code, recreate VMs and try again. Do not run `pre-exam.sh` on non-empty VMs.

Expected result:

- Many changes on 1st run
- Zero changes on 2nd run
- Zero changes on 3rd run

If you have something different -- fix your code. No point to take the exam until you have achieved the
expected result. Note that we will still check your code during the exam.

To run the script, put it next to `infra.yaml`, make it executable and type `./pre-exam.sh`.


Testing
-------

This is what we (teachers) may do to test your infrastructure.


**1. Kill any of the services mentioned above**

You should be able to restore the infrastructure in exactly one Ansible run.

Note: to _restore_ the services with Ansible here and in other cases you *must* use Ansible tags. Running the whole playbook to change one file is not allowed.


**2. Kill one of the highly available service instances**

Agama in Docker container, Bind (primary or secondary), Docker daemon, HAProxy,
Keepalived, MySQL replica.

The application should remain accessible for the clients, i.e. public URL of
Agama should remain working as nothing happened.

Your monitoring should be able to detect which component is down.

You should be able to restore the infrastructure in exactly one Ansible run.


**3. Kill one of the services and break its configuration file**

We will only break the files that are (or expected to be) managed with Ansible.

You should be able to restore the infrastructure in exactly one Ansible run.


**4. Break one of your services and ask you to find the problem**

We may tell you which service is broken, or you may need to identify that
yourself -- your monitoring (Grafana) will be helpful here.

We will only produce the damage that can be easily detected with commands
explained on the "Troubleshooting" lecture and lab, by checking
 - service status
 - service configuration syntax
 - service logs
 - ability to communicate with other services

For example, we may:
 - Make a typo in the HAProxy configuration
 - Change Bind configuration so that name resolution does not work
 - Change MySQL user, password, port
 - Stop Prometheus
 - etc.

You should be able to find the problem and explain what is broken and, ideally,
how to fix it.


**5. Reboot any of your VMs**

After the machine is started all your services there should be started
automatically **without any Ansible runs**, and of course without any manual
intervention.


**6. Ask you to change some configuration value**

Username, password, port, file permissions, etc. for any of the service mentioned
above.

This change should be then fully applied in a single Ansible run.

> We will not ask you to make changes that silently break your infrastructure.
> If we do ask a breaking change -- we'll make it openly.


**7. Stop one of your services and restore it from the backup**

We will only use the instructions from your `backup_restore.md` document.

Note that _we_ will restore the service, not you.


**8. Ask you questions about your infrastructure**

A few examples:

 - How to check if the service X is working (multiple ways)?
 - What files does service X work with? Where are configuration files, where is
   working directory etc.
 - What other services does service X communicate to?
 - What services will be affected and how if machine A is turned off?
 - How do you back up your infrastructure (coverage, retention, versioning,
   usability, RPO/RTO etc.)?
 - When was the last backup for service X created?

And other questions of similar complexity and detail level: we won't ask you to
disassemble the binary files -- but you should have a basic understanding of how
the deployed services work.

Expected answer is usually one-two sentences.


**9. Ask you questions about your code**

Be ready to explain every line of your code.

You don't need to learn the documentation by heart precisely. You can always
check it any time -- it's an open-everything exam. We well accept cited online
references as answers -- if they answer the question, of course.
