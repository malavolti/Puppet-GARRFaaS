class jagger::prerequisites(
  $rootpw           = 'puppetsecret',
  $rr3password      = 'rr3secret',
  $gearmand_version = '1.1.12',
  $install_signer   = false,
  $logo_url         = 'http://federation-webpage.com/logo.png',
) {
  
  # Install mysql-server and set the root's password to access it
  class { 'mysql::server':
    	root_password => $rootpw
  }
  
  apache::mod { 'rewrite': }
  apache::mod { 'unique_id': }
  
  # Install requested packages
  package { [
    'php5', 'php-apc', 'php5-cli', 'php5-dev', 'php-pear', 'php5-curl',
    'php5-mysql', 'php5-mcrypt', 'php5-memcached', 'build-essential',
    'gearman-job-server', 'memcached', 'libboost-all-dev', 'gperf',
    'libevent-dev', 'uuid-dev', 'libcloog-ppl-dev']:
    ensure => installed,
  }
  
  augeas { "max_execution_time":
    context => "/files/etc/php5/apache2/php.ini",
    changes => 'set PHP/max_execution_time 600',
    onlyif  => "get PHP/max_execution_time != 600",
    require => Package['libapache2-mod-php5'];
  }
  
  # Install java (this operation also performs apt-get updated needed by further packages)
  include shib2common::java::package
  # include shib2common::java::download
  $java_home = $shib2common::java::params::java_home
  
  download_file {
    "/usr/local/src/gearmand-${gearmand_version}":
      url             => "https://launchpad.net/gearmand/1.2/${gearmand_version}/+download/gearmand-${gearmand_version}.tar.gz",
      extract         => 'tar.gz';
  
    '/opt/rr3/images/Federation-Logo.png':
      url             => $logo_url,
      execute_command => '/bin/chown www-data /opt/rr3/images/Federation-Logo.png',
      require         => Exec['install rr3'];
  }
    
  exec {
    'configure gearmand':
      command => 'sh configure',
      cwd     => "/usr/local/src/gearmand-${gearmand_version}",
      require => [Package['build-essential'], Download_file["/usr/local/src/gearmand-${gearmand_version}"]],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ["/usr/local/src/gearmand-${gearmand_version}/Makefile"];
                  
    'make gearmand':
      command => 'make',
      cwd     => "/usr/local/src/gearmand-${gearmand_version}",
      require => Exec['configure gearmand'],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      timeout => 1800,
      creates => ["/usr/local/src/gearmand-${gearmand_version}/bin/gearman",
                  "/usr/local/src/gearmand-${gearmand_version}/bin/gearman.o"];
                  
    'install gearmand':
      command => 'make install',
      cwd     => "/usr/local/src/gearmand-${gearmand_version}",
      require => Exec['make gearmand'],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ['/usr/local/sbin/gearmand', '/usr/local/bin/gearman',
                  '/usr/local/include/libgearman-1.0', '/usr/local/include/libgearman',
                  '/usr/local/lib/libgearman.a', '/usr/local/lib/libgearman.so', '/usr/local/lib/pkgconfig/gearmand.pc',
                  '/usr/local/lib/libgearman.so.8', '/usr/local/lib/libgearman.so.8.0.0', '/usr/local/lib/libgearman.la'];
                  
    'pecl install gearman':
      command => 'pecl install gearman',
      cwd     => "/usr/local/src/gearmand-${gearmand_version}",
      require => [Package['php5', 'php-pear', 'php5-dev'], Exec['install gearmand']],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ['/usr/lib/php5/20090626/gearman.so'];
      
    'gitclone rr3-addons':
      command => 'git clone https://github.com/janul/rr3-addons.git',
      cwd     => "/opt",
      require => Package['git'],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ['/opt/rr3-addons'];
      
    'gitclone codeigniter':
      command => 'git clone https://github.com/EllisLab/CodeIgniter.git /opt/codeigniter',
      cwd     => "/opt",
      timeout => 1800,
      require => Package['git'],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ['/opt/codeigniter'];
      
    'change branch codeigniter':
      command => 'git checkout -b release/3.0 origin/release/3.0',
      cwd     => "/opt/codeigniter",
      require => [Package['git'], Exec['gitclone codeigniter']],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      unless  => 'git branch | grep "* release/3.0"';
      
    'gitclone rr3':
      command => 'git clone https://github.com/Edugate/ResourceRegistry.git /opt/rr3',
      cwd     => "/opt",
      require => Package['git'],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ['/opt/rr3'];
      
    'copy index.php':
      command => 'cp /opt/codeigniter/index.php /opt/rr3/',
      cwd     => "/opt",
      require => Exec['gitclone rr3'],
      path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      creates => ['/opt/rr3/index.php'];
        
    'install rr3':
      command => "sh install.sh",
      cwd     => "/opt/rr3",
      path    => ["/bin", "/usr/bin"],
      creates => ['/opt/rr3/application/libraries/Doctrine', '/opt/rr3/application/libraries/Zend', '/opt/rr3/application/libraries/geshi'],
      require => Exec['gitclone rr3'];
  }
  
  file {
    '/etc/php5/conf.d/gearman.ini':
      ensure  => file,
      owner   => "root",
      group   => "root",
      mode    => "0644",
      content => "extension=gearman.so",
      require => Package['php5', 'php-pear', 'php5-dev'],
      notify  => Service['httpd'];
    
    '/etc/init.d/gearman-workers':
      ensure  => link,
      target  => '/opt/rr3-addons/gearman-workers/gearman-workers',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => Exec['gitclone rr3-addons'];
      
    '/var/run/gworker':
      ensure  => directory,
      owner   => "root",
      group   => "root",
      mode    => "0755";

    '/opt/rr3/signed-metadata':
      ensure  => directory,
      owner   => "root",
      group   => "root",
      mode    => "0755",
      require => Exec['gitclone rr3'];
      
    '/etc/apache2/sites-available/registry-ssl.conf':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => [join(['   Alias /rr3 /opt/rr3',
                        '',
                        '   <Location /rr3/auth/fedauth>',
                        '            Options -Indexes FollowSymLinks MultiViews',
                        '            Order allow,deny',
                        '            Allow from all',
                        '            AuthType shibboleth',
                        '            ShibRequireSession On',
                        '            Require valid-user',
                        '   </Location>',
                        '',
                        '   <Location /rr3/index.php/auth/fedauth>',
                        '            Options -Indexes FollowSymLinks MultiViews',
                        '            Order allow,deny',
                        '            Allow from all',
                        '            AuthType shibboleth',
                        '            ShibRequireSession On',
                        '            Require valid-user',
                        '   </Location>'], "\n")],
      require => Apache::Mod['shib'],
      notify  => Exec['shib2-apache-restart'];

    '/etc/apache2/sites-enabled/registry-ssl.conf':
      ensure  => link,
      target  => '/etc/apache2/sites-available/registry-ssl.conf',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File['/etc/apache2/sites-available/registry-ssl.conf'],
      notify  => Exec['shib2-apache-restart'];
      
    '/etc/apache2/conf.d/registry.conf':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => [join(['<Directory /opt/rr3>',
                        '        Options FollowSymLinks',
                        '',
                        '        RewriteEngine On',
                        '        RewriteBase /rr3',
                        '        RewriteCond $1 !^(Shibboleth\.sso|index\.php|logos|signedmetadata|flags|images|app|schemas|fonts|styles|images|js|robots\.txt|pub|includes)',
                        '        RewriteRule  ^(.*)$ /rr3/index.php?/$1 [L]',
                        '</Directory>'], "\n")],
      require => Apache::Mod['shib', 'rewrite'],
      notify  => Exec['shib2-apache-restart'];
      
    '/opt/rr3/application/cache':
      owner   => 'www-data',
      require => Exec['gitclone rr3'];
      
    '/opt/rr3/application/models/Proxies':
      owner   => 'www-data',
      require => Exec['gitclone rr3'];
  }
  
  mysql_database { 'rr3':
    ensure  => 'present',
  }

	mysql_user { 'rr3user@localhost':
	  ensure        => 'present',
	  password_hash => mysql_password($rr3password),
    #provider      => 'mysql',
    require       => Mysql_database['rr3'],
	}
	
	mysql_grant { 'rr3user@localhost/rr3.*':
	  privileges => 'ALL',
	  #provider   => 'mysql',
	  user       => 'rr3user@localhost',
	  table      => 'rr3.*',
	  require    => Mysql_user['rr3user@localhost'],
	}
	
	modifyfilelines {
    'modify index.php system_path':
      modifyname => 'system_path',
      filename   => 'index.php',
      filepath   => '/opt/rr3',
      search     => 'system_path = \'system\'',
      replace    => 'system_path = \'\\/opt\\/codeigniter\\/system\'',
      require    => Exec['copy index.php'];
        
    'modify php.ini memory_limit':
      modifyname => 'memory_limit',
      filename   => 'php.ini',
      filepath   => '/etc/php5/apache2',
      search     => 'memory_limit = 128M',
      replace    => 'memory_limit = 256M',
      require    => [Package['php5', 'php-pear', 'php5-dev'], Exec['copy index.php']];
        
    'modify php.ini max_execution_time':
      modifyname => 'max_execution_time',
      filename   => 'php.ini',
      filepath   => '/etc/php5/apache2',
      search     => 'max_execution_time = 30',
      replace    => 'max_execution_time = 60',
      require    => [Package['php5', 'php-pear', 'php5-dev'], Exec['copy index.php']];
  }
  
  if ($install_signer) {
    file {
      '/opt/md-signer':
        ensure  => directory,
        owner   => "root",
        group   => "root",
        mode    => "0755";
      
      '/opt/md-signer/metadata-signer.crt':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => "puppet:///modules/jagger/certs/${hostname}-metadata-signer.crt",
        require => File['/opt/md-signer'];

      '/opt/md-signer/metadata-signer.key':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        source  => "puppet:///modules/jagger/certs/${hostname}-metadata-signer.key",
        require => File['/opt/md-signer'];
    }
    
    download_file { '/opt/xmlsectool-1.2.0':
      url             => 'http://shibboleth.net/downloads/tools/xmlsectool/latest/xmlsectool-1.2.0-bin.zip',
      extract         => 'zip',
    }

    modifyfilelines {
	    'modify gearman-workers':
	        filename   => 'gearman-workers',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'ARGS=\"\\/PATH\\/gearman-worker-metasigner.py\"',
	        replace    => 'ARGS=\"\\/opt\\/rr3-addons\\/gearman-workers\\/gearman-worker-metasigner.py\"',
	        require    => File['/etc/init.d/gearman-workers'];
	
	      'modify gearman-worker-metasigner.py java-home':
	        modifyname => 'java-home',
	        filename   => 'gearman-worker-metasigner.py',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'java-6-sun',
	        replace    => $shib2common::java::params::java_dir_name,
	        require    => Exec['gitclone rr3-addons'];
	        
	      'modify gearman-worker-metasigner.py xmlsecommand':
	        modifyname => 'xmlsecommand',
	        filename   => 'gearman-worker-metasigner.py',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'xmlsecommand = \"PATH\\/xmlsectool.sh\"',
	        replace    => 'xmlsecommand = \"\\/opt\\/xmlsectool-1.2.0\\/xmlsectool.sh\"',
	        require    => Exec['gitclone rr3-addons'];
	        
	      'modify gearman-worker-metasigner.py cert':
	        modifyname => 'cert',
	        filename   => 'gearman-worker-metasigner.py',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'cert=\"CERTPATH\\/metadata-signer.crt\"',
	        replace    => 'cert=\"\\/opt\\/md-signer\\/metadata-signer.crt\"',
	        require    => Exec['gitclone rr3-addons'];
	        
	      'modify gearman-worker-metasigner.py certkey':
	        modifyname => 'certkey',
	        filename   => 'gearman-worker-metasigner.py',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'certkey=\"CERTKEYPATH\\/metadata-signer.key\"',
	        replace    => 'certkey=\"\\/opt\\/md-signer\\/metadata-signer.key\"',
	        require    => Exec['gitclone rr3-addons'];
	        
	      'modify gearman-worker-metasigner.py certpass':
	        modifyname => 'certpass',
	        filename   => 'gearman-worker-metasigner.py',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'cerpass=\"CERTPASS\"',
	        replace    => 'cerpass=\"\"',
	        require    => Exec['gitclone rr3-addons'];
	        
	      'modify gearman-worker-metasigner.py destination':
	        modifyname => 'destination',
	        filename   => 'gearman-worker-metasigner.py',
	        filepath   => '/opt/rr3-addons/gearman-workers',
	        search     => 'destination=\"PATH_TO_RR3_FOLDER\\/signedmetadata\"',
	        replace    => 'destination=\"\\/opt\\/rr3\\/signed-metadata\"',
	        require    => Exec['gitclone rr3-addons'];
    }
  }
}
