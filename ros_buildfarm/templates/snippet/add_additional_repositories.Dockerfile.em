@[if os_name == 'ubuntu']@
@{
from itertools import product
}@
@[  if arch in ['amd64', 'i386']]@
@{
archive_commands = []
old_releases_commands = []
for distribution, archive_type in product((os_code_name, os_code_name + '-updates', os_code_name + '-security'), ('deb', 'deb-src')):
    archive_entry = '%s http://archive.ubuntu.com/ubuntu/ %s multiverse' % (archive_type, distribution)
    archive_pattern = '%s http://archive\.ubuntu\.com/ubuntu/? %s ([-a-z]+ )*multiverse( [-a-z])*' % (archive_type, distribution)
    old_releases_entry = '%s http://old-releases.ubuntu.com/ubuntu/ %s multiverse' % (archive_type, distribution)
    old_releases_pattern = '%s http://old-releases\.ubuntu\.com/ubuntu/? %s ([-a-z]+ )*multiverse( [-a-z]+)*' % (archive_type, distribution)
    archive_commands.append('(grep -q -E -x -e "%s" /etc/apt/sources.list || echo "%s" >> /etc/apt/sources.list)' % (archive_pattern, archive_entry))
    old_releases_commands.append('(grep -q -E -x -e "%s" /etc/apt/sources.list || echo "%s" >> /etc/apt/sources.list)' % (old_releases_pattern, old_releases_entry))
}@
RUN grep -q -F -e "deb http://old-releases.ubuntu.com" /etc/apt/sources.list && (@(' && '.join(old_releases_commands))) || (@(' && '.join(archive_commands)))
@[  elif arch in ['armhf', 'armv8']]@
@{
commands = []
for distribution, archive_type in product((os_code_name, os_code_name + '-updates', os_code_name + '-security'), ('deb', 'deb-src')):
    entry = '%s http://ports.ubuntu.com/ %s multiverse' % (archive_type, distribution)
    pattern = '%s http://ports\.ubuntu\.com/? %s ([-a-z]+ )*multiverse( [-a-z])*' % (archive_type, distribution)
    commands.append('(grep -q -E -x -e "%s" /etc/apt/sources.list || echo "%s" >> /etc/apt/sources.list)' % (pattern, entry))
}@
RUN @(' && '.join(commands))
@[  end if]@
@[end if]@
