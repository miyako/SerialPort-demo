#!/usr/bin/env python3
"""PTY-backed virtual serial device for the SerialPort demo.

A real serial port cannot be attached to a CI machine, so the demo talks to a
pseudo terminal instead. This script owns the *master* side of a PTY pair and
prints the *slave* path so the 4D side can open it like any device:

    $ python3 virtual_serial.py
    PORT=/dev/ttys012
    READY

The port line is emitted before the command loop starts, so a caller may open
the path as soon as it has been read.

Protocol: line oriented, LF or CRLF terminated, ASCII commands. Replies are
deliberately mixed: text for humans, binary frames for Blob handling.

    PING            PONG <seq>
    READ            TEMP=..;HUM=..;SEQ=<seq>
    BIN             binary frame: STX, 4-byte big-endian seq, NUL, 0xFF, ETX
    KANJI           one UTF-8 character split across two writes
    MULTI           64 text lines, one per write (queue/burst pressure)
    STREAM          toggle a 250 ms sensor stream
    STALL           stop reading for 3 seconds, so a large write times out
    HELP            command list
    QUIT            leave

Diagnostics go to stderr so stdout stays reserved for the PORT line.
"""

from __future__ import annotations

import errno
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

STREAM_PERIOD = 0.25
STALL_SECONDS = 3.0


def log(message: str) -> None:
	print(message, file=sys.stderr, flush=True)


class VirtualDevice:
	def __init__(self) -> None:
		self.master, self.slave = pty.openpty()
		# Raw mode: no echo, no CR/LF translation, no signal characters. Without
		# this the terminal line discipline rewrites the bytes we send and the
		# 4D side sees something other than what this script wrote.
		attributes = termios.tcgetattr(self.slave)
		attributes[0] = 0  # iflag
		attributes[1] = 0  # oflag
		attributes[2] = termios.CS8 | termios.CREAD | termios.CLOCAL  # cflag
		attributes[3] = 0  # lflag
		attributes[6][termios.VMIN] = 1
		attributes[6][termios.VTIME] = 0
		termios.tcsetattr(self.slave, termios.TCSANOW, attributes)
		# The master side is non-blocking: select() on a PTY master claims
		# "not writable" even when a small write succeeds, so back-pressure is
		# detected from the write itself instead of from select().
		os.set_blocking(self.master, False)
		self.path = os.ttyname(self.slave)
		self.sequence = 0
		self.streaming = False
		self.stalled_until = 0.0
		self.buffer = b""
		self.running = True

	def send(self, payload: bytes) -> bool:
		"""Write one chunk. Returns False when the reader is not keeping up.

		A write that would block is not retried: the caller uses this signal to
		stop pushing data, which is what a real device with a full FIFO does.
		"""
		try:
			os.write(self.master, payload)
		except OSError as error:
			if error.errno in (errno.EAGAIN, errno.EWOULDBLOCK):
				return False
			if error.errno == errno.EIO:
				self.running = False
				return False
			raise
		return True

	def send_line(self, text: str) -> bool:
		return self.send(text.encode("utf-8") + b"\n")

	def next_sequence(self) -> int:
		self.sequence += 1
		return self.sequence

	def binary_frame(self) -> bytes:
		sequence = self.next_sequence()
		# NUL and 0xFF prove that the 4D side really receives bytes: text
		# encoding would either drop them or fail to round-trip them.
		return b"\x02" + struct.pack(">I", sequence) + b"\x00\x01\x02\xff" + b"\x03\n"

	def read_commands(self, timeout: float) -> list[str]:
		if time.time() < self.stalled_until:
			time.sleep(min(timeout, 0.02))
			return []
		ready, _, _ = select.select([self.master], [], [], timeout)
		if not ready:
			return []
		try:
			chunk = os.read(self.master, 4096)
		except OSError as error:
			if error.errno == errno.EIO:
				self.running = False
				return []
			raise
		if not chunk:
			self.running = False
			return []
		self.buffer += chunk
		commands = []
		while b"\n" in self.buffer:
			line, self.buffer = self.buffer.split(b"\n", 1)
			commands.append(line.decode("utf-8", "replace").strip("\r"))
		return commands

	def handle(self, command: str) -> None:
		name = command.strip().upper()
		if not name:
			return
		if name == "PING":
			self.send_line(f"PONG {self.next_sequence()}")
		elif name == "READ":
			self.send_line(f"TEMP=21.5;HUM=48.0;SEQ={self.next_sequence()}")
		elif name == "BIN":
			self.send(self.binary_frame())
		elif name == "KANJI":
			# "温度" split inside the first character: a stateless decoder that
			# converts each chunk independently loses the character.
			self.send("温度".encode("utf-8")[:1])
			time.sleep(0.05)
			self.send("温度".encode("utf-8")[1:] + b" 21.5\n")
		elif name == "MULTI":
			for index in range(1, 65):
				if not self.send_line(f"LINE {index:02d} sequencer tick"):
					break
				time.sleep(0.01)
		elif name == "STREAM":
			self.streaming = not self.streaming
			self.send_line("STREAM ON" if self.streaming else "STREAM OFF")
		elif name == "STALL":
			self.stalled_until = time.time() + STALL_SECONDS
			log(f"stalled for {STALL_SECONDS}s")
		elif name == "HELP":
			self.send_line("PING READ BIN KANJI MULTI STREAM STALL QUIT")
		elif name == "QUIT":
			self.send_line("BYE")
			self.running = False
		else:
			self.send_line(f"ERR unknown command {name}")

	def run(self) -> int:
		signal.signal(signal.SIGINT, lambda *_: setattr(self, "running", False))
		print(f"PORT={self.path}", flush=True)
		print("READY", flush=True)
		log(f"virtual device on {self.path}")
		next_stream = time.time() + STREAM_PERIOD
		while self.running:
			for command in self.read_commands(0.05):
				self.handle(command)
			if self.streaming and time.time() >= next_stream:
				next_stream = time.time() + STREAM_PERIOD
				if not self.send_line(f"SEQ={self.next_sequence()} TEMP={21.0 + (self.sequence % 7) * 0.1:.1f}"):
					# Reader is not draining: stop the stream rather than spin.
					self.streaming = False
					log("stream paused: reader behind")
		os.close(self.master)
		os.close(self.slave)
		return 0


if __name__ == "__main__":
	raise SystemExit(VirtualDevice().run())
