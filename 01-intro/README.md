# Lab 1

## Git Intro

You will keep all the code (and more) written during this course in a Git
repository.

Teachers will check your work in your Git repo -- not in your text editor.
Having all the tasks completed with results pushed to your Git repository is a
requirement to access the exam.

GitHub is a well-known and widely used (but not the only one) service to host
Git repositories. We'll use GitHub for this course as a collaboration platform.

If you feel some lack of experience with Git and GitHub we recommend to read
[this tutorial](https://guides.github.com/introduction/git-handbook).
It's also ok to use GUI version if you prefer: [GitHub Desktop](https://desktop.github.com/)


## Ansible Intro

We will use Ansible in this course as a configuration management tool. There are
dozens of configuration management tools out there but we've chosen Ansible as
one of the simplest one to get started with.

You can run Ansible from your laptop directly in case you have Linux or MacOS. 
In case you have Windows, you can run Ansible in WSL.


## Task 1: Set up your Git repository

If you have a GitHub account already, skip this step. Otherwise
[create a new GitHub account](https://github.com/join). The most basic free
account is more than enough -- you won't need any premium GitHub features for
this course.

[Create a GitHub repository](https://github.com/new) named `ica0002`. Choose "Add a README file". Note: this repository should be **private**!

Add our course bot as a collaborator to your repository. This is needed for the
teachers to provision virtual machines for you to practice, and check your task
submissions. Go to your new repository settings, select `Collaborators` in the
left menu, click `Add people` and add user `ica0002-bot` (here is its
GitHub profile: [https://github.com/ica0002-bot](https://github.com/ica0002-bot)).

Once you have completed all the steps above your repository should appear in
[this list](http://193.40.156.67/students.html) automatically after some time (up to 30m).
If it does not, please ask the teachers for help.

Note: You don't have to wait until your repository is added to this list, you
can continue with the next task.


## Task 2: Set up SSH keys

**(on a Control node -- same machine you'll be running Ansible from)**

If you have an SSH keypair already you can reuse it for this course. You can
check for existing SSH keys on your machine by running

    ls -la ~/.ssh

If there are files named `id_rsa` and `id_rsa.pub` you're probably good to go
already. If not, generate a new keypair by running `ssh-keygen`.

Your **public** SSH key can be found in `~/.ssh/id_rsa.pub` file. Add this key
(entire file content) to your GitHub account:
 - In GitHub web UI click your profile icon in the top right corner
 - Select `Settings`
 - Select `SSH and GPG keys` in the left menu
 - Click `New SSH key`
 - Paste the content of `~/.ssh/id_rsa.pub` file to the `Key` field
 - click `Add SSH key`

Once you have added your public key to your GitHub account our bot should detect
it automatically within 2..3 minutes. You can see the result
[here](http://193.40.156.67/students.html).

Note: You don't have to wait until your key is added to this list, you can
continue with the next task.


## Task 3: Install Ansible

**(on a Control node -- same machine where your SSH keys reside)**

Note: we will use Ansible version 10.1.0 (ansible-core 2.17.1) for this course.
Teachers will have this version installed and use it to check your tasks.
Your code is considered working only if it executes successfully on Ansible 10.1.0.
If you're using other Ansible versions -- you're on your own with them.

Note: you will need Python v3.10 or newer to use this version of Ansible.

For Linux or OS X, we recommend to use Python virtual env:

    python3 -m venv ~/ansible-venv
    ~/ansible-venv/bin/pip install ansible==10.1.0
    ~/ansible-venv/bin/ansible-community --version
    ~/ansible-venv/bin/ansible --version

Last command should print something like (minor version might be different):

    ansible [core 2.17.1]

Then, add this line to your `~/.profile` file (if the file is missing, create it)
so you can use 'shorter' commands:

    PATH="$HOME/ansible-venv/bin:$PATH"

Logout and log in again. Now this command should also work:

    ansible --version


## Task 4: Test access to your virtual machine

First, make sure that your Git repository is set up correctly -- check
[this list](http://193.40.156.67/students.html) for details.

Then, make sure that your virtual machine is set up -- click your name here and find the
SSH access details on your page. Note the SSH port number!

Finally, test that SSH access works -- run this command on the **control node**
(replace the `122` with the port number from the list above):

    ssh -p122 ubuntu@193.40.156.67 uptime

The command above should print the virtual machine uptime (a few minutes, maybe
hours). This means that you can access your virtual machine via SSH.

If you cannot access the virtual machine or it's stuck in 'Creating' state,
please ask the teachers for help.


## Task 5: Clone your Git repository

**(on a Control node -- same machine you'll be running Ansible from)**

    git clone git@github.com:<your_github_username>/ica0002


## Task 6: Create Ansible playbook

**(on a Control node -- same machine you'll be running Ansible from)**

Example of first playbook you can find [here](01-demo).

Step 1: Move to cloned directory named `ica0002`.

Step 2: In that directory, create files named `ansible.cfg`, `hosts`,
`roles/init/tasks/main.yaml` and `infra.yaml` -- you can just copy
the contents of `01-demo` directory from the link above.

Note: directory structure and file names matter! Create the files and
directories named exactly as requested.

Step 3: Update your inventory file named `hosts` -- check your own page from
http://193.40.156.67/students.html to find the correct connection parameters.

Step 4: Run the Ansible playbook:

    ansible-playbook infra.yaml

You should see only green "ok" messages.


## Task 7: Commit and your work to GitHub

Once all the previous tasks are done make sure the files you've created in the
Task 6 are pushed to GitHub.

Run these commands to commit your changes:

    git add .
    git commit -m 'Lab 1'


Finally, run this command to push your changes to GitHub:

    git push

Once done, the following files should appear in the root of your GitHub
repository:
 - `ansible.cfg`
 - `hosts`
 - `infra.yaml`
 - `roles/init/tasks/main.yaml`
