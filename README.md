Description
===========

Installs:

* apache using the apache cookbook
* keepalived using the keepalived cookbook

Configures:
* a floating IP for the reverse proxy service
* an apache reverse proxy for each openstack service

Requirements
============

Chef 0.10.0 or higher required (for Chef environment use).
This cookbook assumes that it's being used in a deployment based on the rcbops cookbooks.

Platforms
--------

* Ubuntu >= 12.04

Cookbooks
---------

The following cookbooks are dependencies:

* keepalived
* osops-utils
* apache2

Recipes
=======

default
----
- Iterates through the list of services provided in the attributes/environment
- Uses `node['openstack-proxy']['vips']` to add floating IP's using keepalived
- Uses `node['openstack-proxy']['services']` to search for the appropriate back-ends and create the reverse proxies for each of them

attributes
----
Using the example:

```json
    "openstack-proxy": {
      "use_ssl": true,
      "vips": {
        "192.168.4.114": {
          "vrid": 13,
          "network": "public",
          "public_name": "api.example.com"
        }
      },
      "services": {
        "192.168.4.114": {
          "keystone-service-api": {
            "role": "keystone-api",
            "namespace": "keystone",
            "service": "service-api"
          },
          "keystone-admin-api": {
            "role": "keystone-api",
            "namespace": "keystone",
            "service": "admin-api"
          },
          "nova-api": {
            "role": "nova-api-os-compute",
            "namespace": "nova",
            "service": "api"
          }
        }
      }
    }
```

- use_ssl is a global setting to make all reverse proxies listen via ssl
- the virtual ip of 192.168.4.114 with keepalived using a virtual router id of 13 on the osops_network 'public' and all reverse proxies on that address have the servername directive of 'api.example.com'. The virtual router ID must be a value between 1 and 255 and must be unique!
- three services are setup for reverse proxy: the keystone service api, keystone admin api and nova api. The role, namespace and service values must come from the openstack-ha cookbook attributes.

License and Author
==================

Author:: Jesse Pretorius <jesse.pretorius@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
