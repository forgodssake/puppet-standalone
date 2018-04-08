class standalone (
  $base_path = undef,
  $puppet_server = undef,
  $root_password,
  $users,
  $group_admin,
  $network_port_knock_ports = undef,
  $network_allowed_networks = undef,
  $cosmetic_ps1 = '[\[\033[01;32m\]\u\[\033[00m\]@\h \[\033[01;34m\]\W\[\033[00m\]]\$ ',
  $cosmetic_ps1_root = '[\[\033[01;31m\]\u\[\033[00m\]@\h \[\033[01;34m\]\W\[\033[00m\]]\$ ',

){
  if $base_path != undef and $puppet_server != undef {
    fail("You can't set base_path and puppet_server at the same time in module ${module_name}")
  }

  if $base_path != undef {
    # Useful script to force a puppet run at any time
    file { '/usr/local/sbin/repuppet':
      mode    => '0750',
      content => template("${module_name}/repuppet_base_path.erb"),
    }
  }

  if $puppet_server != undef {
    # Useful script to force a puppet run at any time
    file { '/usr/local/sbin/repuppet':
      mode    => '0750',
      content => template("${module_name}/repuppet_puppet_server.erb"),
    }
  }

  # User config
  class { '::root':
    password => $root_password,
  }

  if !has_key($users, $group_admin) {
    fail("You need to specify a \$group_admin that exists in \$users")
  }

  $users.each |String $group, Hash $g_users| {
    group { $group: ensure => present}

    $user_group = $group ? {
      $group_admin => [ $group,  'wheel'],
      default => $group,
    }

    $g_users.each |String $user, Hash $u_data| {
      user { $user:
        groups   => $user_group,
        home     => "/home/${user}",
        shell    => '/bin/bash',
        password => $u_data['password'],
        purge_ssh_keys => true,
        managehome => true,
      }

      ssh_authorized_key { $u_data['email']:
        ensure => present,
        user   => $user,
        type   => 'ssh-rsa',
        key    => $u_data['ssh_key'],
      }

    }
  }


  # Cosmetic configs
  class { '::cosmetic::bash':
    ps1      => $cosmetic_ps1,
    ps1_root => $cosmetic_ps1_root,
  }

  include '::cosmetic::vimrc'

  # Network

  if ($network_port_knock_ports == undef or size($network_port_knock_ports) != 3) and $network_allowed_networks == undef {
    fail('You should configure $network_port_knock_ports or $network_allowed_networks so you are able to access the server')
  }

  class { '::rhel::firewall':
    src_ssh => $network_allowed_networks,
  }

  if $network_port_knock_ports != undef and size($network_port_knock_ports) == 3 {
    rhel::firewall::portknock { 'SSH':
      port1  => $network_port_knock_ports[0],
      port2  => $network_port_knock_ports[1],
      port3  => $network_port_knock_ports[2],
      dports => [ '22' ],
      seconds_open => '20',
    }
  }
}
