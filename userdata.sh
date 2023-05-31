#!/bin/bash

labauto ansible
ansible-pull -i localhost, -U https://github.com/KoulteghDevOps/Ansible-Roboshop-Project.git roboshop.yml -e role_name=${name} -e env=${env} &>>/opt/ansible.log
