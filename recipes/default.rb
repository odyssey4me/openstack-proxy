#
# Cookbook Name:: openstack-proxy
#
# Recipe:: default
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Used for IP Address validation
require 'ipaddr'

# Include osops-utils for service/node search libraries
include_recipe 'osops-utils'

# Include keepalived for virtual ip setup
include_recipe 'keepalived'

# Include apache2 for reverse proxy setup
include_recipe 'apache2'
apache_module  'proxy_http'
apache_module  'substitute'

# Declare utility variables
service_array = Hash.new {|h,k| h[k] = Hash.new(&h.default_proc) }

node['openstack-proxy']['vips'].each do |virtual_ip, vip_props|

  # Check that the provided address is a valid IPv4 address
  ip = IPAddr.new virtual_ip
  if ! ip.ipv4?()
    Chef::Application.fatal!("#{router_id} has an invalid IPv4 address.")
  end

  vrrp_name = "vi_#{virtual_ip.gsub(/\./, '_')}"
  vrrp_interface = get_if_for_net(vip_props['network'], node)

  # Setup the virtual IP's
  keepalived_vrrp vrrp_name do
    interface vrrp_interface
    virtual_ipaddress Array(virtual_ip)
    virtual_router_id vip_props['vrid']
    notifies :restart, "service[keepalived]"
  end

  if node['openstack-proxy']['use_ssl']
    cookbook_file "/etc/ssl/certs/#{node['openstack-proxy']['cert_file']}" do
      source "#{node['openstack-proxy']['cert_file']}"
      mode 0644
      owner 'root'
      group 'root'
      notifies :restart, 'service[apache2]', :delayed
    end
    cookbook_file "/etc/ssl/private/#{node['openstack-proxy']['key_file']}" do
      source "#{node['openstack-proxy']['key_file']}"
      mode 0640
      owner 'root'
      group 'ssl-cert'
      notifies :restart, 'service[apache2]', :delayed
    end
    unless node['openstack-proxy']['chain_file'].nil?
      cookbook_file "/etc/ssl/certs/#{node['openstack-proxy']['chain_file']}" do
        source "#{node['openstack-proxy']['chain_file']}"
        mode 0644
        owner 'root'
        group 'root'
        notifies :restart, 'service[apache2]', :delayed
      end
    end
  end

  # We build the array of all reverse proxied services.
  # This is to ensure that we can perform substitution for all services on
  #  every reverse proxy to ensure that links referencing each other
  #  are still substituted correctly.
  node['openstack-proxy']['services'][virtual_ip].each do |service, properties|

    service_endpoint = get_access_endpoint(properties['role'],
                                           properties['namespace'],
                                           properties['service'])

    service_array[service]['public_name'] = vip_props['public_name']
    service_array[service]['public_ip'] = virtual_ip
    service_array[service]['public_port'] = service_endpoint['port']
    service_array[service]['internal_scheme'] = service_endpoint['scheme']
    service_array[service]['internal_ip'] = service_endpoint['host']
    service_array[service]['internal_port'] = service_endpoint['port']

  end
end

# Now that we have all the information we need, we implement the
#  reverse proxies.
service_array.each do |service, properties|

  template "#{node["apache"]["dir"]}/sites-available/proxy-#{service}" do
    source 'reverse-proxy-vhost.erb'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(
      :use_ssl => node['openstack-proxy']['use_ssl'],
      :public_ip => properties['public_ip'],
      :public_port => properties['public_port'],
      :public_name => properties['public_name'],
      :cert_file => "/etc/ssl/certs/#{node['openstack-proxy']['cert_file']}",
      :key_file => "/etc/ssl/private/#{node['openstack-proxy']['key_file']}",
      :chain_file => "/etc/ssl/certs/#{node['openstack-proxy']['chain_file']}",
      :internal_scheme => properties['internal_scheme'],
      :internal_ip => properties['internal_ip'],
      :internal_port => properties['internal_port'],
      :service_array => service_array,
      :apache_log_dir => node['apache']['log_dir'],
      :access_log_file => "proxy-#{service}-access.log",
      :error_log_file => "proxy-#{service}-error.log"
    )
    notifies :restart, 'service[apache2]', :delayed
  end

  apache_site "proxy-#{service}" do
    enable true
  end

end
