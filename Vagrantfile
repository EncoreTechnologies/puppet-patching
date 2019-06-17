
docker_registry = ENV['DOCKER_REGISTRY']
docker_image = ENV['DOCKER_IMAGE']

dockerfile_path = ENV['DOCKERFILE_PATH'] ? ENV['DOCKERFILE_PATH'] : '.'
dockerfile = ENV['DOCKERFILE'] ? ENV['DOCKERFILE'] : 'Dockerfile'

Vagrant.configure('2') do |config|
  config.vm.synced_folder '.', '/ci_puppet/'

  if docker_image
    config.vm.provider 'docker' do |d|
      docker_image_full = if docker_registry
                            "#{docker_registry}/#{docker_image}"
                          else
                            docker_image
                          end
      # pull container from registry
      d.image = docker_image_full
      # tell the container to stay running, even when /bin/bash exits (default command)
      d.create_args = ['-t']
    end
  else
    config.vm.provider 'docker' do |d|
      # build container from our Dockerfile
      d.build_dir = dockerfile_path
      d.dockerfile = dockerfile
      # tell the container to stay running, even when /bin/bash exits (default command)
      d.create_args = ['-t']
    end
  end

  config.vm.provision 'docker' do |d|
    d.run 'default'
  end
end
