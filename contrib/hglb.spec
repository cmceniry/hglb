# General RPM SPECFILE for hglb

Summary: QuickSilver Load Balancer (hglb) management utilities
Name: hglb
Version: 0.3
Release: 0
License: Simplified BSD License
Vendor: Corgalabs
Group: Applications/System
URL: http://github.com/cmceniry/hglb
Source0: hglb-%{version}.tar.gz
Requires: ruby
Requires: rubygem-net-ssh
Requires: rubygem-net-sftp
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch

%description
The Quicksilver Load Balancer (hglb) management utilities are a suite of tools
for managing a home grown load balancer based on varnish and nginx.

%prep
%setup -q

%build

%check

%install
rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}/usr/sbin/
install -m 0755 src/hglbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/hglbwrapper.rb
ln -s hglbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/hglb-resume
ln -s hglbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/hglb-stats
ln -s hglbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/hglb-status
ln -s hglbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/hglb-suspend
ln -s hglbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/hglb-sync

mkdir -p ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/
install -m 0644 src/lib/hglb.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb.rb
install -m 0755 -d ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb
install -m 0644 src/lib/hglb/configchecker.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb/configchecker.rb
install -m 0644 src/lib/hglb/config.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb/config.rb
install -m 0644 src/lib/hglb/manager.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb/manager.rb
install -m 0644 src/lib/hglb/ssh.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb/ssh.rb
install -m 0644 src/lib/hglb/state.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb/state.rb
install -m 0644 src/lib/hglb/vcltemplate.rb ${RPM_BUILD_ROOT}/usr/lib/ruby/site_ruby/1.8/hglb/vcltemplate.rb

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
/usr/sbin/hglbwrapper.rb
/usr/sbin/hglb-resume
/usr/sbin/hglb-stats
/usr/sbin/hglb-status
/usr/sbin/hglb-suspend
/usr/sbin/hglb-sync
/usr/lib/ruby/site_ruby/1.8/hglb.rb
/usr/lib/ruby/site_ruby/1.8/hglb

%changelog
* Tue Jul 13 2010 Chris McEniry <cmceniry@corgalabs.com> - 0.3-0
- additional backend options can be specified in config (probe, etc)
- force pass on directed server template item
- better (more exact) matching on directed server template item
- basic check for clutername in lb-stats

* Tue Jul 13 2010 Chris McEniry <cmceniry@corgalabs.com> - 0.2-0
- tool prefix rename lb -> hglb

* Mon Jul 12 2010 Chris McEniry <cmceniry@corgalabs.com> - 0.1-0
- Initial release/specfile

