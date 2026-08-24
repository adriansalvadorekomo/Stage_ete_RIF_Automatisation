# ============================================================
# Bastion HA - Secondary
# ============================================================
#
# Phase 1 :
# - création du keypair HA ;
# - création du port Neutron du Bastion secondaire ;
# - création de la VM Bastion secondaire.
#
# La VIP / Keepalived / Floating IP seront configurés
# dans les phases suivantes.
# ============================================================


# ============================================================
# Keypair SSH HA
# ============================================================

resource "openstack_compute_keypair_v2" "bastion_ha" {
  provider = openstack.bastion_ha

  name       = var.bastion_secondary_keypair_name
  public_key = var.bastion_ha_public_key
}


# ============================================================
# Port Neutron du Bastion secondaire
# ============================================================

resource "openstack_networking_port_v2" "bastion_secondary" {
  provider = openstack.bastion_ha

  name           = "${var.bastion_secondary_name}-port"
  network_id     = data.openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    data.openstack_networking_secgroup_v2.bastion_ha.id
  ]

  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.private.id
    ip_address = var.bastion_secondary_ip
  }


  # VIP HA autorisée sur le Bastion secondaire
  allowed_address_pairs {
    ip_address = var.bastion_vip
  }

  lifecycle {
    prevent_destroy = true
  }
}


# ============================================================
# VM Bastion secondaire
# ============================================================

resource "openstack_compute_instance_v2" "bastion_secondary" {
  provider = openstack.bastion_ha

  name              = var.bastion_secondary_name
  image_id          = data.openstack_images_image_v2.ubuntu.id
  flavor_id         = data.openstack_compute_flavor_v2.bastion.id
  availability_zone = "pfe-zone"
  key_pair          = openstack_compute_keypair_v2.bastion_ha.name

  network {
    port = openstack_networking_port_v2.bastion_secondary.id
  }


  lifecycle {
    prevent_destroy = true
  }
}