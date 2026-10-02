locals {
  routes = jsondecode(var.routes_json)
}

resource "aws_route" "this" {
  for_each       = local.routes
  route_table_id = var.route_table_id

  # Destino (aceita 'destination_cidr_block' OU 'cidr_block' no JSON)
  destination_cidr_block = try(coalesce(
    lookup(each.value, "destination_cidr_block", null),
    lookup(each.value, "cidr_block", null)
  ), null)

  destination_ipv6_cidr_block = try(coalesce(
    lookup(each.value, "destination_ipv6_cidr_block", null),
    lookup(each.value, "ipv6_cidr_block", null)
  ), null)

  destination_prefix_list_id = try(each.value.destination_prefix_list_id, null)

  # Alvo (use apenas 1 por rota)
  # Placeholders (ex: "${IGW_ID}") são resolvidos aqui, por valor, para que as chaves do for_each sejam estáticas
  gateway_id                = try(lookup(var.placeholders, each.value.gateway_id, each.value.gateway_id), null) # IGW/VGW
  nat_gateway_id            = try(lookup(var.placeholders, each.value.nat_gateway_id, each.value.nat_gateway_id), null)
  transit_gateway_id        = try(each.value.transit_gateway_id, null)
  vpc_peering_connection_id = try(each.value.vpc_peering_connection_id, null)
  vpc_endpoint_id           = try(each.value.vpc_endpoint_id, null)
  egress_only_gateway_id    = try(each.value.egress_only_gateway_id, null)
  network_interface_id      = try(each.value.network_interface_id, null)
  core_network_arn          = try(each.value.core_network_arn, null)
  local_gateway_id          = try(each.value.local_gateway_id, null)
  carrier_gateway_id        = try(each.value.carrier_gateway_id, null)
}
