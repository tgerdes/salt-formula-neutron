{%- from "neutron/map.jinja" import client with context %}
{%- if client.enabled %}

neutron_client_packages:
  pkg.installed:
  - names: {{ client.pkgs }}


{%- for identity_name, identity in client.server.iteritems() %}
{%- if identity.network is defined %}

{%- for network_name, network in identity.network.iteritems() %}

neutron_openstack_network_{{ network_name }}:
  neutronng.network_present:
    - name: {{ network_name }}
    - profile: {{ identity_name }}
    - tenant: {{ network.tenant }}
    {%- if identity.endpoint_type is defined %}
    - endpoint_type: {{ identity.endpoint_type }}
    {%- endif %}

    {%- if network.provider_network_type is defined %}
    - provider_network_type: {{ network.provider_network_type }}
    {%- endif %}
    {%- if network.provider_physical_network is defined %}
    - provider_physical_network: {{ network.provider_physical_network }}
    {%- endif %}
    {%- if network.router_external is defined %}
    - router_external: {{ network.router_external }}
    {%- endif %}
    {%- if network.admin_state_up is defined %}
    - admin_state_up: {{ network.admin_state_up }}
    {%- endif %}
    {%- if network.shared is defined %}
    - shared: {{ network.shared }}
    {%- endif %}
    {%- if network.provider_segmentation_id is defined %}
    - provider_segmentation_id: {{ network.provider_segmentation_id }}
    {%- endif %}

{%- if network.subnet is defined %}

{%- for subnet_name, subnet in network.subnet.iteritems() %}
neutron_openstack_subnet_{{ subnet_name }}:
  neutronng.subnet_present:
    - name: {{ subnet_name }}
    - network_name: {{ network_name }}
    - profile: {{ identity_name }}
    - tenant: {{ network.tenant }}
    {%- if identity.endpoint_type is defined %}
    - endpoint_type: {{ identity.endpoint_type }}
    {%- endif %}

    {%- if subnet.cidr is defined %}
    - cidr: {{ subnet.cidr  }}
    {%- endif %}
    {%- if subnet.ip_version is defined %}
    - ip_version: {{ subnet.ip_version }}
    {%- endif %}
    {%- if subnet.enable_dhcp is defined %}
    - enable_dhcp: {{ subnet.enable_dhcp }}
    {%- endif %}
    {%- if subnet.allocation_pools is defined %}
    - allocation_pools: {{ subnet.allocation_pools }}
    {%- endif %}
    {%- if subnet.gateway_ip is defined %}
    - gateway_ip: {{ subnet.gateway_ip }}
    {%- endif %}
    {%- if subnet.dns_nameservers is defined %}
    - dns_nameservers: {{ subnet.dns_nameservers }}
    {%- endif %}
    {%- if subnet.host_routes is defined %}
    - host_routes: {{ subnet.host_routes }}
    {%- endif %}
    - require:
      - neutronng: neutron_openstack_network_{{ network_name }}

{%- endfor %}

{%- endif %}

{%- endfor %}

{%- endif %}

{%- if identity.router is defined %}

{%- for router_name, router in identity.router.iteritems() %}
neutron_openstack_router_{{ router_name }}:
  neutronng.router_present:
    - name: {{ router_name }}
    - interfaces: {{ router.interfaces }}
    - gateway_network: {{ router.gateway_network }}
    - profile: {{ identity_name }}
    - tenant: {{ router.tenant }}
    - admin_state_up: {{ router.admin_state_up }}
    {%- if identity.endpoint_type is defined %}
    - endpoint_type: {{ identity.endpoint_type }}
    {%- endif %}
{%- endfor %}

{%- endif %}

{%- if identity.security_group is defined %}

{%- for security_group_name, security_group in identity.security_group.iteritems() %}
openstack_security_group_{{ security_group_name }}:
  neutronng.security_group_present:
    - name: {{ security_group_name }}
    {%- if security_group.description is defined %}
    - description: {{ security_group.description }}
    {%- endif %}
    - rules: {{ security_group.rules }}
    - profile: {{ identity_name }}
    - tenant: {{ security_group.tenant }}
    {%- if identity.endpoint_type is defined %}
    - endpoint_type: {{ identity.endpoint_type }}
    {%- endif %}
{%- endfor %}

{%- endif %}

{%- if identity.floating_ip is defined %}

{%- for instance_name, instance in identity.floating_ip.iteritems() %}
neutron_floating_ip_for_{{ instance_name }}:
  neutronng.floatingip_present:
    - subnet: {{ instance.subnet }}
    - tenant_name: {{ instance.tenant }}
    - name: {{ instance.server }}
    - network:  {{ instance.network }}
    - profile: {{ identity_name }}
    {%- if identity.endpoint_type is defined %}
    - endpoint_type: {{ identity.endpoint_type }}
    {%- endif %}

{%- endfor %}

{%- endif %}

{%- endfor %}

{%- endif %}
