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
    days_to_keep=730,
    num_to_keep=30,
))@
@(SNIPPET(
    'property_github-project',
    project_url=github_url,
))@
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
    'scm_null',
))@
  <assignedNode>@(node_label)</assignedNode>
  <canRoam>false</canRoam>
  <disabled>@('true' if disabled else 'false')</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>true</blockBuildWhenUpstreamBuilding>
  <triggers>
@[if upstream_projects]@
@(SNIPPET(
    'trigger_reverse-build',
    upstream_projects=upstream_projects,
))@
@[end if]@
  </triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
@(SNIPPET(
    'builder_system-groovy_verify-upstream',
))@
@(SNIPPET(
    'builder_system-groovy_check-free-disk-space',
))@
@(SNIPPET(
    'builder_system-groovy_check-for-re-queue',
))@
@(SNIPPET(
    'builder_shell_docker-info',
))@
@(SNIPPET(
    'builder_check-docker',
    os_name={'rhel': 'almalinux'}.get(os_name, os_name),
    os_code_name=os_code_name,
    arch=arch,
))@
@(SNIPPET(
    'builder_shell_clone-ros-buildfarm',
    ros_buildfarm_repository=ros_buildfarm_repository,
    wrapper_scripts=wrapper_scripts,
))@
@(SNIPPET(
    'builder_shell_key-files',
    script_generating_key_files=script_generating_key_files,
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'rm -fr $WORKSPACE/docker_binaryrpm',
        'mkdir -p $WORKSPACE/docker_binaryrpm',
        '',
        '# monitor all subprocesses and enforce termination',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/subprocess_reaper.py $$ --cid-file $WORKSPACE/docker_binaryrpm/docker.cid > $WORKSPACE/docker_binaryrpm/subprocess_reaper.log 2>&1 &',
        '# sleep to give python time to startup',
        'sleep 1',
        '',
        '# generate Dockerfile, build and run it',
        '# generating the Dockerfile for the actual binaryrpm task',
        'echo "# BEGIN SECTION: Generate Dockerfile - binaryrpm task"',
        'export TZ="%s"' % timezone,
        'export PYTHONPATH=$WORKSPACE/ros_buildfarm:$PYTHONPATH',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/release/rpm/run_binarypkg_job.py' +
        ' --rosdistro-index-url ' + rosdistro_index_url +
        ' ' + rosdistro_name +
        ' ' + pkg_name +
        ' ' + os_name +
        ' ' + os_code_name +
        ' ' + arch +
        ' ' + ' '.join(repository_args) +
        ' --dockerfile-dir $WORKSPACE/docker_binaryrpm' +
        ' --binarypkg-dir /tmp/binarypkg' +
        ' --env-vars ' + ' '.join(build_environment_variables) +
        (' --append-timestamp' if append_timestamp else '') +
        (' --skip-tests' if skip_tests else '') +
        ((' --skip-rosdep-keys ' + ' '.join(skip_rosdep_keys)) if skip_rosdep_keys else ''),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Build Dockerfile - build binaryrpm"',
        'cd $WORKSPACE/docker_binaryrpm',
        'python3 -u $WORKSPACE/ros_buildfarm/scripts/misc/docker_pull_baseimage.py',
        'docker build --cap-add=SYS_ADMIN --force-rm --net=host -t binaryrpm.%s_%s_%s_%s_%s .' % (rosdistro_name, os_name, os_code_name, arch, pkg_name),
        'echo "# END SECTION"',
        '',
        'echo "# BEGIN SECTION: Run Dockerfile - build binaryrpm"',
        'rm -fr $WORKSPACE/binarypkg',
        'mkdir -p $WORKSPACE/binarypkg/source',
    ] + ([
        'if [ ! -d "$HOME/.ccache" ]; then mkdir $HOME/.ccache; fi',
    ] if shared_ccache else []) + [
        'docker run' +
        ' --rm' +
        ' --cap-add=SYS_ADMIN' +
        ' --cidfile=$WORKSPACE/docker_binaryrpm/docker.cid' +
        ' -e=TRAVIS=$TRAVIS' +
        ' --net=host' +
        ' -v $WORKSPACE/ros_buildfarm:/tmp/ros_buildfarm:ro' +
        ' -v $WORKSPACE/binarypkg:/tmp/binarypkg' +
        (' -v $HOME/.ccache:/home/buildfarm/.ccache' if shared_ccache else '') +
        ' binaryrpm.%s_%s_%s_%s_%s' % (rosdistro_name, os_name, os_code_name, arch, pkg_name),
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'echo "# BEGIN SECTION: Upload binaryrpm"',
        'find binarypkg -mindepth 1 -maxdepth 1 -type f -name "*.rpm" -not -name "*.src.rpm" -fprint binarypkg/rpm_upload_args.txt -fprintf binarypkg/rpm_import_args.txt "--import=/tmp/upload-${BUILD_TAG}/%f\\n"',
        'ssh %s -- mkdir -p /tmp/upload-${BUILD_TAG}/' % (upload_host,),
        'xargs -a binarypkg/rpm_upload_args.txt -I @ scp @ %s:/tmp/upload-${BUILD_TAG}/' % (upload_host,),
        'xargs -a binarypkg/rpm_import_args.txt ssh %s -- createrepo-agent /var/repos/%s/building/%s/ --arch %s --invalidate-family --invalidate-dependants' % (upload_host, os_name, os_code_name, arch),
        'ssh %s -- rm -fr /tmp/upload-${BUILD_TAG}/' % (upload_host,),
        'echo "# END SECTION"',
    ]),
))@
@(SNIPPET(
    'builder_shell',
    script='\n'.join([
        'if [ "$skip_cleanup" = "false" ]; then',
        'echo "# BEGIN SECTION: Clean up to save disk space on agents"',
        'rm -f binarypkg/*.rpm binarypkg/source/*.rpm',
        'echo "# END SECTION"',
        'fi',
    ]),
))@
  </builders>
  <publishers>
@(SNIPPET(
    'publisher_build-trigger',
    child_projects=child_projects,
))@
@(SNIPPET(
    'publisher_description-setter',
    regexp=r"Package '[^']+' version: (\S+)",
    # to prevent overwriting the description of failed builds
    regexp_for_failed='ThisRegExpShouldNeverMatch',
))@
@[if notify_maintainers]@
@(SNIPPET(
    'publisher_groovy-postbuild_maintainer-notification',
))@
@[end if]@
@(SNIPPET(
    'publisher_mailer',
    recipients=notify_emails,
    dynamic_recipients=maintainer_emails,
    send_to_individuals=False,
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
