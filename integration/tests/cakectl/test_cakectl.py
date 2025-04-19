import uuid
from time import sleep

import pytest
from paramiko.client import AutoAddPolicy, SSHClient


@pytest.mark.only_tart_present()
def test_clone_with_tart(cakectl):
	linux = f"linux-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.clone("ghcr.io/cirruslabs/ubuntu:24.04", linux)

	# Ensure that the VM was created
	stdout, _ = cakectl.listvm()
	# Clean up the VM
	cakectl.delete(linux)

	assert linux in stdout

def test_create_linux(cakectl):
	linux = f"linux-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.build(linux)

	# Ensure that the VM was created
	stdout, _ = cakectl.listvm()
	# Clean up the VM
	cakectl.delete(linux)

	assert linux in stdout

def test_rename(cakectl):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.build(debian)

	# Rename that VM
	cakectl.rename(debian, ubuntu)

	# Ensure that the VM is now named ubuntu
	stdout, _, = cakectl.listvm()

	cakectl.delete(ubuntu)

	assert ubuntu in stdout

def test_duplicate(cakectl):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.build(debian)

	# Duplicate that VM
	cakectl.duplicate(debian, ubuntu)

	# Ensure that the VM is now named ubuntu
	stdout, _, = cakectl.listvm()

	cakectl.delete(ubuntu)
	cakectl.delete(debian)

	assert debian in stdout
	assert ubuntu in stdout

def test_delete(cakectl):
	vmname = f"vmname-{uuid.uuid4()}"

	# Create an ubuntu VM
	cakectl.build(vmname)

	# Ensure that the VM exists
	stdout, _, = cakectl.listvm()
	assert vmname in stdout

	# Delete the VM
	cakectl.delete(vmname)

	# Ensure that the VM was removed
	stdout, _, = cakectl.listvm()

	assert vmname not in stdout

def test_launch(cakectl):
	vm_name = f"integration-test-run-{uuid.uuid4()}"

	# Instantiate a VM with admin:admin SSH access
	stdout, _ = cakectl.launch(vm_name)
	assert f"VM launched {vm_name} with IP: " in stdout

	stdout, _ = cakectl.stop(vm_name)
	assert f"VM {vm_name} stopped" in stdout

	# Delete the VM
	cakectl.delete(vm_name)

def test_remote(cakectl):
	stdout, _ = cakectl.add_remote("test-remote", "https://images.lxd.canonical.com/")
	assert "test-remote" in stdout

	stdout, _ = cakectl.list_remote()
	assert "test-remote" in stdout

	stdout, _ = cakectl.delete_remote("test-remote")
	assert "test-remote" in stdout

	stdout, _ = cakectl.list_remote()
	assert "test-remote" not in stdout

def test_template(cakectl):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM (because we can create it really fast)
	cakectl.build(debian)

	# Clone the VM
	cakectl.create_template(debian, ubuntu)

	# Ensure that we have new template
	stdout, _, = cakectl.list_template()
	assert ubuntu in stdout

	# Clean up the VM to free disk space
	cakectl.delete(debian)
	stdout, _, = cakectl.listvm()
	assert debian not in stdout

	# Clean up the template to free disk space
	cakectl.delete_template(ubuntu)
	stdout, _, = cakectl.list_template()
	assert ubuntu not in stdout

def test_networks(cakectl):
	network_name = f"test-network-{uuid.uuid4()}-{uuid.uuid4()}"

	cakectl.run(["networks", "create", network_name, "--mode=shared", "--gateway=192.168.106.1", "--dhcp-end=192.168.106.128", "--netmask=255.255.254.0"])
	stdout, _ = cakectl.infos_networks(network_name)
	assert network_name in stdout

	cakectl.start_networks(network_name)
	stdout, _ = cakectl.infos_networks(network_name)
	assert f"{network_name}.sock" in stdout

	sleep(2)

	cakectl.stop_networks(network_name)
	stdout, _ = cakectl.infos_networks(network_name)
	assert "not running" in stdout

	cakectl.delete_networks(network_name)
	stdout, _ = cakectl.list_networks()
	assert network_name not in stdout

def test_exec(cakectl):
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM (because we can create it really fast)
	cakectl.launch(ubuntu)
	stdout, _ = cakectl.exec(ubuntu, ["cat"], input=b"Hello World")
	assert "Hello World" in stdout

	cakectl.stop(ubuntu)
	cakectl.delete(ubuntu)