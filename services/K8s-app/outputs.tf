# Expose the service endpoint (the loadbalancer hostname)
locals {
    status = kubernetes_service.app.status
}

# output "service_endpoint" {
#     value = try(
#         "http://${local.status[0]["load_balancer"][0]["ingress"][0]["hostname"]}", 
#         "(error parsing hostname from status)"
#         )
#         description = "The k8s service endpoint"
# }

output "service_endpoint" {
  value = try(
    "http://${local.status[0].load_balancer[0].ingress[0].hostname}",
    try(
      "http://${local.status[0].load_balancer[0].ingress[0].ip}",
      "Service endpoint not yet available"
    )
  )
  description = "The k8s service endpoint"
}

output "service_ip" {
  value = try(
    local.status[0].load_balancer[0].ingress[0].ip,
    "Pending or not available"
  )
  description = "The service IP address (if available)"
}

output "service_name" {
  value = kubernetes_service.app.metadata[0].name
  description = "The service name"
}

