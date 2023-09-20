packer {
  required_plugins {
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = "~> 1"
    }
  }
}

variable "version" {
  type    = string
  default = ""
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "vagrant" "autogenerated_1" {
  add_force    = true
  communicator = "ssh"
  provider     = "virtualbox"
  source_path  = "ubuntu/focal64"

}

build {
  sources = ["source.vagrant.autogenerated_1"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    script = "scripts/setup.sh"
  }
}
