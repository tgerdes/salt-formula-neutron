{% from "neutron/map.jinja" import gateway, fwaas with context %}

{%- if fwaas.get('enabled', False) %}
include:
- neutron.fwaas
{%- endif %}

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

{%- for service_name in gateway.services %}
{{ service_name }}_default:
  file.managed:
    - name: /etc/default/{{ service_name }}
    - source: salt://neutron/files/default
    - template: jinja
    - defaults:
        service_name: {{ service_name }}
        values: {{ gateway }}
    - require:
      - pkg: neutron_gateway_packages
{%- if 'openvswitch' in gateway.backend.mechanism.values()|map(attribute="driver") %}
    - watch_in:
      - service: neutron_gateway_services_ovs
{% endif %}
{% endfor %}

{%- if gateway.logging.log_appender %}

{%- if gateway.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
neutron_gateway_fluentd_logger_package:
  pkg.installed:
    - name: python-fluent-logger
{%- endif %}

{% for service_name in gateway.services %}
{{ service_name }}_logging_conf:
  file.managed:
    - name: /etc/neutron/logging/logging-{{ service_name }}.conf
    - source: salt://neutron/files/logging.conf
    - template: jinja
    - makedirs: true
    - user: neutron
    - group: neutron
    - defaults:
        service_name: {{ service_name }}
        values: {{ gateway }}
    - require:
      - pkg: neutron_gateway_packages
{%- if gateway.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
      - pkg: neutron_gateway_fluentd_logger_package
{%- endif %}
{%- if 'openvswitch' in gateway.backend.mechanism.values()|map(attribute="driver") %}
    - watch_in:
      - service: neutron_gateway_services_ovs
{%- endif %}
{% endfor %}

{% endif %}

{%- if 'openvswitch' in gateway.backend.mechanism.values()|map(attribute="driver") %}
neutron_gateway_packages_ovs:
  pkg.installed:
  - names: {{ gateway.pkgs_ovs }}

/etc/neutron/plugins/ml2/openvswitch_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/openvswitch_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_packages

neutron_gateway_services_ovs:
  service.running:
  - names: {{ gateway.services_ovs }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/l3_agent.ini
    - file: /etc/neutron/metadata_agent.ini
    - file: /etc/neutron/plugins/ml2/openvswitch_agent.ini
    - file: /etc/neutron/dhcp_agent.ini
    {%- if fwaas.get('enabled', False) %}
    - file: /etc/neutron/fwaas_driver.ini
    {%- endif %}
    {%- if gateway.message_queue.get('ssl',{}).get('enabled', False) %}
    - file: rabbitmq_ca_neutron_gateway
    {%- endif %}

{%- endif %}
{%- if 'linuxbridge' in gateway.backend.mechanism.values()|map(attribute="driver") %}
neutron_gateway_packages_linuxbridge:
  pkg.installed:
  - names: {{ gateway.pkgs_linuxbridge }}

/etc/neutron/plugins/ml2/linuxbridge_agent.ini:
  file.managed:
  - source: salt://neutron/files/{{ gateway.version }}/linuxbridge_agent.ini
  - template: jinja
  - require:
    - pkg: neutron_gateway_packages_linuxbridge

/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini:
  file.managed:
  - makedirs: True
  - contents:
    - "# Workaround bug in neutron-linuxbridge-agent packaing that requires this file to exist"

neutron_gateway_services_linuxbridge:
  service.running:
  - names: {{ gateway.services_linuxbridge }}
  - enable: true
  - watch:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    - file: /etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini
{%- endif %}


{%- if gateway.message_queue.get('ssl',{}).get('enabled', False) %}
rabbitmq_ca_neutron_gateway:
{%- if gateway.message_queue.ssl.cacert is defined %}
  file.managed:
    - name: {{ gateway.message_queue.ssl.cacert_file }}
    - contents_pillar: neutron:gateway:message_queue:ssl:cacert
    - mode: 0444
    - makedirs: true
{%- else %}
  file.exists:
   - name: {{ gateway.message_queue.ssl.get('cacert_file', gateway.cacert_file) }}
{%- endif %}
{%- endif %}

{%- endif %}
