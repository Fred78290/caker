import os
import subprocess
import tempfile


class Caked:
	def __init__(self):
		if "CIRRUS_WORKING_DIR" in os.environ:
			# Test on CI
			self.cake_home = tempfile.TemporaryDirectory(dir=os.environ.get("CIRRUS_WORKING_DIR"))
			self.cleanup = True

			# Link to the users cache to make things faster
			src = os.path.join(os.path.expanduser("~"), ".cake", "cache")
			dst = os.path.join(self.cake_home.name, "cache")
			os.symlink(src, dst)
		else:
			# Test on local machine 
			self.cake_home =  os.path.join(os.path.expanduser("~"), ".cake")
			self.cleanup = False

	def __enter__(self):
		return self

	def __exit__(self, exc_type, exc_val, exc_tb):
		if self.cleanup:
			self.cake_home.cleanup()

	def home(self) -> str:
		if self.cleanup:
			return self.cake_home.name
		else:
			return self.cake_home

	def build(self, vmname, args=["--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20"]):
		return self.run(["build", vmname] + args)

	def launch(self, vmname, args=["--user=admin", "--password=admin", "--clear-password", "--display-refit", "--cpus=2", "--memory=2048", "--disk-size=20"]):
		return self.run(["launch", vmname] + args)

	def configure(self, vmname, option):
		return self.run(["configure", vmname, option])

	def listvm(self):
		return self.run(["list", "--vmonly"])

	def delete(self, vmname):
		return self.run(["delete", vmname])

	def vmrun(self, vmname, pass_fds=()):
		return self.run_async(["vmrun", vmname], pass_fds=pass_fds)

	def start(self, vmname):
		return self.run(["start", vmname])

	def stop(self, vmname):
		return self.run(["stop", vmname])

	def rename(self, oldname, newname):
		return self.run(["rename", oldname, newname])

	def clone(self, oci, name):
		return self.run(["clone", oci, name])

	def duplicate(self, oldname, newname):
		return self.run(["duplicate", oldname, newname])

	def waitip(self, vmname):
		return self.run(["waitip", vmname, "--wait", "120"])

	def create_template(self, source, dest):
		return self.run(["template", "create", source, dest])

	def delete_template(self, name):
		return self.run(["template", "delete", name])

	def list_template(self):
		return self.run(["template", "list"])

	def list_networks(self):
		return self.run(["networks", "list"])

	def infos_networks(self, name):
		return self.run(["networks", "infos", name])

	def start_networks(self, name):
		return self.run(["networks", "start", name])

	def stop_networks(self, name):
		return self.run(["networks", "stop", name])

	def delete_networks(self, name):
		return self.run(["networks", "delete", name])

	def add_remote(self, name, url):
		return self.run(["remote", "add", name, url])

	def delete_remote(self, name):
		return self.run(["remote", "delete", name])

	def list_remote(self):
		return self.run(["remote", "list"])

	def exec(self, vmname, commands):
		return self.run(["exec", vmname, "--"] + commands)

	def run(self, args, pass_fds=()):
		env = os.environ.copy()
		env.update({"CAKE_HOME": self.home()})

		completed_process = subprocess.run(["caked"] + args, env=env, capture_output=True, pass_fds=pass_fds)

		completed_process.check_returncode()

		return completed_process.stdout.decode("utf-8"), completed_process.stderr.decode("utf-8")

	def run_async(self, args, pass_fds=()) -> subprocess.Popen:
		env = os.environ.copy()
		env.update({"CAKE_HOME": self.home()})
		return subprocess.Popen(["caked"] + args, env=env, pass_fds=pass_fds)
