resource "openstack_networking_secgroup_v2" "bastion" {
  name                 = "sg-bastion-nawel-test"
  description          = "SSH public vers le Bastion uniquement"
  delete_default_rules = false
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ssh" {
  for_each = toset(var.allowed_admin_cidrs)

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_rule_v2" "bastion_icmp_private" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "192.168.100.0/24"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

# Reverse Proxy : le Bastion devient le point d'entrée HTTP/HTTPS public
# des applications hébergées sur les VMs privées (RP-NGINX).
resource "openstack_networking_secgroup_rule_v2" "bastion_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_rule_v2" "bastion_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_v2" "private_vms" {
  name                 = "sg-private-vms-via-bastion-test"
  description          = "SSH privé uniquement depuis le Bastion"
  delete_default_rules = false
}

resource "openstack_networking_secgroup_rule_v2" "vm_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.private_vms.id
}

resource "openstack_networking_secgroup_rule_v2" "vm_icmp_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.private_vms.id
}

# ============================================================
# Security Group - Projet Haythem
# bastion-nawel-test -> Bastion_TDP uniquement
# ============================================================

resource "openstack_networking_secgroup_v2" "haythem_from_central_bastion" {
  provider = openstack.haythem

  name                 = "sg-bastion-tdp-from-bastion-nawel"
  description          = "Autorise Bastion_TDP depuis bastion-nawel-test"
  delete_default_rules = false
}

resource "openstack_networking_secgroup_rule_v2" "haythem_ssh_from_central_bastion" {
  provider = openstack.haythem

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "192.168.100.111/32"
  security_group_id = openstack_networking_secgroup_v2.haythem_from_central_bastion.id
}

resource "openstack_networking_secgroup_rule_v2" "haythem_icmp_from_central_bastion" {
  provider = openstack.haythem

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "192.168.100.111/32"
  security_group_id = openstack_networking_secgroup_v2.haythem_from_central_bastion.id
}

/*
# ============================================================
# Security Group - Projet Hadil
# Bastion HA -> pfe-hadil
# ============================================================

resource "openstack_networking_secgroup_v2" "hadil_from_central_bastion" {
  provider = openstack.hadil

  name                 = "sg-hadil-from-bastion-nawel"
  description          = "Autorise pfe-hadil depuis les Bastions HA Nawel"
  delete_default_rules = false
}

# SSH depuis PRIMARY .111 et BACKUP .112
resource "openstack_networking_secgroup_rule_v2" "hadil_ssh_from_bastion" {
  provider = openstack.hadil

  for_each = toset([
    var.bastion_primary_ip,
    var.bastion_secondary_ip
  ])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${each.value}/32"
  security_group_id = openstack_networking_secgroup_v2.hadil_from_central_bastion.id
}

# ICMP pour les tests réseau
resource "openstack_networking_secgroup_rule_v2" "hadil_icmp_from_bastion" {
  provider = openstack.hadil

  for_each = toset([
    var.bastion_primary_ip,
    var.bastion_secondary_ip
  ])

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "${each.value}/32"
  security_group_id = openstack_networking_secgroup_v2.hadil_from_central_bastion.id
}
*/



# Keepalived utilise VRRP pour que les deux nœuds s'échangent des annonces de disponibilité.

# VRRP n'utilise ni TCP ni UDP. C'est directement le protocole IP numéro 112.

#Primary → Backup
resource "openstack_networking_secgroup_rule_v2" "bastion_vrrp_from_primary" {
  description       = "VRRP HA depuis le Bastion principal"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "112"
  remote_ip_prefix  = "${var.bastion_primary_ip}/32"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

#Backup → Primary

resource "openstack_networking_secgroup_rule_v2" "bastion_vrrp_from_secondary" {
  description       = "VRRP HA depuis le Bastion secondaire"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "112"
  remote_ip_prefix  = "${var.bastion_secondary_ip}/32"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}