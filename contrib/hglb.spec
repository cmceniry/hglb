# General RPM SPECFILE for hglb

Summary: QuickSilver Load Balancer (hglb) management utilities
Name: hglb
Version: 0.1
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
install -m 0755 src/lbwrapper.rb ${RPM_BUILD_ROOT}/usr/sbin/lbwrapper.rb
install src/lb-resume ${RPM_BUILD_ROOT}/usr/sbin/lb-resume
install src/lb-stats ${RPM_BUILD_ROOT}/usr/sbin/lb-stats
install src/lb-status ${RPM_BUILD_ROOT}/usr/sbin/lb-status
install src/lb-suspend ${RPM_BUILD_ROOT}/usr/sbin/lb-suspend
install src/lb-sync ${RPM_BUILD_ROOT}/usr/sbin/lb-sync

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
/usr/sbin/lbwrapper.rb
/usr/sbin/lb-resume
/usr/sbin/lb-stats
/usr/sbin/lb-status
/usr/sbin/lb-suspend
/usr/sbin/lb-sync
/usr/lib/ruby/site_ruby/1.8/hglb.rb
/usr/lib/ruby/site_ruby/1.8/hglb

%changelog
* Mon Jul 12 2010 Chris McEniry <cmceniry@corgalabs.com> - 0.1-0
- Initial release/specfile

