begin
  require 'yaml'
  require 'pp'

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
        chmod 700 ${BAREMETAL_ROOT}/root/.ssh
      }, true)
      scp(config[:ipv4], "#{PRIVATE_SSH_KEY}.pub", "/mnt/baremetal/root/.ssh/authorized_keys", true)
      sh %Q{ssh #{ssh_opts} root@#{config[:ipv4]} reboot; true}
      wait_for_ssh(config[:ipv4])
      puts "If all went right, your server is ready now"
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
