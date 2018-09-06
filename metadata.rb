name 'terminator'
maintainer 'Atex Managed Services'
maintainer_email 'managed-services@atex.com'
license 'All Rights Reserved'
description 'Terminates servers based on disk %.'
version '1.0.0'
chef_version '>= 12.1' if respond_to?(:chef_version)

depends 'aws'
depends 'wait_for'
