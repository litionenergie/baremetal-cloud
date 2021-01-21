begin
  require 'yaml'
  require 'pp'
  require 'tempfile'

  namespace :baremetal do

    desc "scan all ISPs for baremetals. You can optional pass a subset of providers, use ':' as separator"
    task :scan_isps, :provider do |t, args|
      baremetals_persist(baremetal_scan_isps(args.provider))
    end

    desc "list all known hosts (use scan_isps to find them)"
    task :list_hosts do |t|
      baremetals.each do |host,config|
        puts "#{host}:\t#{config[:ipv4]}"
      end
    end

    desc "put host into rescue"
    task :rescue, :host do |t, args|
      baremetal_rescue(args.host)
    end

    desc "bootstrap a node"
    task :bootstrap, :host, :disklayout, :install_script do |t, args|
      throw "needs a disklayout" unless args.disklayout
      config = baremetal_by_human_input(args.host)

      baremetal_rescue(args.host)
      remote_sudo(config[:ipv4], %Q{
        . onhost/disklayout/#{args.disklayout}
        . onhost/install/#{args.install_script || 'ubuntu-focal'}
        mkdir ${BAREMETAL_ROOT}/root/.ssh
      }, true)
      scp(config[:ipv4], "#{PRIVATE_SSH_KEY}.pub", "/mnt/baremetal/root/.ssh/authorized_keys", true)
      scp(config[:ipv4], "#{PRIVATE_SSH_KEY}", "/mnt/baremetal/root/.ssh/#{File.basename(PRIVATE_SSH_KEY)}", true)
      scp(config[:ipv4], "#{PRIVATE_SSH_KEY}.pub", "/mnt/baremetal/root/.ssh/#{File.basename(PRIVATE_SSH_KEY)}.pub", true)

      # set correct rights, sshd is picky
      remote_sudo(config[:ipv4], %Q{
        chmod 700 /mnt/baremetal/root/.ssh
        chmod 600 /mnt/baremetal/root/.ssh/#{File.basename(PRIVATE_SSH_KEY)}
        chmod 644 /mnt/baremetal/root/.ssh/#{File.basename(PRIVATE_SSH_KEY)}.pub
        chmod 644 /mnt/baremetal/root/.ssh/authorized_keys
        echo "#{config[:ipv4]} #{config[:id]}" >> /etc/hosts
        hostnamectl set-hostname #{config[:id]}
      }, true)

      # can't use remove_sudo here, as systemd kills the ssh session and that's a fatal error
      sh %Q{ssh #{ssh_opts} root@#{config[:ipv4]} reboot; true}
      wait_for_ssh(config[:ipv4])

      puts "If all went right, your server is ready now"
    end

    desc "install su-chef"
    task :install_su_chef, :host do |t, args|
      config = baremetal_by_human_input(args.host)
      remote_sudo(config[:ipv4], %Q{
        curl -s -L https://www.opscode.com/chef/install.sh -o /root/install-chef.sh
        . /root/install-chef.sh -v 16.9.29 || exit 1
        rm /root/install-chef.sh
        mkdir -p /etc/chef /var/su-chef/cache /var/su-chef/backup
      }, true)

      scp(config[:ipv4], Dir.pwd, "/var/su-chef/", true)

      Tempfile.create do |f|
        f << %Q{
local_mode true
listen false
node_name '#{config[:id]}'

log_location STDOUT
verbose_logging false
enable_reporting false

file_cache_path "/var/lib/su-chef/cache"
file_backup_path "/var/lib/su-chef/backup"

chef_repo_path '/var/su-chef/private'
data_bag_path '/var/su-chef/private/data_bags'
node_path '/var/su-chef/node-cache'
role_path '/var/su-chef/private/roles'

cookbook_path [
  '/var/su-chef/baremetal-cloud/cookbooks',
  '/var/su-chef/private/cookbooks'
]
versioned_cookbooks false

environment 'suchef'
environment_path '/var/su-chef/baremetal-cloud/environments'

chef_license 'accept'
}.lstrip
        f.flush
        scp(config[:ipv4],f.path,'/etc/chef/client.rb',true)
        remote_sudo(config[:ipv4], "chef-client -o bash"}, true)
      end
    end

    desc "select ubuntu kernel to be installed during bootstrap"
    task :select_ubuntu_kernel, :kernel_version do |t, args|
      uri = URI("https://kernel.ubuntu.com/~kernel-ppa/mainline/v#{args.kernel_version}/amd64/")
      debs = Net::HTTP.get(uri).scan(/href=('|")(linux.+(?:all|amd64)\.deb)('|")/).map{|m| m[1]}.select{|deb| !deb.match(/lowlatency/)}.uniq

      raise "No debs foud for #{args.kernel_version}" if debs.length == 0

      kernel_dir = "/root/kernel-#{args.kernel_version}"
      kernel_installer = ERB.new %Q{#!/bin/bash

# install boot loaders
spawn_chroot "DEBIAN_FRONTEND=noninteractive apt-get -y install extlinux grub-efi-amd64"

# fetch and install kernel via ubuntu ppa
mkdir -p /mnt/baremetal<%= kernel_dir %>
cd /mnt/baremetal<%= kernel_dir %>
<% debs.each do |kernel_deb| %>
wget <%= (uri + kernel_deb) %><% end %>
spawn_chroot "dpkg -i <%= kernel_dir %>/*.deb"
}

      File.open('./onhost/setup/ubuntu-kernel', 'w') do |f|
        f.write kernel_installer.result(binding)
      end

    end
  end
rescue LoadError
  $stderr.puts "Baremetal API cannot be loaded. Skipping some rake tasks ..."
end
