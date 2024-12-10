#!/bin/bash -ex

date > pre_exam.txt

exec > >(tee -ia pre_exam.txt) 2>&1

hostname

ansible-playbook infra.yaml --diff

ansible-playbook infra.yaml --diff

ansible all -b -m reboot -a "test_command=uptime"

sleep 15

ansible-playbook infra.yaml --diff

date
