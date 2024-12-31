@[if 'base_image' in locals()]@
FROM z572/loongros2
@[else]@
@# same logic as in builder_check-docker.xml.em
@[  if arch in ['i386', 'armhf', 'arm64']]@
FROM osrf/@(os_name)_@arch:@os_code_name
@[  else]@
FROM z572/loongros2
@[  end if]@
@[end if]@
@[if vars().get('maintainer_name')]@
LABEL maintainer "@maintainer_name"
@[end if]@
