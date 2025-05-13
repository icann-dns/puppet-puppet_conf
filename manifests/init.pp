# @summary configure puppet for master and agent
# @param owner the owner of the puppet files and directories
# @param group the group of the puppet files and directories
# @param service the name of the puppet service
# @param confdir the location of the puppet configuration
# @param puppet_state_dir the location of the puppet state files
# @param puppet_master indicates if the server is a puppet master
# @param include_legacy_facts enable legacy facts
# @param dns_alt_names Array of alternet DNS names to add to the csr
# @param environment_override an environment to explicitly set the node to
#
class puppet_conf (
  String               $owner                = 'pe-puppet',
  String               $group                = 'pe-puppet',
  String               $service              = 'puppet',
  Stdlib::Absolutepath $confdir              = '/etc/puppetlabs/puppet',
  Stdlib::Absolutepath $puppet_state_dir     = '/opt/puppetlabs/puppet/cache/state',
  Boolean              $puppet_master        = false,
  Boolean              $include_legacy_facts = false,
  String               $environment_override = $::environment,  # lint:ignore:top_scope_facts
  Array[Stdlib::Fqdn]  $dns_alt_names        = [],
) {
  $puppet_conf     = "${confdir}/puppet.conf"
  $fileserver_conf = "${confdir}/fileserver.conf"

  user { $owner:
    ensure => present,
  }
  file { '/var/puppet/facts':
    owner => $owner,
    group => $group,
    mode  => '0644',
  }
  file { "${puppet_state_dir}/last_run_summary.yaml":
    owner => $owner,
    group => $group,
    mode  => '0644',
  }
  # update config
  ini_setting {
    default:
      ensure  => present,
      path    => $puppet_conf,
      section => 'agent',
      notify  => Service[$service];
    'puppet_conf_agent_environment':
      setting => 'environment',
      value   => $environment_override;
    'puppet_conf_legacy_facts':
      setting => 'include_legacy_facts',
      value   => String($include_legacy_facts);
    'puppet_conf_certname':
      setting => 'certname',
      section => 'main',
      value   => $facts['networking']['fqdn'];
  }
  unless $dns_alt_names.empty() {
    ini_setting { 'puppet_dns_alt_names':
      ensure  => present,
      path    => $puppet_conf,
      section => 'main',
      setting => 'dns_alt_names',
      value   => $dns_alt_names.join(','),
    }
  }
  file { '/usr/local/bin/kick_puppet':
    ensure => file,
    mode   => '0555',
    source => 'puppet:///modules/puppet_conf/bin/kick_puppet',
  }
  cron { 'puppet_conf: Kick puppet':
    ensure  => present,
    command => '/usr/local/bin/kick_puppet',
    minute  => 0,
    require => File['/usr/local/bin/kick_puppet'],
  }
  if $puppet_master {
    cron {
      'puppet_conf: check puppetserver':
        ensure  => present,
        command => 'service pe-puppetserver status > /dev/null || service pe-puppetserver restart',
        minute  => 10;
      'puppet_conf: check puppetdb':
        ensure  => present,
        command => 'service pe-puppetdb status > /dev/null || service pe-puppetdb restart',
        minute  => 20;
    }
    ini_setting { 'puppet_master_certname':
      ensure  => present,
      path    => $puppet_conf,
      section => 'master',
      setting => 'certname',
      value   => $facts['networking']['fqdn'],
    }
  }
  file { $puppet_conf:
    owner => $owner,
    group => $group,
    mode  => '0644',
  }
  service { $service:
    ensure => running,
    enable => true,
  }
}
