{% from "neutron/map.jinja" import compute, fwaas with context %}
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

{%- if 'openvswitch' in compute.backend.mechanism.values()|map(attribute="driver") %}
neutron_compute_packages_ovs:
  pkg.installed:
  - names: {{ compute.pkgs_ovs }}

/etc/neutron/plugins/ml2/openvswitch_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/openvswitch_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_compute_packages_ovs

neutron_compute_services:
  service.running:
  - names: {{ compute.services_ovs }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/openvswitch_agent.ini
    {%- if compute.message_queue.get('ssl',{}).get('enabled', False) %}
    - file: rabbitmq_ca_neutron_compute
    {%- endif %}
{% endif %}

{%- if 'linuxbridge' in compute.backend.mechanism.values()|map(attribute="driver") %}
neutron_compute_packages_linuxbridge:
  pkg.installed:
  - names: {{ compute.pkgs_linuxbridge }}

/etc/neutron/plugins/ml2/linuxbridge_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ compute.version }}/linuxbridge_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_compute_packages_linuxbridge

/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini:
  file.managed:
  - makedirs: True
  - contents:
    - "# Workaround bug in neutron-linuxbridge-agent packaing that requires this file to exist"

neutron_compute_services:
  service.running:
  - names: {{ compute.services_linuxbridge }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    - file: /etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini
{% endif %}

{%- set neutron_compute_services_list = compute.services_ovs %}
{%- if compute.backend.sriov is defined %}
  {%- do neutron_compute_services_list.append('neutron-sriov-agent') %}
{%- endif %}
{%- if compute.dvr %}
  {%- do neutron_compute_services_list.extend(['neutron-l3-agent', 'neutron-metadata-agent']) %}
{%- endif %}

{%- for service_name in neutron_compute_services_list %}
{{ service_name }}_default:
  file.managed:
    - name: /etc/default/{{ service_name }}
    - source: salt://neutron/files/default
    - template: jinja
    - defaults:
        service_name: {{ service_name }}
        values: {{ compute }}
    - require:
      - pkg: neutron_compute_packages
{% if compute.backend.sriov is defined %}
      - pkg: neutron_sriov_package
{% endif %}
{% if compute.dvr %}
      - pkg: neutron_dvr_packages
{% endif %}
    - watch_in:
      - service: neutron_compute_services
{% if compute.backend.sriov is defined %}
      - service: neutron_sriov_service
{% endif %}
{% if compute.dvr %}
      - service: neutron_dvr_agents
{% endif %}
{% endfor %}

{%- if compute.logging.log_appender %}

{%- if compute.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
neutron_compute_fluentd_logger_package:
  pkg.installed:
    - name: python-fluent-logger
{%- endif %}

{% for service_name in neutron_compute_services_list %}
{{ service_name }}_logging_conf:
  file.managed:
    - name: /etc/neutron/logging/logging-{{ service_name }}.conf
    - source: salt://neutron/files/logging.conf
    - template: jinja
    - makedirs: True
    - user: neutron
    - group: neutron
    - defaults:
        service_name: {{ service_name }}
        values: {{ compute }}
    - require:
      - pkg: neutron_compute_packages
{% if compute.backend.sriov is defined %}
      - pkg: neutron_sriov_package
{% endif %}
{% if compute.dvr %}
      - pkg: neutron_dvr_packages
{% endif %}
{%- if compute.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
      - pkg: neutron_compute_fluentd_logger_package
{%- endif %}
    - watch_in:
      - service: neutron_compute_services
{% if compute.backend.sriov is defined %}
      - service: neutron_sriov_service
{% endif %}
{% if compute.dvr %}
      - service: neutron_dvr_agents
{% endif %}
{% endfor %}

{% endif %}

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
   - name: {{ compute.message_queue.ssl.get('cacert_file', compute.cacert_file) }}
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
