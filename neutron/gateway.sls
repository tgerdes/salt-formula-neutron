{% from "neutron/map.jinja" import gateway with context %}
{%- if gateway.enabled %}

neutron_gateway_packages:
  pkg.installed:
  - names: {{ gateway.pkgs }}

{%- if pillar.neutron.server is not defined %}

/etc/neutron/neutron.conf:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/neutron-generic.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: neutron_gateway_packages

{%- endif %}


/etc/neutron/l3_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/l3_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_packages

/etc/neutron/dhcp_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/dhcp_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_packages

/etc/neutron/metadata_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/metadata_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_packages

{%- if 'openvswitch' in gateway.backend.mechanism.values()|map(attribute="driver") %}
neutron_gateway_ovs_packages:
  pkg.installed:
  - names: {{ gateway.ovs_pkgs }}

/etc/neutron/plugins/ml2/openvswitch_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/openvswitch_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_ovs_packages

neutron_gateway_agent_service:
  service.running:
  - names: {{ gateway.ovs_services }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/openvswitch_agent.ini
{%- endif %}

{%- if 'linuxbridge' in gateway.backend.mechanism.values()|map(attribute="driver") %}
neutron_gateway_linuxbridge_packages:
  pkg.installed:
  - names: {{ gateway.linuxbridge_pkgs }}

/etc/neutron/plugins/ml2/linuxbridge_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/linuxbridge_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_linuxbridge_packages

/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini:
  file.managed:
  - makedirs: True
  - contents:
    - "# Workaround bug in neutron-linuxbridge-agent packaing that requires this file to exist"

neutron_gateway_agent_service:
  service.running:
  - names: {{ gateway.linuxbridge_services }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    - file: /etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini
{%- endif %}

neutron_gateway_services:
  service.running:
  - names: {{ gateway.services }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/l3_agent.ini
    - file: /etc/neutron/metadata_agent.ini
    - file: /etc/neutron/dhcp_agent.ini

{%- endif %}
