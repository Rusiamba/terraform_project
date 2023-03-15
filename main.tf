terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "C:/Users/Ruslan/Desktop/myTerraform/key.json"
  cloud_id = "b1g3pahc0knui3j2hgus"
  folder_id = "b1gruuo73ondr1kpq56n"
  zone = "ru-central1-a"
}
#Образ LEMP
data "yandex_compute_image" "my_image" {
  family = "lemp"
}
#Network
resource "yandex_vpc_network" "labnet" {
  name = "lab-network"
}
#Подсети для инстансов
resource "yandex_vpc_subnet" "lab-subnet-a" {
  name = "lab-subnet-a"
  v4_cidr_blocks = ["192.168.10.0/24"]
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.labnet.id}"
}

resource "yandex_vpc_subnet" "lab-subnet-b" {
  name = "lab-subnet-b"
  v4_cidr_blocks = ["192.168.11.0/24"]
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.labnet.id}"
}
#Сервер Nginx
resource "yandex_compute_instance" "test" {
  name = "testmachine"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab-subnet-a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
#Сервер Apache
resource "yandex_compute_instance" "apache" {
  name = "apache"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd83hhoi03ga5bsau95m"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.lab-subnet-b.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_lb_target_group" "target" {
  name = "my-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = "${yandex_vpc_subnet.lab-subnet-a.id}"
    address = "${yandex_compute_instance.test.network_interface.0.ip_address}"
  }

  target {
    subnet_id = "${yandex_vpc_subnet.lab-subnet-b.id}"
    address = "${yandex_compute_instance.apache.network_interface.0.ip_address}"
  }
  
}
#Балансировщик сети
resource "yandex_lb_network_load_balancer" "internallb_test" {
  name = "internallbtest"
  type = "internal"

  listener {
    name = "my-listener"
    port = 80
    internal_address_spec {
      subnet_id = "e9b1l57mp13cpl8nb89b"
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.target.id}"
    healthcheck {
      name =   "http"
      http_options {
        port =   80
      }
    }  
  }
}
#Выводы в консоль
output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.test.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.test.network_interface.0.nat_ip_address
}

output "internal_ip_address_apache" {
  value = yandex_compute_instance.apache.network_interface.0.ip_address
}

output "external_ip_address_apache" {
  value = yandex_compute_instance.apache.network_interface.0.nat_ip_address
}