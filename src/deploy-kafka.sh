#!/bin/bash

echo "Welcome to the Kafka Installer!"

echo "\nStarting Terraform phase...\n"

cd terraform

terraform apply

if [ $? -ne 0 ]
then
  echo "\033[31mTerraform error...\033[0m"
  exit 1
fi

SSH_USER=$(terraform output -json ssh-user | tr -d '"')

rm ../ansible/roles/kafka/files/zookeeper/zookeeper.properties
cp ../ansible/roles/kafka/files/zookeeper/zookeeper.properties.sample ../ansible/roles/kafka/files/zookeeper/zookeeper.properties

> ../ansible/inventory.ini
COUNT=1

# Kafka server properties zookeeper
rm ../ansible/roles/kafka/files/kafka/server.properties
cp ../ansible/roles/kafka/files/kafka/server.properties.sample ../ansible/roles/kafka/files/kafka/server.properties
/bin/echo -n "zookeeper.connect=" >> ../ansible/roles/kafka/files/kafka/server.properties

terraform output -json kafka-ips | jq '.[]' | tr -d '"' | while read ip
do
  echo "kafka_main_$COUNT brokerId=$COUNT ansible_ssh_user=$SSH_USER-$COUNT ansible_ssh_host=$ip ansible_ssh_port=22 ansible_ssh_args='-o ControlMaster=auto -o ControlPersist=60s'" >> ../ansible/inventory.ini
  echo "server.$COUNT=zookeeper$COUNT:2888:3888" >> ../ansible/roles/kafka/files/zookeeper/zookeeper.properties

  # Kafka server properties
  if [ $COUNT -eq 1 ]
  then
    /bin/echo -n "zookeeper$COUNT:2181," >> ../ansible/roles/kafka/files/kafka/server.properties
  else
    /bin/echo -n "zookeeper$COUNT:2181" >> ../ansible/roles/kafka/files/kafka/server.properties
  fi

  COUNT=$[$COUNT + 1]
done

/bin/echo -n "/kafka" >> ../ansible/roles/kafka/files/kafka/server.properties

> ../ansible/roles/kafka/files/hosts
COUNT=1
terraform output -json kafka-private-ips | jq '.[]' | tr -d '"' | while read ip_private
do
  echo "$ip_private kafka$COUNT
$ip_private zookeeper$COUNT" >> ../ansible/roles/kafka/files/hosts
  COUNT=$[$COUNT + 1]
done

echo "\nAnsible inventory.ini generated"

echo "\nWaiting 30 while instances are being created..."
sleep 30

echo "\nStarting Ansible phase..."

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ../ansible/kafka.yml -i ../ansible/inventory.ini --key-file ../keys/kafka_brokers

echo "\nInstallation finished :)"
