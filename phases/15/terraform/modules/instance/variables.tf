variable "instance_name" { type = string }
variable "instance_zone" { type = string }
variable "instance_type" {
  type    = string
  default = "e2-micro"
}
variable "instance_network" { type = string }
variable "source_image" { type = string }
variable "labels" { type = map(string) }
