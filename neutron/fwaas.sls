{%- from "neutron/map.jinja" import compute, fwaas with context %}

{%- if fwaas.get('enabled', False) %}

neutron_fwaas_packages:
  pkg.installed:
  - names: {{ fwaas.pkgs }}

{%- if pillar.neutron.gateway is defined or compute.get('enabled', False) and compute.dvr %}
/etc/neutron/fwaas_driver.ini:
  file.managed:
  - source: salt://neutron/files/{{ fwaas.version }}/fwaas_driver.ini
  - template: jinja
  - require:
    - pkg: neutron_fwaas_packages
{%- endif %}

{%- endif %}
