output "bastion_private_ip" {
  description = "Adresse IP privée du Bastion"
  value       = openstack_networking_port_v2.bastion.all_fixed_ips[0]
}

output "bastion_floating_ip" {
  description = "Floating IP associée au Bastion"
  value       = var.bastion_floating_ip
}

output "ssh_bastion" {
  description = "Commande SSH pour accéder au Bastion"
  value       = "ssh ubuntu@${var.bastion_floating_ip}"
}

output "ssh_lms_openedx" {
  description = "Commande SSH vers LMS-OpenedX via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.55"
}

output "ssh_odoo_server" {
  description = "Commande SSH vers Odoo Server via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.91"
}

output "ssh_full_stack_js" {
  description = "Commande SSH vers Full-Stack-JS via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.87"
}

output "ssh_java_js" {
  description = "Commande SSH vers Java-JS via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.149"
}
# ============================================================
# Accès SSH - Projet Haythem
# ============================================================

output "ssh_haythem_bastion_tdp" {
  description = "SSH vers Bastion_TDP via bastion-nawel-test"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.40"
}


# ============================================================
# Bastion HA
# ============================================================

output "bastion_secondary_private_ip" {
  description = "Adresse IP privée du Bastion secondaire"
  value       = openstack_networking_port_v2.bastion_secondary.all_fixed_ips[0]
}

output "bastion_ha_vip" {
  description = "Future VIP privée du cluster Bastion HA"
  value       = var.bastion_vip
}

output "bastion_ha_keypair_name" {
  description = "Nom du keypair SSH créé pour le Bastion secondaire"
  value       = openstack_compute_keypair_v2.bastion_ha.name
}

output "ssh_bastion_secondary_via_primary" {
  description = "Connexion SSH vers le Bastion secondaire via le Bastion principal"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@${var.bastion_secondary_ip}"
}