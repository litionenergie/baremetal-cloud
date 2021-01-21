require 'tmpdir'

def check_ping(ipaddress)
  %x(ping -c 1 -W 5 #{ipaddress})
  reachable = $?.exitstatus == 0
  sleep(1)
  reachable
end

def wait_with_ping(ipaddress, reachable)
  print "waiting for machine to #{reachable ? "boot" : "shutdown"} "

  while check_ping(ipaddress) != reachable
    print "."
  end

  print "\n"
end

def ssh_detect(host)
  File.chmod(0400, PRIVATE_SSH_KEY) # for good measure
  ssh_opts = %{-oBatchMode=yes -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -o "GlobalKnownHostsFile /dev/null" #{host[:ipv4]} hostname -f 2>/dev/null}

  unless check_ping(host[:ipv4])
    host[:down] = true
    return
  end

  %x{nmap -p 22 -sT -Pn #{host[:ipv4]}| grep 'open  ssh'}
  unless $?.success?
    host[:down] = true
    return
  end

  host.delete(:down)

  fqdn = %x{ssh #{ssh_opts}}.chomp
  if $?.success?
    host[:fqdn] = fqdn
    return
  end

  fqdn = %x{ssh -l root -i #{PRIVATE_SSH_KEY} #{ssh_opts}}.chomp
  if $?.success?
    host[:rescue] = true
    return
  end
end

def wait_for_ssh(fqdn)
  wait_with_ping(fqdn, false)
  wait_with_ping(fqdn, true)
  print "waiting for ssh to be accessible "
  loop do
    print "."
    system("nmap -p 22 -sT #{fqdn} | grep 'open  ssh' &> /dev/null")
    break if $?.exitstatus == 0
    sleep 5
  end
  print "\n"
  sleep 5
end

def remote_sudo(fqdn, command, root = false)
  cmd_file = File.join(Dir.tmpdir(), "baremetal-#{fqdn}-#{Time.now.to_f}")
  File.write(cmd_file, command)
  sh %W{
    cat #{cmd_file} | ssh
    #{root ? '-l root ' : ''}
    #{ssh_opts(root)}
    #{fqdn}
    #{root ? '' : 'sudo '}
    /bin/bash -l -s
  }.join(' ')
end

def scp(fqdn, path, remote_path, root = false)
  command = "scp #{File.directory?(path) ? '-r' : ''} #{ssh_opts(root)} #{path} #{(root ? 'root@' : '')}#{fqdn}:#{remote_path}"
  sh command
end

def ssh_opts(root = true)
  opts = %w{
    -oStrictHostKeyChecking=no
    -oUserKnownHostsFile=/dev/null
    -oGlobalKnownHostsFile=/dev/null
  }
  opts.push("-i #{PRIVATE_SSH_KEY}") if root
  opts.join(' ')
end
