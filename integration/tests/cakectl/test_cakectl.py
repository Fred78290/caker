import os
import random
import uuid
from time import sleep

import pytest
from cakectl import CakeCtl
from paramiko.client import AutoAddPolicy, SSHClient


class TestCakeCtl:
	@classmethod
	def setup_class(cls):
		cls.cakectl = CakeCtl()

	@classmethod
	def teardown_class(cls):
		if cls.cakectl is not None:
			cls.cakectl.do_cleanup()
			cls.cakectl = None

	@pytest.mark.only_tart_present()
	def test_clone_with_tart(self):
		linux = f"linux-{uuid.uuid4()}"

		# Create a Linux VM
		TestCakeCtl.cakectl.clone("ghcr.io/cirruslabs/ubuntu:24.04", linux)

		# Ensure that the VM was created
		stdout, _ = TestCakeCtl.cakectl.listvm()
		# Clean up the VM
		TestCakeCtl.cakectl.delete(linux)

		assert linux in stdout

	def test_create_linux(self):
		linux = f"linux-{uuid.uuid4()}"

		# Create a Linux VM
		TestCakeCtl.cakectl.build(linux)

		# Ensure that the VM was created
		stdout, _ = TestCakeCtl.cakectl.listvm()
		# Clean up the VM
		TestCakeCtl.cakectl.delete(linux)

		assert linux in stdout

	def test_rename(self):
		debian = f"debian-{uuid.uuid4()}"
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM
		TestCakeCtl.cakectl.build(debian)

		# Rename that VM
		TestCakeCtl.cakectl.rename(debian, ubuntu)

		# Ensure that the VM is now named ubuntu
		stdout, _, = TestCakeCtl.cakectl.listvm()

		TestCakeCtl.cakectl.delete(ubuntu)

		assert ubuntu in stdout

	def test_duplicate(self):
		debian = f"debian-{uuid.uuid4()}"
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM
		TestCakeCtl.cakectl.build(debian)

		# Duplicate that VM
		TestCakeCtl.cakectl.duplicate(debian, ubuntu)

		# Ensure that the VM is now named ubuntu
		stdout, _, = TestCakeCtl.cakectl.listvm()

		TestCakeCtl.cakectl.delete(ubuntu)
		TestCakeCtl.cakectl.delete(debian)

		assert debian in stdout
		assert ubuntu in stdout

	def test_delete(self):
		vmname = f"vmname-{uuid.uuid4()}"

		# Create an ubuntu VM
		TestCakeCtl.cakectl.build(vmname)

		# Ensure that the VM exists
		stdout, _, = TestCakeCtl.cakectl.listvm()
		assert vmname in stdout

		# Delete the VM
		TestCakeCtl.cakectl.delete(vmname)

		# Ensure that the VM was removed
		stdout, _, = TestCakeCtl.cakectl.listvm()

		assert vmname not in stdout

	def test_launch(self):
		vm_name = f"integration-test-run-{uuid.uuid4()}"

		# Instantiate a VM with admin:admin SSH access
		stdout, _ = TestCakeCtl.cakectl.launch(vm_name)
		assert f"VM launched {vm_name} with IP: " in stdout

		stdout, _ = TestCakeCtl.cakectl.stop(vm_name)
		assert f"VM {vm_name} stopped" in stdout

		# Delete the VM
		TestCakeCtl.cakectl.delete(vm_name)

	def test_remote(self):
		stdout, _ = TestCakeCtl.cakectl.add_remote("test-remote", "https://images.lxd.canonical.com/")
		assert "test-remote" in stdout

		stdout, _ = TestCakeCtl.cakectl.list_remote()
		assert "test-remote" in stdout

		stdout, _ = TestCakeCtl.cakectl.delete_remote("test-remote")
		assert "test-remote" in stdout

		stdout, _ = TestCakeCtl.cakectl.list_remote()
		assert "test-remote" not in stdout

	def test_template(self):
		debian = f"debian-{uuid.uuid4()}"
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM (because we can create it really fast)
		TestCakeCtl.cakectl.build(debian)

		# Clone the VM
		TestCakeCtl.cakectl.create_template(debian, ubuntu)

		# Ensure that we have new template
		stdout, _, = TestCakeCtl.cakectl.list_template()
		assert ubuntu in stdout

		# Clean up the VM to free disk space
		TestCakeCtl.cakectl.delete(debian)
		stdout, _, = TestCakeCtl.cakectl.listvm()
		assert debian not in stdout

		# Clean up the template to free disk space
		TestCakeCtl.cakectl.delete_template(ubuntu)
		stdout, _, = TestCakeCtl.cakectl.list_template()
		assert ubuntu not in stdout

	def test_networks(self):
		network_name = f"test-network-{uuid.uuid4()}"
		random_octet = random.randint(128, 254)

		TestCakeCtl.cakectl.run(["networks", "create", network_name, "--mode=shared", f"--gateway=192.168.{random_octet}.1", f"--dhcp-end=192.168.{random_octet}.128", "--netmask=255.255.255.0"])
		stdout, _ = TestCakeCtl.cakectl.infos_networks(network_name)
		assert network_name in stdout

		TestCakeCtl.cakectl.start_networks(network_name)
		stdout, _ = TestCakeCtl.cakectl.infos_networks(network_name)
		assert ".sock" in stdout

		sleep(2)

		TestCakeCtl.cakectl.stop_networks(network_name)
		stdout, _ = TestCakeCtl.cakectl.infos_networks(network_name)
		assert "not running" in stdout

		TestCakeCtl.cakectl.delete_networks(network_name)
		stdout, _ = TestCakeCtl.cakectl.list_networks()
		assert network_name not in stdout

	def test_exec(self):
		ubuntu = f"ubuntu-{uuid.uuid4()}"

		# Create a Linux VM (because we can create it really fast)
		TestCakeCtl.cakectl.launch(ubuntu)
		stdout, _ = TestCakeCtl.cakectl.exec(ubuntu, ["cat"], input=b"Hello World")
		assert "Hello World" in stdout

		TestCakeCtl.cakectl.stop(ubuntu)
		TestCakeCtl.cakectl.delete(ubuntu)