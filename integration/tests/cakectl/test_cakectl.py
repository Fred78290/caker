import uuid

import pytest
from paramiko.client import AutoAddPolicy, SSHClient


def test_create_linux(cakectl):
	linux = f"linux-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.run(["build", linux, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Ensure that the VM was created
	stdout, _ = cakectl.run(["list", "--vmonly"])

	# Clean up the VM
	cakectl.run(["delete", linux])

	assert linux in stdout

def test_rename(cakectl):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.run(["build", debian, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Rename that VM
	cakectl.run(["rename", debian, ubuntu])

	# Ensure that the VM is now named ubuntu
	stdout, _, = cakectl.run(["list", "--vmonly"])

	cakectl.run(["delete", ubuntu])

	assert ubuntu in stdout

def test_duplicate(cakectl):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	cakectl.run(["build", debian, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Duplicate that VM
	cakectl.run(["duplicate", debian, ubuntu])

	# Ensure that the VM is now named ubuntu
	stdout, _, = cakectl.run(["list", "--vmonly"])

	cakectl.run(["delete", ubuntu])
	cakectl.run(["delete", debian])

	assert debian in stdout
	assert ubuntu in stdout

def test_delete(cakectl):
	vmname = f"vmname-{uuid.uuid4()}"

	# Create an ubuntu VM
	cakectl.run(["build", vmname, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Ensure that the VM exists
	stdout, _, = cakectl.run(["list", "--vmonly"])
	assert vmname in stdout

	# Delete the VM
	cakectl.run(["delete", vmname])

	# Ensure that the VM was removed
	stdout, _, = cakectl.run(["list", "--vmonly"])

	assert vmname not in stdout

def test_launch(cakectl):
	vm_name = f"integration-test-run-{uuid.uuid4()}"

	# Instantiate a VM with admin:admin SSH access
	cakectl.run(["launch", vm_name, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])
	assert f"VM launched {vm_name} with IP: " in stdout

	stdout, _ = cakectl.run(["stop", vm_name, "--wait", "120"])
	assert f"VM {vm_name} stopped" in stdout

	# Delete the VM
	cakectl.run(["delete", vm_name])

def test_template(cakectl):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM (because we can create it really fast)
	cakectl.run(["build", debian, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Clone the VM
	cakectl.run(["template", "create", debian, ubuntu])

	# Ensure that we have new template
	stdout, _, = cakectl.run(["template", "list"])
	assert ubuntu in stdout

	# Clean up the VM to free disk space
	cakectl.run(["delete", debian])
	stdout, _, = cakectl.run(["list", "--vmonly"])
	assert debian not in stdout

	# Clean up the template to free disk space
	cakectl.run(["template", "delete", ubuntu])
	stdout, _, = cakectl.run(["template", "list"])
	assert ubuntu not in stdout
