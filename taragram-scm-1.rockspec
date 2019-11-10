rockspec_format = '3.0'
package = 'taragram'
version = 'scm-1'
description = {
  license = 'MIT',
  homepage = 'https://github.com/un-def/taragram',
  issues_url = 'https://github.com/un-def/taragram/issues',
  maintainer = 'un.def <me@undef.im>',
}
dependencies = {
  'lua >= 5.1',
  'httoolsp >= 0.2.0',
}
source = {
  url = 'git://github.com/un-def/taragram.git',
  branch = 'master',
}
build = {
  type = 'builtin',
  modules = {
    ['taragram'] = 'src/taragram/init.lua',
  },
}
