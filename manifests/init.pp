# @summary
#   conifigure puppet for master and agent
# @param owner
#   the owner of the puppet files and directories
# @param group
#   the group of the puppet files and directories
# @param service
#   the name of the puppet service
# @param confdir
#   the location of the puppet configueration
# @param puppet_state_dir
#   the location of the puppet state files
# @param puppet_master
#   indicates if the server is a puppet master
# @param dns_alt_names
#   Array of alternet DNS names to add to the csr
# @param hedgehoog_ca_path
#   location of the puppet environments
# @param hedgehoog_ca_path
#   location of the hedghog ca directory, this is configuered 
#   as an alternet location in puppet
# @param enable_nagios
#   indicates if we should export nagios\_service types
# @param environment_override
#   an environment to explicitly set the node to
#
class puppet_conf (
  String                         $owner,
  String                         $group,
  String                         $service,
  Stdlib::Absolutepath           $confdir,
  Stdlib::Absolutepath           $puppet_state_dir,
  Boolean                        $puppet_master,
  Optional[Array[Stdlib::Fqdn]]  $dns_alt_names,
  Stdlib::Absolutepath           $environments_path,
  Stdlib::Absolutepath           $hedgehoog_ca_path,
  Boolean                        $enable_nagios,
  Optional[String]               $environment_override,
) {

  $_environment = $environment_override ? {
    undef   => $::environment,
    default => $environment_override
  }
  $nagios_ensure = $enable_nagios ? {
    true    => 'present',
    default => 'absent',
  }
  $puppet_conf     = "${confdir}/puppet.conf"
  $fileserver_conf = "${confdir}/fileserver.conf"
  user {$owner:
    ensure => present,
  }
  file {$puppet_conf:
    owner => $owner,
    group => $group,
    mode  => '0644',
  }
  file {'/var/puppet/facts':
    owner => $owner,
    group => $group,
    mode  => '0644',
  }
  file {"${puppet_state_dir}/last_run_summary.yaml":
    owner => $owner,
    group => $group,
    mode  => '0644',
  }
  Ini_setting {
    ensure  => present,
    path    => $puppet_conf,
    section => 'main',
    notify  => Service[$service],
  }
  # update config
  ini_setting {'puppet_conf_agent_environment':
    setting => 'environment',
    value   => $_environment,
    section => 'agent',
  }
  ini_setting {
    'puppet_conf_certname':
      setting => 'certname',
      value   => $::fqdn;
  }
  if ! empty($dns_alt_names) {
    ini_setting {'puppet_dns_alt_names':
      setting => 'dns_alt_names',
      value   => join($dns_alt_names, ','),
    }
  }
  file {'/usr/local/bin/kick_puppet':
    ensure => file,
    mode   => '0555',
    source => 'puppet:///modules/puppet_conf/bin/kick_puppet',
  }
  cron {'puppet_conf: Kick puppet':
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
    ini_setting {'puppet_master_certname':
      section => 'master',
      setting => 'certname',
      value   => $::fqdn,
    }
    augeas { 'fileserver ca mount':
      incl      => $fileserver_conf,
      lens      => 'PuppetFileserver.lns',
      load_path => '/opt/puppet/share/augeas/lenses/dist',
      changes   => [
        "set /files/${fileserver_conf}/hedgehog_ca/path ${hedgehoog_ca_path}",
        "set /files/${fileserver_conf}/hedgehog_ca/allow *",
      ],
    }
  }
  service { $service:
    ensure => running,
    enable => true,
  }
#  @@nagios_service{ "${::fqdn}-PUPPET_ENV":
#    ensure              => $nagios_ensure,
#    use                 => 'generic-service',
#    host_name           => $::fqdn,
#    service_description => 'PUPPET_ENV',
#    check_command       => 'check_nrpe!check_puppet_environment',
#  }
#  @@nagios_service{ "${::fqdn}-PUPPET_LASTRUN":
#    ensure              => $nagios_ensure,
#    use                 => 'generic-service',
#    host_name           => $::fqdn,
#    service_description => 'PUPPET_LASTRUN',
#    check_command       => 'check_nrpe!check_puppet_lastrun',
#  }
}
