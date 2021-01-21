package "bash"
package "bash-completion"

directory node[:bash][:rcdir] do
  mode "0755"
end

%w(
  bash_logout
  bashcomp-modules
  bashcomp.sh
  bashrc
  color.sh
  detect.sh
  prompt.sh
).each do |f|
  template "#{node[:bash][:rcdir]}/#{f}" do
    source f
    mode "0644"
  end
end

template "/etc/profile" do
  source "profile"
  owner "root"
  group "root"
  mode "0644"
end

# always use global bashrc for root
%w(.bashrc .bash_profile .bash_logout).each do |f|
  file "/root/#{f}" do
    action :delete
  end
end

# most distributions use /etc/bash.bashrc and /etc/bash.bash_logout but we
# follow the gentoo way of putting these in /etc/bash, so we symlink these
# for compatibility
file "/etc/bash.bashrc" do
  action :delete
  not_if { File.symlink?("/etc/bash.bashrc") }
end

link "/etc/bash.bashrc" do
  to "#{node[:bash][:rcdir]}/bashrc"
end

file "/etc/bash.bash_logout" do
  action :delete
  not_if { File.symlink?("/etc/bash.bash_logout") }
end

link "/etc/bash.bash_logout" do
  to "#{node[:bash][:rcdir]}/bash_logout"
end

# various color fixes for solarized
cookbook_file node[:bash][:dircolors] do
  source "dircolors.ansi-universal"
  mode "0644"
end

cookbook_file node[:bash][:colordiffrc] do
  source "colordiffrc"
  mode "0644"
end

# scripts
%w(
  copy
  grab
  mktar
  urlscript
).each do |f|
  cookbook_file "#{node[:script_path]}/#{f}" do
    source "scripts/#{f}"
    mode "0755"
  end
end
