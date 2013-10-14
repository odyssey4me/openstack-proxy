name              "openstack-proxy"
maintainer        "Jesse Pretorius <jesse.pretorius@gmail.com>"
license           "Apache 2.0"
description       "Configures Reverse Proxy for SSL access to Openstack Services"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "0.0.1"
supports          "ubuntu"

%w{ keepalived osops-utils apache2 }.each do |dep|
  depends dep
end

