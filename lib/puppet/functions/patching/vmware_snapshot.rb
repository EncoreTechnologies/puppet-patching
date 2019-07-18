require 'rbvmomi'

Puppet::Functions.create_function(:'patching::vmware_snapshot') do
  dispatch :vmware_snapshot do
    required_param 'Array',   :vm_names
    required_param 'String',  :snapshot_name
    required_param 'String',  :vcenter_host
    required_param 'String',  :vcenter_username
    required_param 'String',  :vcenter_password
    required_param 'String',  :vmware_datacenter
    optional_param 'Boolean', :vcenter_insecure
    optional_param 'String',  :snapshot_description
    optional_param 'Boolean', :snapshot_memory
    optional_param 'Boolean', :snapshot_quiesce
    optional_param 'String',  :action
    return_type 'Array'
  end

  def vmware_snapshot(vm_names,
                      snapshot_name,
                      vcenter_host,
                      vcenter_username,
                      vcenter_password,
                      vmware_datacenter,
                      vcenter_insecure = true,
                      snapshot_description = nil,
                      snapshot_memory = false,
                      snapshot_quiesce = false,
                      action = 'create')
    # Check to make sure a valid action was chosen
    available_actions = ['create', 'delete']
    unless available_actions.include? action
      raise "#{action} is an invalid action. Please choose from create or delete"
    end

    # Compose vCenter credentials
    credentials = {
      host: vcenter_host,
      user: vcenter_username,
      password: vcenter_password,
      insecure: vcenter_insecure,
    }

    # Establish a connection to vCenter
    vim = RbVmomi::VIM.connect credentials

    # Get the vCenter Datacenter that we are interested in
    dc = vim.serviceInstance.find_datacenter(vmware_datacenter)

    unless dc
      raise "Could not find datacenter with name: #{vmware_datacenter}"
    end

    # Get all the VMs in the datacenter
    view_hash = {
      container: dc.vmFolder,
      type:      ['VirtualMachine'],
      recursive: true,
    }
    all_vms = vim.serviceContent.viewManager.CreateContainerView(view_hash).view

    # Create a snapshot for each VM
    snapshot_error = []
    snapshot_tasks = []
    vm_names.each do |vm_name|
      snapshot_error_hash = { 'name' => vm_name, 'status' => false }
      begin
        task_return = nil
        if action == 'create'
          task_return = create_snapshot_on_vm(all_vms, vm_name, snapshot_name, snapshot_description, snapshot_memory, snapshot_quiesce)
        elsif action == 'delete'
          task_return = delete_snapshot_from_vm(all_vms, vm_name, snapshot_name)
        end

        if task_return
          snapshot_tasks.push(task_return)
        else
          snapshot_error_hash['details'] = 'Could not find vm'
        end
      rescue => err
        snapshot_error_hash['details'] = err
      end

      if snapshot_error_hash.key?('details')
        snapshot_error.push(snapshot_error_hash)
      end
    end

    # Wait for all snap shot tasks to finish
    completion_errors = wait_for_completion(snapshot_tasks)

    # Combine any errors that are present
    vmware_error_return = combine_errors(snapshot_error + completion_errors)

    # Return all errors
    vmware_error_return
  end

  def combine_errors(error_list)
    # Combine error lists. If there are multiple errors we will
    # combine the details information
    error_return = []
    error_list.each do |error|
      # Check if error_return already has the vm in it.
      error_item = error_return.select { |h| h['name'] == error['name'] }
      # If it does combine the details
      if !error_item.empty?
        error_item = error_item[0]
        error_item['details'] = "#{error_item['details']}, #{error['details']}"
        error_return.map! { |e| (e['name'] == error['name']) ? error_item : e }
      else
        # Otherwise add to the return
        error_return.push(error)
      end
    end
    error_return
  end

  def create_snapshot_on_vm(all_vms, vm_name, snapshot_name, snapshot_description, snapshot_memory, snapshot_quiesce)
    # Find the VM and create the snapshot. Wait for the snapshot to be created.
    return_value = false
    all_vms.each do |vm|
      next unless vm.name == vm_name

      if vm.snapshot
        snapshots = find_snapshot(vm.snapshot.rootSnapshotList, snapshot_name)

        if snapshots.length == 1
          delete_snapshot_from_vm(all_vms, vm_name, snapshot_name)
        elsif snapshots.length > 1
          raise "There are #{snapshots.length} snapshots with the name #{snapshot_name} please remediate this or choose a different name before continuing"
        end
      end

      begin
        # Create the Snapshot
        snapshot_task = vm.CreateSnapshot_Task(name: snapshot_name, description: snapshot_description, memory: snapshot_memory, quiesce: snapshot_quiesce)
        return_value = snapshot_task
        break
      rescue => err
        raise "Creating snapshot failed with error: #{err}"
      end
    end
    return_value
  end

  def delete_snapshot_from_vm(all_vms, vm_name, snapshot_name)
    # Find the VM and delete the snapshot. Wait for the snapshot delete to finish before continuing
    return_value = false
    all_vms.each do |vm|
      next unless vm.name == vm_name

      # If the VM doesn't have snapshots then exit
      unless vm.snapshot
        return_value = true
        break
      end

      # Find the snapshot to delete
      snapshots = find_snapshot(vm.snapshot.rootSnapshotList, snapshot_name)
      if snapshots.empty?
        return_value = true
        break
      end

      # Delete the last Snapshot
      begin
        snapshot_task = snapshots[-1].RemoveSnapshot_Task(removeChildren: false)
        return_value = snapshot_task
        break
      rescue => err
        raise "Deleting snapshot failed with error: #{err}"
      end
    end

    return_value
  end

  def find_snapshot(snapshot_list, snapshot_name)
    # Find snapshot by name from the list of snapshots on the VM
    snapshot_return = []
    snapshot_list.each do |vm_snapshot|
      if vm_snapshot.name == snapshot_name
        snapshot_return.push(vm_snapshot.snapshot)
      end

      unless vm_snapshot.childSnapshotList.empty?
        # If snapshot has child snapshots then search those also
        snapshot_return += find_snapshot(vm_snapshot.childSnapshotList, snapshot_name)
      end
    end
    snapshot_return
  end

  def wait_for_completion(snapshot_task_list)
    # Make sure all snapshot tasks have been completed
    completion_errors = []
    snapshot_task_list.each do |snapshot_task|
      next unless snapshot_task.is_a?(RbVmomi::VIM::Task)

      begin
        snapshot_task.wait_for_completion
      rescue => err
        completion_errors_hash = {
          'name' => snapshot_task.info.entity.name,
          'status' => false,
          'details' => err,
        }
        completion_errors.push(completion_errors_hash)
      end
    end
    completion_errors
  end
end
