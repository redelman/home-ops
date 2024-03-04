# User permissions
data "cloudflare_api_token_permission_groups" "all" {}

resource time_static "time_now" {
}

resource "time_rotating" "cloudflare_api_token_validity_period" {
  rotation_days = 90
}

# Token allowed to edit DNS entries for all zones from specific account.
resource "cloudflare_api_token" "vyos_dynamic_dns_token" {
  name = "vyos_dynamic_dns_token"

  # include all zones from specific account
  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
    ]

    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }

  not_before = "${time_rotating.cloudflare_api_token_validity_period.rfc3339}"
  expires_on = "${time_rotating.cloudflare_api_token_validity_period.rotation_rfc3339}"

  lifecycle {
    prevent_destroy = true
  }
}

output "vyos_dynamic_dns_token" {
  value = "${cloudflare_api_token.vyos_dynamic_dns_token}"
  sensitive = true
}

# A record for spyrja.io apex
# Probably will be deleted once k8s and external-dns are available
# Record is created by OpenTofu but the value is managed dynamically
# by ddclient on VyOS.
resource "cloudflare_record" "apex_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "A"
  value = "1.2.3.4"
  ttl     = 1
  proxied = true

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

# A record for spyrja.io gaming services
# Cannot be proxied.
# Record is created by OpenTofu but the value is managed dynamically
# by ddclient on VyOS.
resource "cloudflare_record" "gaming_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "gaming"
  type    = "A"
  value   = "1.2.3.4"
  ttl     = 300

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

# Sometimes we might want to use a game specific FQDN for gaming
# No idea why, but we'll support it for now, but just via a
# wildcard entry
resource "cloudflare_record" "wc_gaming_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "*.gaming"
  type    = "CNAME"
  value   = "gaming.spyrja.io"
  ttl     = 300

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

# Quick and dirty CAA record to support Let's Encrypt certs
resource "cloudflare_record" "caa_0_nonwild_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "CAA"
  data  {
    flags = "0"
    tag   = "issue"
    value = "letsencrypt.org;validationmethods=dns-01"
  }
  ttl     = 300

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

resource "cloudflare_record" "caa_0_wild_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "CAA"
  data  {
    flags = "0"
    tag   = "issuewild"
    value = "letsencrypt.org;validationmethods=dns-01"
  }
  ttl     = 300

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

# MX records for email routing
resource "cloudflare_record" "mx1_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "MX"
  priority = "69"
  value = "route1.mx.cloudflare.net"
  ttl     = 1

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

resource "cloudflare_record" "mx2_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "MX"
  priority = "48"
  value = "route2.mx.cloudflare.net"
  ttl     = 1

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

resource "cloudflare_record" "mx3_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "MX"
  priority = "85"
  value = "route3.mx.cloudflare.net"
  ttl     = 1

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

# SPF records
resource "cloudflare_record" "spf_spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "@"
  type    = "TXT"
  value   = "v=spf1 include:_spf.mx.cloudflare.net ~all"
  ttl     = 300

  lifecycle {
    ignore_changes = [ value, ]
    prevent_destroy = true
  }
}

## Email Routing
resource "cloudflare_email_routing_settings" "spyrja_io" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  enabled = "true"
}

resource "cloudflare_email_routing_rule" "redelman" {
  zone_id = data.sops_file.encrypted-secrets.data["cloudflare_zone_id"]
  name    = "terraform rule"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "redelman@spyrja.io"
  }

  action {
    type  = "forward"
    value = ["redelman+spyrja@gmail.com"]
  }
}

resource "cloudflare_email_routing_address" "redelman" {
  account_id = data.sops_file.encrypted-secrets.data["cloudflare_account_id"]
  email = "redelman+spyrja@gmail.com"
}

# Maybe one day I'll figure out the permissions for this
/* resource "cloudflare_email_routing_catch_all" "spyrja_io" {
  zone_id = "0da42c8d2132a9ddaf714f9e7c920711"
  name    = "spyrja.io catch-all"
  enabled = true

  matcher {
    type = "all"
  }

  action {
    type  = "drop"
    value = []
  }
} */
