import logging
import random
import uuid
from time import sleep

import pytest
from caked import Caked
from paramiko.client import AutoAddPolicy, SSHClient

log = logging.getLogger()


class TestCaked:
	@classmethod
	def setup_class(cls):
		cls.caked = Caked()

	@classmethod
	def teardown_class(cls):
		if cls.caked is not None:
			cls.caked.do_cleanup()
			cls.caked = None

	@pytest.mark.only_tart_present()
	def test_clone_with_tart(self):
		linux = f"linux-{uuid.uuid4()}"

		# Create a Linux VM
		TestCaked.caked.clone("ghcr.io/cirruslabs/ubuntu:24.04", linux)

		# Ensure that the VM was created
		stdout, _ = TestCaked.caked.listvm()
		# Clean up the VM
		TestCaked.caked.delete(linux)

		assert linux in stdout

	def test_create_linux(self):
		linux = f"linux-{uuid.uuid4()}"

		# Create a Linux VM
		TestCaked.caked.build(linux)

		# Ensure that the VM was created
		stdout, _ = TestCaked.caked.listvm()
		# Clean up the VM
		TestCaked.caked.delete(linux)

		assert linux in stdout

	def test_rename(self):
		debian = f"debian-{uuid.uuid4()}"
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM
		TestCaked.caked.build(debian)

		# Rename that VM
		TestCaked.caked.rename(debian, ubuntu)

		# Ensure that the VM is now named ubuntu
		stdout, _, = TestCaked.caked.listvm()

		TestCaked.caked.delete(ubuntu)

		assert ubuntu in stdout

	def test_duplicate(self):
		debian = f"debian-{uuid.uuid4()}"
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM
		TestCaked.caked.build(debian)

		# Duplicate that VM
		TestCaked.caked.duplicate(debian, ubuntu)

		# Ensure that the VM is now named ubuntu
		stdout, _, = TestCaked.caked.listvm()

		TestCaked.caked.delete(ubuntu)
		TestCaked.caked.delete(debian)

		assert debian in stdout
		assert ubuntu in stdout

	def test_delete(self):
		vmname = f"vmname-{uuid.uuid4()}"

		# Create an ubuntu VM
		TestCaked.caked.build(vmname)

		# Ensure that the VM exists
		stdout, _, = TestCaked.caked.listvm()
		assert vmname in stdout

		# Delete the VM
		TestCaked.caked.delete(vmname)

		# Ensure that the VM was removed
		stdout, _, = TestCaked.caked.listvm()

		assert vmname not in stdout

	def test_vmrun(self):
		vm_name = f"integration-test-run-{uuid.uuid4()}"

		# Instantiate a VM with admin:admin SSH access
		TestCaked.caked.build(vm_name)

		# Run the VM asynchronously
		caked_run_process = TestCaked.caked.run_async(["vmrun", vm_name])

		sleep(2)

		# Obtain the VM's IP
		stdout, _ = TestCaked.caked.waitip(vm_name)
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
		TestCaked.caked.delete(vm_name)

	def test_launch(self):
		vm_name = f"integration-test-run-{uuid.uuid4()}"

		# Instantiate a VM with admin:admin SSH access
		stdout, _ = TestCaked.caked.launch(vm_name)
		assert f"VM launched {vm_name} with IP: " in stdout

		stdout, _ = TestCaked.caked.stop(vm_name)
		assert f"VM {vm_name} stopped" in stdout

		# Delete the VM
		TestCaked.caked.delete(vm_name)

	def test_remote(self):
		stdout, _ = TestCaked.caked.add_remote("test-remote", "https://images.lxd.canonical.com/")
		assert "test-remote" in stdout

		stdout, _ = TestCaked.caked.list_remote()
		assert "test-remote" in stdout

		stdout, _ = TestCaked.caked.delete_remote("test-remote")
		assert "test-remote" in stdout

		stdout, _ = TestCaked.caked.list_remote()
		assert "test-remote" not in stdout

	def test_template(self):
		debian = f"debian-{uuid.uuid4()}"
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM (because we can create it really fast)
		TestCaked.caked.build(debian)

		# Clone the VM
		TestCaked.caked.create_template(debian, ubuntu)

		# Ensure that we have new template
		stdout, _, = TestCaked.caked.list_template()
		assert ubuntu in stdout

		# Clean up the VM to free disk space
		TestCaked.caked.delete(debian)
		stdout, _, = TestCaked.caked.listvm()
		assert debian not in stdout

		# Clean up the template to free disk space
		TestCaked.caked.delete_template(ubuntu)
		stdout, _, = TestCaked.caked.list_template()
		assert ubuntu not in stdout

	def test_networks(self):
		network_name = f"test-network-{uuid.uuid4()}"
		random_octet = random.randint(128, 254)

		TestCaked.caked.run(["networks", "create", network_name, "--mode=shared", f"--gateway=192.168.{random_octet}.1", f"--dhcp-end=192.168.{random_octet}.128", "--netmask=255.255.255.0"])
		stdout, _ = TestCaked.caked.infos_networks(network_name)
		assert network_name in stdout

		TestCaked.caked.start_networks(network_name)
		stdout, _ = TestCaked.caked.infos_networks(network_name)
		assert ".sock" in stdout

		sleep(2)

		TestCaked.caked.stop_networks(network_name)
		stdout, _ = TestCaked.caked.infos_networks(network_name)
		assert "not running" in stdout

		TestCaked.caked.delete_networks(network_name)
		stdout, _ = TestCaked.caked.list_networks()
		assert network_name not in stdout

	def test_exec(self):
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM (because we can create it really fast)
		TestCaked.caked.launch(ubuntu)
		stdout, _ = TestCaked.caked.exec(ubuntu, ["cat"], input=b"Hello World")
		log.info(stdout)
		assert "Hello World" in stdout

		TestCaked.caked.stop(ubuntu)
		TestCaked.caked.delete(ubuntu)