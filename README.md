# Kafka Infrastructure Tools

Tested with Kafka 2.4.0

## Requirements

- terraform cli
- ansible cli (brew install ansible)
- jq

## How it works

In this repository we have all the tools to deploy an operative **Kafka Cluster in 5 minutes**.

To do this **Terraform and Ansible** are used. The first one is to automatize the infrastructure build. And the second one is to automatize the provisioning of the machines.

To make it easy and to join Terraform output and Ansible input, use the script **`deploy-kafka.sh`**.

Before executing it you have to **choose** how many **brokers** you want, you can change this parameter in the **variable broker_num allocated in /terraform/vm.tf**

You can **change some configurations** for **Kafka and Zookeeper** in **ansible/roles/kafka/files** but take into account that some of these are being overwritten when you execute the script. If there is a **.sample** file, modify it and no the default file.

To specify the Kafka version you need to download the Kafka Bynary .tgz release from https://kafka.apache.org/downloads and put in `src/ansible/roles/kafka/files`. Then change the Kafka version in `src/ansible/roles/kafka/tasks/3-configs.yml`.

Generate a Public Key to allow the script create SSH Private Keys for the Kafka Brokers in `src/keys/kafka_brokers.pub`

Specify your domain in `src/ansible/roles/kafka/tasks/6-kafka.yml` "Add broker specific configs" section.

Create a file with your Service Account Key in `src/terraform/terraform-key.json`

Then you can do **`sh deploy-kafka.sh`** and all will be done.

## In-depth

The first step is to **run Terraform** and it creates these things for every broker:

- Public Static IP
- ssd 10GB disk
- GCP Instance with Debian 10 with a pd-standard 10GB disk attached

**Terraform output** 3 things:

- kafka-ips (Public IPs)
- kafka-private-ips (Private IPs)
- ssh-user (SSH GCP Instance user)

**The script** continues the execution after Terraform and creates **this files**:

- **ansible/inventory.ini**
  With these outputs the `deploy-kafka.sh` script build the file. This file is used by Ansible to know hoy to connect by ssh to the hosts.
- **ansible/roles/kafka/files/zookeeper/zookeeper.properties**
  Zookeeper properties with every host
- **ansible/roles/kafka/files/kafka/server.properties**
  Kafka properties with every Zookeeper hosts
- **ansible/roles/kafka/files/hosts**
  hosts file with the private IPs that then will be added to the Linux machine /etc/hosts

After building these files the script executes the **Ansible** command with **ansible/inventory.ini** configuration and connects to every broker to make these things:

- **Install packages** like Java 11 JDK and more
- **Format and mount** the ssd volume
- Update /etc/hosts and copy **Kafka binaries**
- Configure **jmx_prometheus_javaagent** for Kafka and Zookeeper
- Configure **Zookeeper** and install service for it
- Configure **Kafka** and install service for it
- **Start** Zookeeper and Kafka

## Connect to the brokers

Every broker has the same username with a number depending of the broker number 'xxxxxxxx-1', 'xxxxxxxx-2', 'xxxxxxxx-3'...

The **SSH private key** is the same for all brokers.

## Destroy infrastructure

In the **terraform folder** run the command **`terraform destroy`**
