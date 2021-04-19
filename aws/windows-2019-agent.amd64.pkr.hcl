packer {
  required_plugins {
    windows-update = {
      version = "0.12.0"
      source = "github.com/rgl/windows-update"
    }
  }
}

variable "openssh_public_key" {
  type    = string
  default = ""
}

variable "openssh_version" {
  type    = string
  default = "v8.1.0.0p1-Beta"
}

variable "location" {
  type    = string
}

variable "maven_version" {
  type    = string
}

variable "git_version" {
  type    = string
}

variable "jdk11_version" {
  type    = string
}

variable "jdk8_version" {
  type    = string
}

variable "git_lfs_version" {
  type    = string
}

data "amazon-ami" "autogenerated_1" {
  filters = {
    name                = "Windows_Server-2019-English-Core-ContainersLatest-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = "${var.location}"
}

locals {
  now_unix_timestamp = formatdate("YYYYMMDDhhmmss",timestamp())
}

source "amazon-ebs" "autogenerated_1" {
  ami_name      = "jenkins-agent-win2019-${local.now_unix_timestamp}"
  communicator  = "winrm"
  instance_type = "t2.micro"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp2"
  }
  region     = "${var.location}"
  source_ami = "${data.amazon-ami.autogenerated_1.id}"

  tags = {
    imageplatform = "amd64"
    imagetype     = "jenkins-agent-win2019"
    timestamp     = "${local.now_unix_timestamp}"
  }
  user_data_file = "./scripts/setupWinRM.ps1"
  winrm_insecure = true
  winrm_timeout  = "20m"
  winrm_use_ssl  = true
  winrm_username = "Administrator"
}

build {
  sources = ["source.amazon-ebs.autogenerated_1"]

  provisioner "windows-update" {
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    script = "./scripts/test-disk-size.ps1"
  }

  provisioner "powershell" {
    script = "./scripts/test-docker.ps1"
  }

  provisioner "powershell" {
    environment_vars = ["MAVEN_VERSION=${var.maven_version}", "GIT_VERSION=${var.git_version}", "JDK11_VERSION=${var.jdk11_version}", "JDK8_VERSION=${var.jdk8_version}", "GIT_LFS_VERSION=${var.git_lfs_version}", "OPENSSH_VERSION=${var.openssh_version}", "CLOUD_TYPE=aws", "OPENSSH_PUBLIC_KEY=${var.openssh_public_key}"]
    script           = "./scripts/windows-2019-provision.ps1"
  }

  provisioner "powershell" {
    inline = ["C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\InitializeInstance.ps1 -SchedulePerBoot", "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\SysprepInstance.ps1 -NoShutdown"]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
