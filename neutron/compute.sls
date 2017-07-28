{% from "neutron/map.jinja" import compute, fwaas, system_cacerts_file with context %}
{%- if compute.enabled %}

{% if compute.backend.engine == "ml2" %}
neutron_compute_packages:
  pkg.installed:
  - names: {{ compute.pkgs }}

/etc/neutron/neutron.conf:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/neutron-generic.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: neutron_compute_packages

{% if compute.backend.sriov is defined %}

neutron_sriov_package:
  pkg.installed:
  - name: neutron-sriov-agent

/etc/neutron/plugins/ml2/sriov_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/sriov_agent.ini
  - template: jinja
  - watch_in:
    - service: neutron_compute_services
  - require:
    - pkg: neutron_compute_packages
    - pkg: neutron_sriov_package

neutron_sriov_service:
  service.running:
  - name: neutron-sriov-agent
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - watch_in:
    - service: neutron_compute_services
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/openvswitch_agent.ini
    - file: /etc/neutron/plugins/ml2/sriov_agent.ini
    {%- if compute.message_queue.get('ssl',{}).get('enabled', False) %}
    - file: rabbitmq_ca_neutron_compute
    {%- endif %}

{% endif %}

{% if compute.dvr %}

{%- if fwaas.get('enabled', False) %}
include:
- neutron.fwaas
{%- endif %}

neutron_dvr_packages:
  pkg.installed:
  - names:
    - neutron-l3-agent
    - neutron-metadata-agent

neutron_dvr_agents:
  service.running:
    - enable: true
    - names:
      - neutron-l3-agent
      - neutron-metadata-agent
    - watch:
      - file: /etc/neutron/neutron.conf
      - file: /etc/neutron/l3_agent.ini
      - file: /etc/neutron/metadata_agent.ini
      {%- if fwaas.get('enabled', False) %}
      - file: /etc/neutron/fwaas_driver.ini
      {% endif %}
      {%- if compute.message_queue.get('ssl',{}).get('enabled', False) %}
      - file: rabbitmq_ca_neutron_compute
      {%- endif %}
    - require:
      - pkg: neutron_dvr_packages

/etc/neutron/l3_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/l3_agent.ini
  - template: jinja
  - watch_in:
    - service: neutron_compute_services
  - require:
    - pkg: neutron_dvr_packages

/etc/neutron/metadata_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/metadata_agent.ini
  - template: jinja
  - watch_in:
    - service: neutron_compute_services
  - require:
    - pkg: neutron_dvr_packages

{% endif %}

/etc/neutron/plugins/ml2/openvswitch_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/openvswitch_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_compute_packages

neutron_compute_services:
  service.running:
  - names: {{ compute.services }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/openvswitch_agent.ini
    {%- if compute.message_queue.get('ssl',{}).get('enabled', False) %}
    - file: rabbitmq_ca_neutron_compute
    {%- endif %}


{%- if compute.message_queue.get('ssl',{}).get('enabled', False) %}
rabbitmq_ca_neutron_compute:
{%- if compute.message_queue.ssl.cacert is defined %}
  file.managed:
    - name: {{ compute.message_queue.ssl.cacert_file }}
    - contents_pillar: neutron:compute:message_queue:ssl:cacert
    - mode: 0444
    - makedirs: true
{%- else %}
  file.exists:
   - name: {{ compute.message_queue.ssl.get('cacert_file', system_cacerts_file) }}
{%- endif %}
{%- endif %}

{%- elif compute.backend.engine == "ovn" %}

ovn_packages:
  pkg.installed:
  - names: {{ compute.pkgs_ovn }}

{%- if not grains.get('noservices', False) %}

remote_ovsdb_access:
  cmd.run:
  - name: "ovs-vsctl set open .
  external-ids:ovn-remote=tcp:{{ compute.controller_vip }}:6642"

enable_overlays:
  cmd.run:
  - name: "ovs-vsctl set open . external-ids:ovn-encap-type=geneve,vxlan"

configure_local_endpoint:
  cmd.run:
  - name: "ovs-vsctl set open .
  external-ids:ovn-encap-ip={{ compute.local_ip }}"

{%- if compute.get('external_access', True) %}

set_bridge_external_id:
  cmd.run:
  - name: "ovs-vsctl --no-wait br-set-external-id
   {{ compute.external_bridge }} bridge-id {{ compute.external_bridge }}"

set_bridge_mapping:
  cmd.run:
  - name: "ovs-vsctl set open .
   external-ids:ovn-bridge-mappings=physnet1:{{ compute.external_bridge }}"

{%- endif %}

ovn_services:
  service.running:
  - names: {{ compute.services_ovn }}
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - pkg: ovn_packages

{%- endif %}
{%- endif %}
{%- endif %}
