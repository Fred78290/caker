from shutil import which

import pytest


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
  config.addinivalue_line("markers", "only_tart_present(): skip test if tart is not present")