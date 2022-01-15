plan k3s_worker_provisioning (
  TargetSpec $host_group,
) {
  # Run the Apply Prep
  apply_prep([$host_group])
  apply_prep(['control_plane_nodes'])

  # Identify what all of the VM Hostnames should be
  $worker_hosts = get_targets($host_group).map|$value|{$value.name}

  # Fetch the K3s Join Passkey
  apply(
    ['control_plane_nodes'[0]],
    _catch_errors => true,
    _run_as => root,
  ) {
    exec { 'get_k3s_token':
      command => '/usr/bin/cat /var/lib/rancher/k3s/server/token'
    }
  }

  # Provision the K3s Node
  apply(
    [$host_group],
    _catch_errors => true,
    _run_as => root,
  ) {

    # Load Variables
    $k3s_version  = lookup('workers.k3s_version')

    # Create the K3s Directories
    $k3s_directories = [
      '/etc/rancher',
      '/etc/rancher/k3s',
    ]

    $worker_hosts.each |Integer $index, String $hostname| {
      exec { 'set_hostname':
        command => "/usr/bin/hostnamectl set-hostname --static ${hostname}"
      }
    }

    file { $k3s_directories:
      ensure => 'directory',
    }

    # Set up the K3s Service
    file { '/etc/systemd/system/k3s-node.service':
      source  => 'puppet:///modules/k3s_worker_provisioning/k3s-node.service',
      mode    => '0644',
      require => File[$k3s_directories],
    }

    exec {'reload_systemd_daemon':
      command => '/usr/bin/systemctl daemon-reload',
      require => File['/etc/systemd/system/k3s-node.service']
    }

    file { 'download k3s binary':
      path   => '/usr/local/bin/k3s',
      source => "https://github.com/k3s-io/k3s/releases/download/v${ k3s_version }%2Bk3s1/k3s",
      mode   => '0740',
    }

    # service { 'enable-k3s-node-service':
    #   name    => 'k3s-node',
    #   # ensure  => 'running',
    #   enable  => true,
    #   require => File['/etc/systemd/system/k3s-node.service'],
    # }
  }
}
