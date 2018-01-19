{%- from "neutron/map.jinja" import server, fwaas with context %}

{%- if fwaas.get('enabled', False) %}
include:
- neutron.fwaas
{%- endif %}

{%- if server.get('enabled', False) %}
{% if grains.os_family == 'Debian' %}
# This is here to avoid starting up wrongly configured service and to avoid
# issue with restart limits on systemd.

policy_rcd_present:
  file.managed:
  - name: /usr/sbin/policy-rc.d
  - mode: 0775
  - contents: "exit 101"
  - require_in:
    - pkg: neutron_server_packages

policy_rcd_absent_ok:
  file.absent:
  - name: /usr/sbin/policy-rc.d
  - require:
    - pkg: neutron_server_packages

policy_rcd_absent_onfail:
  file.absent:
  - name: /usr/sbin/policy-rc.d
  - onfail:
    - pkg: neutron_server_packages
{% endif %}

neutron_server_packages:
  pkg.installed:
  - names: {{ server.pkgs }}

{% if server.backend.engine == "contrail" %}

/etc/neutron/plugins/opencontrail/ContrailPlugin.ini:
  file.managed:
  - source: salt://neutron/files/{{ server.version }}/ContrailPlugin.ini
  - template: jinja
  - require:
    - pkg: neutron_server_packages
    - pkg: neutron_contrail_package

contrail_plugin_link:
  cmd.run:
  - names:
    - ln -s /etc/neutron/plugins/opencontrail/ContrailPlugin.ini /etc/neutron/plugin.ini
  - unless: test -e /etc/neutron/plugin.ini
  - require:
    - file: /etc/neutron/plugins/opencontrail/ContrailPlugin.ini

neutron_contrail_package:
  pkg.installed:
  - name: neutron-plugin-contrail

neutron_server_service:
  service.running:
  - name: neutron-server
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - watch:
    - file: /etc/neutron/neutron.conf
    {%- if server.message_queue.get('ssl',{}).get('enabled', False) %}
    - file: rabbitmq_ca_neutron_server
    {%- endif %}
    {%- if server.database.get('ssl',{}).get('enabled', False) %}
    - file: mysql_ca_neutron_server
    {%- endif %}

{%- endif %}

{% if server.backend.engine in ["ml2", "ovn"] %}

/etc/neutron/plugins/ml2/ml2_conf.ini:
  file.managed:
  - source: salt://neutron/files/{{ server.version }}/ml2_conf.ini
  - template: jinja
  - require:
    - pkg: neutron_server_packages
  - watch_in:
    - service: neutron_server_services

ml2_plugin_link:
  cmd.run:
  - names:
    - ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
  - unless: test -e /etc/neutron/plugin.ini
  - require:
    - file: /etc/neutron/plugins/ml2/ml2_conf.ini

neutron_db_manage:
  cmd.run:
  - name: neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/ml2/ml2_conf.ini

{%- endif %}

/etc/neutron/neutron.conf:
  file.managed:
  - source: salt://neutron/files/{{ server.version }}/neutron-server.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: neutron_server_packages
    {%- if server.database.get('ssl',{}).get('enabled', False) %}
    - file: mysql_ca_neutron_server
    {%- endif %}

/etc/neutron/api-paste.ini:
  file.managed:
    - source: salt://neutron/files/{{ server.version  }}/api-paste.ini.{{ grains.os_family  }}
    - template: jinja
    - require:
      - pkg: neutron_server_packages

{%- for service_name in server.get('services', []) %}
{%- if service_name != 'neutron-server' %}
{{ service_name }}_default:
  file.managed:
    - name: /etc/default/{{ service_name }}
    - source: salt://neutron/files/default
    - template: jinja
    - defaults:
        service_name: {{ service_name }}
        values: {{ server }}
    - require:
      - pkg: neutron_server_packages
    - watch_in:
      - service: neutron_server_services
{%- endif %}
{%- endfor %}

{%- if server.logging.log_appender %}

{%- if server.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
neutron_server_fluentd_logger_package:
  pkg.installed:
    - name: python-fluent-logger
{%- endif %}

{%- for service_name in server.services %}
{{ service_name }}_logging_conf:
  file.managed:
    - name: /etc/neutron/logging/logging-{{ service_name }}.conf
    - source: salt://neutron/files/logging.conf
    - template: jinja
    - makedirs: True
    - defaults:
        service_name: {{ service_name }}
        values: {{ server }}
    - user: neutron
    - group: neutron
    - require:
      - pkg: neutron_server_packages
{%- if server.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
      - pkg: neutron_server_fluentd_logger_package
{%- endif %}
    - watch_in:
      - service: neutron_server_services
{%- endfor %}

{%- endif %}

{%- for name, rule in server.get('policy', {}).iteritems() %}

{%- if rule != None %}
rule_{{ name }}_present:
  keystone_policy.rule_present:
  - path: /etc/neutron/policy.json
  - name: {{ name }}
  - rule: {{ rule }}
  - require:
    - pkg: neutron_server_packages

{%- else %}

rule_{{ name }}_absent:
  keystone_policy.rule_absent:
  - path: /etc/neutron/policy.json
  - name: {{ name }}
  - require:
    - pkg: neutron_server_packages

{%- endif %}

{%- endfor %}

{%- if grains.os_family == "Debian" %}

/etc/default/neutron-server:
  file.managed:
  - source: salt://neutron/files/{{ server.version }}/neutron-server
  - template: jinja
  - require:
    - pkg: neutron_server_packages
  - watch_in:
    - service: neutron_server_services

{%- endif %}

{%- if server.backend.engine == "ovn" %}

ovn_packages:
  pkg.installed:
  - names: {{ server.pkgs_ovn }}

{%- if not grains.get('noservices', False) %}

remote_ovsdb_access:
  cmd.run:
  - name: "ovs-appctl -t ovsdb-server ovsdb-server/add-remote
  ptcp:6640:{{ server.controller_vip }}"

open_ovs_port:
  iptables.append:
    - table: filter
    - chain: INPUT
    - jump: ACCEPT
    - dport: 6640
    - proto: tcp
    - save: True

ovn_services:
  service.running:
  - names: {{ server.services_ovn }}
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - pkg: ovn_packages

{%- if grains.os_family == 'Debian' %}
/etc/default/ovn-central:
  file.managed:
  - source: salt://neutron/files/{{ server.version }}/ovn_central_options
  - template: jinja
  - require:
    - pkg: ovn_packages
  - watch_in:
    - service: ovn_services
{%- endif %}
{%- endif %}
{%- endif %}

{%- if server.backend.engine == "midonet" %}

/etc/neutron/plugins/midonet/midonet.ini:
  file.managed:
    - source: salt://neutron/files/{{ server.version }}/midonet.ini
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755
    - template: jinja

neutron_db_manage:
  cmd.run:
  - name: neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/midonet/midonet.ini upgrade head
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/midonet/midonet.ini

{%- if server.version == "kilo" %}

midonet_neutron_packages:
  pkg.installed:
  - names:
    - python-neutron-plugin-midonet
    - python-neutron-lbaas

midonet-db-manage:
  cmd.run:
  - name: midonet-db-manage upgrade head

{%- else %}

midonet_neutron_packages:
  pkg.installed:
  - names:
    - python-networking-midonet
    - python-neutron-lbaas
    - python-neutron-fwaas

neutron_db_manage:
  cmd.run:
  - name: neutron-db-manage --subproject networking-midonet upgrade head
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - require:
    - file: /etc/neutron/neutron.conf
    - file: /etc/neutron/plugins/midonet/midonet.ini

{%- endif %}
{%- endif %}

neutron_server_services:
  service.running:
  - names: {{ server.services }}
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - watch:
    - file: /etc/neutron/neutron.conf
    {%- if server.message_queue.get('ssl',{}).get('enabled', False) %}
    - file: rabbitmq_ca_neutron_server
    {%- endif %}
    {%- if server.database.get('ssl',{}).get('enabled', False) %}
    - file: mysql_ca_neutron_server
    {%- endif %}

{%- if grains.get('virtual_subtype', None) == "Docker" %}

neutron_entrypoint:
  file.managed:
  - name: /entrypoint.sh
  - template: jinja
  - source: salt://neutron/files/entrypoint.sh
  - mode: 755

{%- endif %}


{%- if server.message_queue.get('ssl',{}).get('enabled', False) %}
rabbitmq_ca_neutron_server:
{%- if server.message_queue.ssl.cacert is defined %}
  file.managed:
    - name: {{ server.message_queue.ssl.cacert_file }}
    - contents_pillar: neutron:server:message_queue:ssl:cacert
    - mode: 0444
    - makedirs: true
{%- else %}
  file.exists:
   - name: {{ server.message_queue.ssl.get('cacert_file', server.cacert_file) }}
{%- endif %}
{%- endif %}

{%- if server.database.get('ssl',{}).get('enabled', False) %}
mysql_ca_neutron_server:
{%- if server.database.ssl.cacert is defined %}
  file.managed:
    - name: {{ server.database.ssl.cacert_file }}
    - contents_pillar: neutron:server:database:ssl:cacert
    - mode: 0444
    - makedirs: true
{%- else %}
  file.exists:
   - name: {{ server.database.ssl.get('cacert_file', server.cacert_file) }}
{%- endif %}
{%- endif %}

{%- endif %}
