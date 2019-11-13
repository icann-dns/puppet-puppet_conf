require 'spec_helper'

describe 'puppet_conf' do
  let(:node) { 'foobar.example.com' }
  let(:params) do
    {
      # owner: nil,
      # group: nil,
      # service: nil,
      # confdir: nil,
      # puppet_state_dir: nil,
      # puppet_master: nil,
      # dns_alt_names: nil,
      # hedgehoog_ca_path: nil,
      # enable_nagios: nil,
      environment_override: 'production',
    }
  end

  # Puppet::Util::Log.level = :debug
  # Puppet::Util::Log.newdestination(:console)
  # This will need to get moved
  # it { pp catalogue.resources }
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      case facts[:kernel]
      when 'FreeBSD'
        let(:owner)             { 'puppet' }
        let(:group)             { 'puppet' }
        let(:puppet_state_dir)  { '/var/puppet/state' }
        let(:confdir)           { '/usr/local/etc/puppet' }
        let(:environments_path) { '/usr/local/etc/puppet/environments' }
      else
        let(:owner)             { 'pe-puppet' }
        let(:group)             { 'pe-puppet' }
        let(:puppet_state_dir)  { '/opt/puppetlabs/puppet/cache/state' }
        let(:confdir)           { '/etc/puppetlabs/puppet' }
        let(:environments_path) { '/etc/puppetlabs/code/environments' }
      end

      describe 'check default config' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_user(owner).with_ensure('present') }
        it do
          is_expected.to contain_file("#{confdir}/puppet.conf").with(
            owner: owner,
            group: group,
            mode: '0644',
          )
        end
        it do
          is_expected.to contain_file('/var/puppet/facts').with(
            owner: owner,
            group: group,
            mode: '0644',
          )
        end
        it do
          is_expected.to contain_file(
            "#{puppet_state_dir}/last_run_summary.yaml",
          ).with(
            owner: owner,
            group: group,
            mode: '0644',
          )
        end
        it do
          is_expected.to contain_ini_setting(
            'puppet_conf_agent_environment',
          ).with(
            setting: 'environment',
            value: 'production',
            section: 'agent',
          )
        end
        it do
          is_expected.to contain_ini_setting('puppet_conf_certname').with(
            path: "#{confdir}/puppet.conf",
            setting: 'certname',
            value: 'foobar.example.com',
          )
        end
        it { is_expected.not_to contain_ini_setting('puppet_dns_alt_names') }
        it do
          is_expected.to contain_file('/usr/local/bin/kick_puppet').with(
            ensure: 'file',
            mode: '0555',
            source: 'puppet:///modules/puppet_conf/bin/kick_puppet',
          )
        end
        it do
          is_expected.to contain_cron('puppet_conf: Kick puppet').with(
            ensure: 'present',
            command: '/usr/local/bin/kick_puppet',
            minute: '0',
            require: 'File[/usr/local/bin/kick_puppet]',
          )
        end
        it { is_expected.not_to contain_cron('puppet_conf: check puppetserver') }
        it { is_expected.not_to contain_cron('puppet_conf: check puppetdb') }
        it { is_expected.not_to contain_ini_setting('puppet_master_certname') }
        it { is_expected.not_to contain_file(environments_path) }
        it { is_expected.not_to contain_augeas('fileserver ca mount') }
        it do
          is_expected.to contain_service('puppet').with(
            ensure: 'running',
            enable: true,
          )
        end
        it do
          is_expected.not_to contain_nagios_service(
            'foobar.example.com-PUPPET_ENV',
          )
        end
        it do
          is_expected.not_to contain_nagios_service(
            'foobar.example.com-PUPPET_LASTRUN',
          )
        end
      end
      describe 'Change Defaults' do
        context 'owner' do
          before(:each) { params.merge!(owner: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              "#{confdir}/puppet.conf",
            ).with_owner('foobar')
          end
          it do
            is_expected.to contain_file('/var/puppet/facts').with_owner('foobar')
          end
          it do
            is_expected.to contain_file(
              "#{puppet_state_dir}/last_run_summary.yaml",
            ).with_owner('foobar')
          end
        end
        context 'group' do
          before(:each) { params.merge!(group: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_file(
              "#{confdir}/puppet.conf",
            ).with_group('foobar')
          end
          it do
            is_expected.to contain_file('/var/puppet/facts').with_group('foobar')
          end
          it do
            is_expected.to contain_file(
              "#{puppet_state_dir}/last_run_summary.yaml",
            ).with_group('foobar')
          end
        end
        context 'service' do
          before(:each) { params.merge!(service: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_service('foobar').with(
              ensure: 'running',
              enable: true,
            )
          end
        end
        context 'confdir' do
          before(:each) { params.merge!(confdir: '/foo/bar') }
          it { is_expected.to compile }
          it { is_expected.to contain_file('/foo/bar/puppet.conf') }
          it do
            is_expected.to contain_ini_setting(
              'puppet_conf_agent_environment',
            ).with_path('/foo/bar/puppet.conf')
          end
          it do
            is_expected.to contain_ini_setting('puppet_conf_certname').with_path(
              '/foo/bar/puppet.conf',
            )
          end
        end
        context 'puppet_state_dir' do
          before(:each) { params.merge!(puppet_state_dir: '/foo/bar') }
          it { is_expected.to compile }
          it { is_expected.to contain_file('/foo/bar/last_run_summary.yaml') }
        end
        context 'puppet_master' do
          before(:each) { params.merge!(puppet_master: true) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_cron('puppet_conf: check puppetserver').with(
              ensure: 'present',
              command: 'service pe-puppetserver status > /dev/null || service pe-puppetserver restart',
              minute: '10',
            )
          end
          it do
            is_expected.to contain_cron('puppet_conf: check puppetdb').with(
              ensure: 'present',
              command: 'service pe-puppetdb status > /dev/null || service pe-puppetdb restart',
              minute: '20',
            )
          end
          it do
            is_expected.to contain_ini_setting('puppet_master_certname').with(
              section: 'master',
              setting: 'certname',
              value: 'foobar.example.com',
            )
          end
          it do
            is_expected.to contain_augeas('fileserver ca mount').with(
              incl: "#{confdir}/fileserver.conf",
              lens: 'PuppetFileserver.lns',
              load_path: '/opt/puppet/share/augeas/lenses/dist',
              changes: [
                "set /files/#{confdir}/fileserver.conf/hedgehog_ca/path #{environments_path}/hedgehog_ca_master/ca",
                "set /files/#{confdir}/fileserver.conf/hedgehog_ca/allow *",
              ],
            )
          end
        end
        context 'dns_alt_names' do
          before(:each) { params.merge!(dns_alt_names: ['foo', 'bar']) }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting('puppet_dns_alt_names').with(
              setting: 'dns_alt_names',
              value: 'foo,bar',
            )
          end
        end
        context 'hedgehoog_ca_path' do
          before(:each) do
            params.merge!(
              hedgehoog_ca_path: '/foo/bar',
              puppet_master: true,
            )
          end
          it { is_expected.to compile }
          it do
            is_expected.to contain_augeas('fileserver ca mount').with(
              incl: "#{confdir}/fileserver.conf",
              lens: 'PuppetFileserver.lns',
              load_path: '/opt/puppet/share/augeas/lenses/dist',
              changes: [
                "set /files/#{confdir}/fileserver.conf/hedgehog_ca/path /foo/bar",
                "set /files/#{confdir}/fileserver.conf/hedgehog_ca/allow *",
              ],
            )
          end
        end
        context 'environment_override' do
          before(:each) { params.merge!(environment_override: 'foobar') }
          it { is_expected.to compile }
          it do
            is_expected.to contain_ini_setting(
              'puppet_conf_agent_environment',
            ).with(
              setting: 'environment',
              value: 'foobar',
              section: 'agent',
            )
          end
        end
      end
      describe 'check bad type' do
        context 'owner' do
          before(:each) { params.merge!(owner: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'group' do
          before(:each) { params.merge!(group: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'service' do
          before(:each) { params.merge!(service: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'confdir' do
          before(:each) { params.merge!(confdir: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'puppet_state_dir' do
          before(:each) { params.merge!(puppet_state_dir: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'puppet_master' do
          before(:each) { params.merge!(puppet_master: 'foobar') }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'dns_alt_names' do
          before(:each) { params.merge!(dns_alt_names: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'hedgehoog_ca_path' do
          before(:each) { params.merge!(hedgehoog_ca_path: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'enable_nagios' do
          before(:each) { params.merge!(enable_nagios: 'foobar') }
          it { is_expected.to raise_error(Puppet::Error) }
        end
        context 'environment_override' do
          before(:each) { params.merge!(environment_override: true) }
          it { is_expected.to raise_error(Puppet::Error) }
        end
      end
    end
  end
end
