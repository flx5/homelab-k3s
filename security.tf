
resource "random_password" "k3s_token" {
  length           = 128
  special          = false
}
