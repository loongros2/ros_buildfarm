@{import os}@
<project>
  <actions/>
  <description>Generated at @ESCAPE(now_str) from template '@ESCAPE(template_name)'@
@[if disabled]
but disabled since the package is blacklisted (or not whitelisted) in the configuration file@
@[end if]@
@ </description>
  <keepDependencies>false</keepDependencies>
  <properties>
@(SNIPPET(
    'property_log-rotator',
    days_to_keep=365,
    num_to_keep=100,
))@
@[if github_url]@
@(SNIPPET(
    'property_github-project',
    project_url=github_url,
))@
@[end if]@
@[if job_priority is not None]@
@(SNIPPET(
    'property_job-priority',
    priority=job_priority,
))@
@[end if]@
@(SNIPPET(
    'property_rebuild-settings',
))@
@(SNIPPET(
    'property_requeue-job',
))@
@(SNIPPET(
    'property_parameters-definition',
    parameters=[
        {
            'type': 'boolean',
            'name': 'force',
            'description': 'Run documentation generation even if neither the source repository nor any of the tools have changes',
        },
        {
            'type': 'boolean',
            'name': 'skip_cleanup',
            'description': 'Skip cleanup of build artifacts',
        },
    ],
))@
@(SNIPPET(
    'property_job-weight',
))@
  </properties>
@(SNIPPET(
    'scm',
    repo_spec=doc_repo_spec,
    path='ws/src/%s' % doc_repo_spec.name,
    git_ssh_credential_id=git_ssh_credential_id,
))@
  <scmCheckoutRetryCount>2</scmCheckoutRetryCount>
  <assignedNode>@(node_label)</assignedNode>
  <canRoam>false</canRoam>
  <disabled>@('true' if disabled else 'false')</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers>
@(SNIPPET(
    'trigger_poll',
    spec='H 3 H/3 * *',
))@
  </triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
@(SNIPPET(
    'builder_system-groovy_check-free-disk-space',
))@
@(SNIPPET(
    'builder_shell_docker-info',
))@
@(SNIPPET(
    'builder_check-docker',
    os_name=os_name,
    os_code_name=os_code_name,
    arch=arch,
))@
@(SNIPPET(
    'builder_shell_clone-ros-buildfarm',
    ros_buildfarm_repository=ros_buildfarm_repository,
    wrapper_scripts=wrapper_scripts,
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'echo "# BEGIN SECTION: Clone rosdoc2"',
        'rm -fr rosdoc2',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/wrapper/git.py clone --depth 1 https://github.com/ros-infrastructure/rosdoc2.git rosdoc2',
        'git -C rosdoc2 log -n 1',
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell_key-files',
    script_generating_key_files=script_generating_key_files,
))@
@{
if doc_repo_spec.type == 'hg':
    hgcache_mount_arg = ' -v $HOME/hgcache:$HOME/hgcache '
else:
    hgcache_mount_arg = ''
}@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'rm -fr $WORKSPACE/docker_generating_docker',
        'mkdir -p $WORKSPACE/docker_generating_docker',
        '',
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_generating_docker/docker.cid > $WORKSPACE/docker_generating_docker/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        '# generate Dockerfile, build and run it',
        '# generating the Dockerfiles for the actual doc task',
        'echo "# BEGIN SECTION: Generate Dockerfile - doc task"',
        'export TZ="%s"' % timezone,
        'export PYTHONPATH=$WORKSPACE/ros_buildfarm:$PYTHONPATH',
        'if [ "$force" = "true" ]; then FORCE_FLAG="--force"; fi',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/doc/run_rosdoc2_job.py' +
        ' ' + os_name +
        ' ' + os_code_name +
        ' ' + arch +
        ' ' + ' '.join(repository_args) +
        ' --env-vars ' + ' '.join([v.replace('$', '\\$',) for v in build_environment_variables]) +
        ' --dockerfile-dir $WORKSPACE/docker_generating_docker',
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - generating doc task"',
        'cd $WORKSPACE/docker_generating_docker',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --force-rm -t rosdoc2_task_generation.%s_%s .' % (rosdistro_name, doc_repo_spec.name.lower()),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - generating doc task"',
        'rm -fr $WORKSPACE/docker_doc',
        'mkdir -p $WORKSPACE/docker_doc',
        '# If using Podman, change the user namespace to preserve UID. No effect if using Docker.',
        'export PODMAN_USERNS=keep-id',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_generating_docker/docker.cid' +
        ' -e=HOME=/home/buildfarm' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        ' -v $WORKSPACE/rosdoc2:/tmp/rosdoc2:ro' +
        ' -v $WORKSPACE/ws:/tmp/ws' +
        ' -v $WORKSPACE/docker_doc:/tmp/docker_doc' +
        hgcache_mount_arg +
        ' rosdoc2_task_generation.%s_%s' % (rosdistro_name, doc_repo_spec.name.lower()),
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'if [ ! -f "$WORKSPACE/docker_doc/Dockerfile" ]; then',
        '  exit 0',
        'fi',
        '',
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_doc/docker.cid > $WORKSPACE/docker_doc/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - doc"',
        '# build and run build_and_install Dockerfile',
        'cd $WORKSPACE/docker_doc',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --force-rm -t rosdoc2.%s_%s .' % (rosdistro_name, doc_repo_spec.name.lower()),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - doc"',
        '# If using Podman, change the user namespace to preserve UID. No effect if using Docker.',
        'export PODMAN_USERNS=keep-id',
        'docker run' +
        ' --rm ' +
        ' --cidfile=$WORKSPACE/docker_doc/docker.cid' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        ' -v $WORKSPACE/rosdoc2:/tmp/rosdoc2' +
        ' -v $WORKSPACE/ws:/tmp/ws' +
        ' rosdoc2.%s_%s' % (rosdistro_name, doc_repo_spec.name.lower()),
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'if [ "$skip_cleanup" = "false" ]; then',
        'echo "# BEGIN SECTION: Clean up to save disk space on agents"',
        'rm -fr rosdoc2',
        'echo "# END SECTION"',
        'fi',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'if [ -d "$WORKSPACE/ws/docs_output" ]; then',
        '  echo "# BEGIN SECTION: rsync API documentation to server"',
        '  cd $WORKSPACE/ws/docs_output',
        '  for pkg_name in $(find . -maxdepth 1 -mindepth 1 -type d); do',
        '    rsync -e ssh --stats -r --delete $pkg_name %s@%s:%s' % \
          (upload_user, upload_host, os.path.join(upload_root, rosdistro_name, 'api')),
        '  done',
        '  echo "# END SECTION"',
        'fi',
    ]),
))@
@(SNIPPET(
    'builder_system-groovy_extract-warnings',
))@
  </builders>
  <publishers>
@[if notify_maintainers]@
@(SNIPPET(
    'publisher_groovy-postbuild_maintainer-notification',
))@
@[end if]@
@(SNIPPET(
    'publisher_mailer',
    recipients=notify_emails,
    dynamic_recipients=maintainer_emails,
    send_to_individuals=notify_committers,
))@
  </publishers>
  <buildWrappers>
@[if timeout_minutes is not None]@
@(SNIPPET(
    'build-wrapper_build-timeout',
    timeout_minutes=timeout_minutes,
))@
@[end if]@
@(SNIPPET(
    'build-wrapper_timestamper',
))@
@(SNIPPET(
    'build-wrapper_ssh-agent',
    credential_ids=[credential_id],
))@
  </buildWrappers>
</project>
