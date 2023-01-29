locals {
  image_cache_dir    = abspath(".terraform/image_cache")
  disk_info          = jsondecode(data.http.coreos-stable.response_body)["architectures"]["x86_64"]["artifacts"]["qemu"]["formats"]["qcow2.xz"]["disk"]
  download_url       = local.disk_info["location"]
  extracted_filename = trimsuffix(basename(local.download_url), ".xz")
  image_path         = "${local.image_cache_dir}/${local.extracted_filename}"
}


data "http" "coreos-stable" {
  url = "https://builds.coreos.fedoraproject.org/streams/stable.json"

  request_headers = {
    Accept = "application/json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Status code invalid"
    }
  }
}

resource "null_resource" "download-extract-image-fedora-coreos" {
  provisioner "local-exec" {
    command = "${path.module}/download_image.sh '${local.download_url}' '${local.image_cache_dir}' '${local.extracted_filename}'"
  }

  triggers = {
    source = data.http.coreos-stable.response_body
  }


  lifecycle {
    postcondition {
      # Workaround the early evaluation by first appending the id and then removing it. Otherwise this fails with a file not found error on first run.
      condition     = filesha256(trimsuffix("${local.image_path}${self.id}", self.id)) == local.disk_info["uncompressed-sha256"]
      error_message = "Checksum mismatch"
    }
  }
}

output "image_path" {
  value = local.image_path
}