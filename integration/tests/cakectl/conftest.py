from shutil import which

import pytest
from cakectl import CakeCtl


@pytest.fixture(scope="class")
def cakectl():
	with CakeCtl() as cakectl:
		yield cakectl

@pytest.fixture(autouse=True)
def only_sequoia(request):
	if request.node.get_closest_marker('only_sequoia'):
		arg = request.node.get_closest_marker('only_sequoia').args[0]
		if not "sequoia" in arg:
			pytest.skip('skipped on image: {0}'.format(arg))   

@pytest.fixture(autouse=True)
def only_tart_present(request):
	if request.node.get_closest_marker('only_tart_present'):
		if which("tart") is None:
			pytest.skip("tart executable not found")

def pytest_configure(config):
  config.addinivalue_line("markers", "only_sequoia(image): skip test for the given macos image not sequoia")