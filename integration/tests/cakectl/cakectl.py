import os
import subprocess
import tempfile


class CakeCtl:
	serviceCaked = None

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

		env = os.environ.copy()
		env.update({"CAKE_HOME": self.home()})
		self.serviceCaked = subprocess.Popen(["caked", "service", "listen", "--secure"], env=env)

	def __del__(self):
		if self.cleanup:
			self.cake_home.cleanup()

		if self.serviceCaked is not None:
			self.serviceCaked.kill()
			self.serviceCaked.wait()

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

	def run(self, args, pass_fds=()):
		env = os.environ.copy()
		env.update({"CAKE_HOME": self.home()})

		completed_process = subprocess.run(["cakectl"] + args, env=env, capture_output=True, pass_fds=pass_fds)

		completed_process.check_returncode()

		return completed_process.stdout.decode("utf-8"), completed_process.stderr.decode("utf-8")

	def run_async(self, args, pass_fds=()) -> subprocess.Popen:
		env = os.environ.copy()
		env.update({"CAKE_HOME": self.home()})
		return subprocess.Popen(["cakectl"] + args, env=env, pass_fds=pass_fds)
