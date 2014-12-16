name             'base'
maintainer       'Maciej Kruk'
maintainer_email ''
license          'All rights reserved'
description      'Configures organization servers'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends "ntp"
depends "apt"
depends "rvm"
depends "nginx"
depends "logrotate"
