import logging

import caked
import test_devices

FORMAT = "{asctime} - {levelname} - {name}:{message}"
logging.basicConfig(filename='/dev/stdout', format=FORMAT, datefmt="%Y-%m-%d %H:%M", style="{", level=logging.INFO)

log = logging.getLogger(__name__)

caked = caked.Caked()
onLinux = test_devices.TestVirtioDevicesOnLinux(caked)
onMac = test_devices.TestVirtioDevicesOnMacOS(caked)

log.info("Running standalone tests...")

log.info("\n\n=====================================================================================================")
log.info("test_virtio_bind on Linux...")
onLinux.test_virtio_bind(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_http on Linux...")
onLinux.test_virtio_http(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_tcp on Linux...")
onLinux.test_virtio_tcp(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_connect on Linux...")
onLinux.test_virtio_connect(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_pipe on Linux...")
onLinux.test_virtio_pipe(caked)

log.info("\n\n=====================================================================================================")
log.info("test_console_socket on Linux...")
onLinux.test_console_socket(caked)

log.info("\n\n=====================================================================================================")
log.info("test_console_pipe on Linux...")
onLinux.test_console_pipe(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_bind on MacOS...")
onMac.test_virtio_bind(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_http on MacOS...")
onMac.test_virtio_http(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_tcp on MacOS...")
onMac.test_virtio_tcp(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_connect on MacOS...")
onMac.test_virtio_connect(caked)

log.info("\n\n=====================================================================================================")
log.info("test_virtio_pipe on MacOS...")
onMac.test_virtio_pipe(caked)

log.info("\n\n=====================================================================================================")
log.info("test_console_socket on MacOS...")
onMac.test_console_socket(caked)

log.info("\n\n=====================================================================================================")
log.info("test_console_pipe on MacOS...")
onMac.test_console_pipe(caked)

