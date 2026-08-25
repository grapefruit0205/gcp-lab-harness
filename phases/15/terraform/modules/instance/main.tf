resource "google_compute_instance" "vm" {
  name         = var.instance_name
  zone         = var.instance_zone
  machine_type = var.instance_type
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = var.source_image
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.instance_network
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
}

output "name" { value = google_compute_instance.vm.name }
output "internal_ip" { value = google_compute_instance.vm.network_interface[0].network_ip }
