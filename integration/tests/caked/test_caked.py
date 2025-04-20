import random
import sys
import uuid
from time import sleep

import pytest
from paramiko.client import AutoAddPolicy, SSHClient


@pytest.mark.only_tart_present()
def test_clone_with_tart(caked):
	linux = f"linux-{uuid.uuid4()}"

	# Create a Linux VM
	caked.clone("ghcr.io/cirruslabs/ubuntu:24.04", linux)

	# Ensure that the VM was created
	stdout, _ = caked.listvm()
	# Clean up the VM
	caked.delete(linux)

	assert linux in stdout

def test_create_linux(caked):
	linux = f"linux-{uuid.uuid4()}"

	# Create a Linux VM
	caked.build(linux)

	# Ensure that the VM was created
	stdout, _ = caked.listvm()
	# Clean up the VM
	caked.delete(linux)

	assert linux in stdout

def test_rename(caked):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	caked.build(debian)

	# Rename that VM
	caked.rename(debian, ubuntu)

	# Ensure that the VM is now named ubuntu
	stdout, _, = caked.listvm()

	caked.delete(ubuntu)

	assert ubuntu in stdout

def test_duplicate(caked):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	caked.build(debian)

	# Duplicate that VM
	caked.duplicate(debian, ubuntu)

	# Ensure that the VM is now named ubuntu
	stdout, _, = caked.listvm()

	caked.delete(ubuntu)
	caked.delete(debian)

	assert debian in stdout
	assert ubuntu in stdout

def test_delete(caked):
	vmname = f"vmname-{uuid.uuid4()}"

	# Create an ubuntu VM
	caked.build(vmname)

	# Ensure that the VM exists
	stdout, _, = caked.listvm()
	assert vmname in stdout

	# Delete the VM
	caked.delete(vmname)

	# Ensure that the VM was removed
	stdout, _, = caked.listvm()

	assert vmname not in stdout

def test_vmrun(caked):
	vm_name = f"integration-test-run-{uuid.uuid4()}"

	# Instantiate a VM with admin:admin SSH access
	caked.build(vm_name)

	# Run the VM asynchronously
	caked_run_process = caked.run_async(["vmrun", vm_name])

	sleep(2)

	# Obtain the VM's IP
	stdout, _ = caked.waitip(vm_name)
	ip = stdout.strip()

	# Connect to the VM over SSH and shutdown it
	client = SSHClient()
	client.set_missing_host_key_policy(AutoAddPolicy)
	client.connect(ip, username="admin", password="admin")
	client.exec_command("sudo shutdown -h now")

	# Wait for the "caked run" to finish successfully
	caked_run_process.wait()
	assert caked_run_process.returncode == 0

	# Delete the VM
	caked.delete(vm_name)

def test_launch(caked):
	vm_name = f"integration-test-run-{uuid.uuid4()}"

	# Instantiate a VM with admin:admin SSH access
	stdout, _ = caked.launch(vm_name)
	assert f"VM launched {vm_name} with IP: " in stdout

	stdout, _ = caked.stop(vm_name)
	assert f"VM {vm_name} stopped" in stdout

	# Delete the VM
	caked.delete(vm_name)

def test_remote(caked):
	stdout, _ = caked.add_remote("test-remote", "https://images.lxd.canonical.com/")
	assert "test-remote" in stdout

	stdout, _ = caked.list_remote()
	assert "test-remote" in stdout

	stdout, _ = caked.delete_remote("test-remote")
	assert "test-remote" in stdout

	stdout, _ = caked.list_remote()
	assert "test-remote" not in stdout

def test_template(caked):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM (because we can create it really fast)
	caked.build(debian)

	# Clone the VM
	caked.create_template(debian, ubuntu)

	# Ensure that we have new template
	stdout, _, = caked.list_template()
	assert ubuntu in stdout

	# Clean up the VM to free disk space
	caked.delete(debian)
	stdout, _, = caked.listvm()
	assert debian not in stdout

	# Clean up the template to free disk space
	caked.delete_template(ubuntu)
	stdout, _, = caked.list_template()
	assert ubuntu not in stdout

def test_networks(caked):
	network_name = f"test-network-{uuid.uuid4()}-{uuid.uuid4()}"
	random_octet = random.randint(128, 254)

	caked.run(["networks", "create", network_name, "--mode=shared", f"--gateway=192.168.{random_octet}.1", f"--dhcp-end=192.168.{random_octet}.128", "--netmask=255.255.255.0"])
	stdout, _ = caked.infos_networks(network_name)
	assert network_name in stdout

	caked.start_networks(network_name)
	stdout, _ = caked.infos_networks(network_name)
	assert f"{network_name}.sock" in stdout

	sleep(2)

	caked.stop_networks(network_name)
	stdout, _ = caked.infos_networks(network_name)
	assert "not running" in stdout

	caked.delete_networks(network_name)
	stdout, _ = caked.list_networks()
	assert network_name not in stdout

def test_exec(caked):
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM (because we can create it really fast)
	caked.launch(ubuntu)
	stdout, _ = caked.exec(ubuntu, ["cat"], input=b"Hello World")
	assert "Hello World" in stdout

	caked.stop(ubuntu)
	caked.delete(ubuntu)