data "openstack_networking_network_v2" "private" {
  name = var.private_network_name
}

data "openstack_networking_subnet_v2" "private" {
  name = var.private_subnet_name
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.bastion_image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "bastion" {
  name = var.bastion_flavor_name
}


# ============================================================
# Security Group existant du Bastion HA
# ============================================================

data "openstack_networking_secgroup_v2" "bastion_ha" {
  provider = openstack.bastion_ha
  name     = "sg-bastion-nawel-test"
}