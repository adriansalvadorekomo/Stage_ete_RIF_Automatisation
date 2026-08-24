variable "os_username" {
  description = "Nom d'utilisateur OpenStack"
  type        = string
}

variable "os_password" {
  description = "Mot de passe OpenStack"
  type        = string
  sensitive   = true
}

variable "os_project_name" {
  description = "Nom du projet OpenStack"
  type        = string
}

variable "private_network_name" {
  type    = string
  default = "reseau-stagiaires"
}

variable "private_subnet_name" {
  type    = string
  default = "subnet-stagiaires"
}

variable "external_network_name" {
  type    = string
  default = "public"
}

variable "floating_ip_subnet_id" {
  description = "ID du subnet public autorisé pour le Bastion"
  type        = string
}

variable "bastion_name" {
  type    = string
  default = "bastion-nawel-test"
}

variable "bastion_image_name" {
  type    = string
  default = "Ubuntu-22.04"
}

variable "bastion_flavor_name" {
  type    = string
  default = "m1.small-custom"
}

variable "existing_keypair_name" {
  type    = string
  default = "Full_Stack_JS_key"
}

variable "admin_ssh_keys" {
  description = "Clés SSH publiques autorisées sur le Bastion"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "allowed_admin_cidrs" {
  description = "CIDR autorisés à joindre le Bastion en SSH"
  type        = list(string)
}

variable "existing_vm_ports" {
  description = "Ports Neutron des VMs utilisées pour le test Bastion"
  type        = map(string)
}

variable "bastion_floating_ip" {
  description = "Floating IP existante à associer au Bastion"
  type        = string
}




variable "haythem_project_name" {
  description = "Nom du projet OpenStack de Haythem"
  type        = string
  default     = "Stage_TDP_Haythem"
}

variable "haythem_project_id" {
  description = "ID du projet OpenStack de Haythem"
  type        = string
  default     = "96920551255d4a0cadadc90b7aa84380"
}

variable "haythem_bastion_port" {
  description = "Port Neutron de Bastion_TDP"
  type        = string
}


# ============================================================
# Bastion HA - Secondary / Backup
# ============================================================

variable "bastion_secondary_name" {
  description = "Nom du Bastion secondaire HA"
  type        = string
  default     = "bastion-nawel-backup"
}

variable "bastion_secondary_ip" {
  description = "Adresse IP privée fixe du Bastion secondaire"
  type        = string
}

variable "bastion_vip" {
  description = "VIP privée utilisée ultérieurement par Keepalived"
  type        = string
}

# ============================================================
# Projet OpenStack du cluster Bastion HA
# ============================================================

variable "bastion_project_name" {
  description = "Nom du projet OpenStack contenant les Bastions HA"
  type        = string
  default     = "stagiaires-ete-2026"
}

variable "bastion_project_id" {
  description = "ID du projet OpenStack contenant les Bastions HA"
  type        = string
  default     = "e553cc57c1a545e78542028045d7ed63"
}

# ============================================================
# SSH / Keypair du Bastion HA
# ============================================================

variable "bastion_secondary_keypair_name" {
  description = "Nom du keypair OpenStack créé pour le Bastion secondaire"
  type        = string
  default     = "bastion-ha-key"
}

variable "bastion_ha_public_key" {
  description = "Clé publique SSH importée dans le keypair du Bastion HA"
  type        = string
  sensitive   = true
}

variable "bastion_primary_ip" {
  description = "IP privée du Bastion principal"
  type        = string
  default     = "192.168.100.111"
}