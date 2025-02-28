#!/usr/bin/env python3
import select
import io

# This script is a simple example of how to communicate with the console device in the guest.
def readmessage(fd: io.FileIO):
	while True:
		rlist, _, _ = select.select([fd], [], [], 60)
		if fd in rlist:
			data = fd.read(8)
			if data:
				length = int.from_bytes(data, byteorder='big')

				print('Echo read message length: {0}'.format(length))

				response = bytearray()

				while length > 0:
					data = fd.read(min(8192, length))
					if data:
						length -= len(data)
						response.extend(data)

				with open('/tmp/received.txt', 'w') as text_file:
					text_file.write(response.decode())

				return response
		else:
			raise Exception('Timeout while waiting for message')

def writemessage(fd: io.FileIO, message):
	length = len(message).to_bytes(8, 'big')

	print('Echo send message length: {0}'.format(len(message)))

	fd.write(length)
	fd.write(message)

def echo_echomessage(in_pipe: io.FileIO, out_pipe: io.FileIO):
	print('Reading pipe')
	message = readmessage(in_pipe)

	print('Writing pipe')
	writemessage(out_pipe, message)

	print('Acking pipe')
	response = readmessage(in_pipe)

	print('Received data: {0}'.format(response.decode()))

echo_echomessage(io.FileIO(0), io.FileIO(1))
