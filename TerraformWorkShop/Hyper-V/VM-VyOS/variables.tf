variable "hyperv_host" {
  type    = string
  default = "127.0.0.1"
}

variable "hyperv_port" {
  type    = string
  default = 5985
}

variable "hyperv_user" {
  type    = string
  default = null
}

variable "hyperv_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "vm_name" {
  type    = string
  default = null
}

variable "vhd_dir" {
  type    = string
  default = "C:\\ProgramData\\Microsoft\\Windows\\Virtual Hard Disks"
}

variable "source_disk" {
  type    = string
  default = null
}

variable "data_disk_ref" {
  type    = string
  default = "null"
}

variable "network_adaptors" {
  type = list(object({
    name        = string
    switch_name = string
  }))
}

variable "enable_secure_boot" {
  type    = string
  default = "Off"
}

variable "memory_startup_bytes" {
  type    = number
  default = 1023410176
}

variable "memory_maximum_bytes" {
  type    = number
  default = 2147483648
}

variable "memory_minimum_bytes" {
  type    = number
  default = 1023410176
}


