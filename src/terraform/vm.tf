provider "google" {
  credentials = file("terraform-key.json")
  project     = "kafka"
  region      = "europe-west1"
  zone        = "europe-west1-b"
  version     = "~> 2.18.1"
}

variable "broker_num" {
  type    = number
  default = 3
}

variable "availability_zone_names" {
  type    = list(string)
  default = ["europe-west1-d", "europe-west1-b", "europe-west1-c", "europe-west1-d", "europe-west1-b", "europe-west1-c", "europe-west1-d", "europe-west1-b", "europe-west1-c", "europe-west1-d", "europe-west1-b", "europe-west1-c"]
}

variable "gce_ssh_user" {
  type    = string
  default = "kafka-siduhsaidu87348"
}

variable "gce_ssh_pub_key_file" {
  type    = string
  default = "../keys/kafka_brokers.pub"
}

resource "google_compute_address" "static" {
  count = var.broker_num

  name = "kafka-broker-ip-${count.index + 1}"

  lifecycle {
    prevent_destroy = false
  }

  /*labels = {
    name         = "kafka-broker-ip-${count.index + 1}"
    kafka-broker = "${count.index + 1}"
  }*/
}

resource "google_compute_disk" "default" {
  count = var.broker_num

  name = "kafka-broker-${count.index + 1}-data"
  type = "pd-ssd"
  zone = var.availability_zone_names["${count.index}"]

  size = 100
  labels = {
    name         = "broker-${count.index + 1}-data"
    kafka-broker = "${count.index + 1}"
  }
  lifecycle {
    prevent_destroy = false
  }
}
resource "google_compute_instance" "default" {
  count = var.broker_num

  name         = "kafka-broker-${count.index + 1}"
  hostname     = "kafka-broker-${count.index + 1}.kafka"
  machine_type = "n1-standard-2"
  zone         = var.availability_zone_names["${count.index}"]

  tags = ["kafka-broker", "kafka-broker-${count.index + 1}"]

  labels = {
    name         = "kafka-broker-${count.index + 1}"
    kafka-broker = "${count.index + 1}"
  }

  boot_disk {
    device_name = "kafka-broker-${count.index + 1}"
    initialize_params {
      image = "debian-cloud/debian-10"
      type  = "pd-standard"
      size  = 10
    }
  }

  attached_disk {
    source      = "kafka-broker-${count.index + 1}-data"
    device_name = "kafka-broker-${count.index + 1}-data"
  }

  network_interface {
    network    = "kafka-network"
    subnetwork = "kafka-subnet"
    access_config {
      nat_ip = google_compute_address.static["${count.index}"].address
    }
  }

  metadata = {
    ssh-keys = "${var.gce_ssh_user}-${count.index + 1}:${file(var.gce_ssh_pub_key_file)}"
  }

  lifecycle {
    prevent_destroy = false
  }
}

output "kafka-ips" {
  value = {
    for address in google_compute_address.static :
    address.name => address.address
  }
  description = "Kafka IPs"
}

output "kafka-private-ips" {
  value = {
    for instance in google_compute_instance.default :
    instance.id => instance.network_interface[0].network_ip
  }
  description = "Kafka Private IPs"
}

output "ssh-user" {
  value       = var.gce_ssh_user
  description = "SSH User"
}
