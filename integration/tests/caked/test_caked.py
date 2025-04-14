import sys
import uuid
from time import sleep

import pytest
from paramiko.client import AutoAddPolicy, SSHClient


def test_create_linux(caked):
	linux = f"linux-{uuid.uuid4()}"

	# Create a Linux VM
	caked.run(["build", linux, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Ensure that the VM was created
	stdout, _ = caked.run(["list", "--vmonly"])
	# Clean up the VM
	caked.run(["delete", linux])

	assert linux in stdout

def test_rename(caked):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	caked.run(["build", debian, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Rename that VM
	caked.run(["rename", debian, ubuntu])

	# Ensure that the VM is now named ubuntu
	stdout, _, = caked.run(["list", "--vmonly"])

	caked.run(["delete", ubuntu])

	assert ubuntu in stdout

def test_duplicate(caked):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM
	caked.run(["build", debian, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Duplicate that VM
	caked.run(["duplicate", debian, ubuntu])

	# Ensure that the VM is now named ubuntu
	stdout, _, = caked.run(["list", "--vmonly"])

	caked.run(["delete", ubuntu])
	caked.run(["delete", debian])

	assert debian in stdout
	assert ubuntu in stdout

def test_delete(caked):
	vmname = f"vmname-{uuid.uuid4()}"

	# Create an ubuntu VM
	caked.run(["build", vmname, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Ensure that the VM exists
	stdout, _, = caked.run(["list", "--vmonly"])
	assert vmname in stdout

	# Delete the VM
	caked.run(["delete", vmname])

	# Ensure that the VM was removed
	stdout, _, = caked.run(["list", "--vmonly"])

	assert vmname not in stdout

def test_vmrun(caked):
	vm_name = f"integration-test-run-{uuid.uuid4()}"

	# Instantiate a VM with admin:admin SSH access
	caked.run(["build", vm_name, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Run the VM asynchronously
	caked_run_process = caked.run_async(["vmrun", vm_name])

	sleep(2)

	# Obtain the VM's IP
	stdout, _ = caked.run(["waitip", vm_name, "--wait", "120"])
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
	caked.run(["delete", vm_name])

def test_launch(caked):
	vm_name = f"integration-test-run-{uuid.uuid4()}"

	# Instantiate a VM with admin:admin SSH access
	stdout, _ = caked.run(["launch", vm_name, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])
	assert f"VM launched {vm_name} with IP: " in stdout

	stdout, _ = caked.run(["stop", vm_name])
	assert f"VM {vm_name} stopped" in stdout

	# Delete the VM
	caked.run(["delete", vm_name])

def test_template(caked):
	debian = f"debian-{uuid.uuid4()}"
	ubuntu = f"ubuntu-{uuid.uuid4()}"

	# Create a Linux VM (because we can create it really fast)
	caked.run(["build", debian, "--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20", "--nested"])

	# Clone the VM
	caked.run(["template", "create", debian, ubuntu])

	# Ensure that we have new template
	stdout, _, = caked.run(["template", "list"])
	assert ubuntu in stdout

	# Clean up the VM to free disk space
	caked.run(["delete", debian])
	stdout, _, = caked.run(["list", "--vmonly"])
	assert debian not in stdout

	# Clean up the template to free disk space
	caked.run(["template", "delete", ubuntu])
	stdout, _, = caked.run(["template", "list"])
	assert ubuntu not in stdout
