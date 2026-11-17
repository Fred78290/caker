// Seamless window protocol, guest side. Mirror of Sources/cakedlib/Seamless/SeamlessProtocol.swift (version 2):
// every message is `u32 length` (type byte + payload) + `u8 type` + payload, little endian, strings are
// `u16 length` + UTF-8. Types 0x01..0x7F go guest -> host, 0x81..0xFF host -> guest.

#ifndef SEAMLESS_WIRE_H
#define SEAMLESS_WIRE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define SEAMLESS_VERSION 2
#define SEAMLESS_DEFAULT_VSOCK_PORT 5100
#define SEAMLESS_MAX_STRING 4096
#define SEAMLESS_MAX_RECTS 1024
#define SEAMLESS_MAX_DIMENSION 16384
#define SEAMLESS_MAX_PIXELS 40000000
/* Host messages are tiny; anything bigger is a broken or hostile peer. */
#define SEAMLESS_MAX_HOST_FRAME (64 * 1024)

enum seamless_guest_type {
	G_HELLO = 0x01,
	G_WINDOW_CREATE = 0x02,
	G_WINDOW_TITLE = 0x03,
	G_WINDOW_APPID = 0x04,
	G_WINDOW_HINTS = 0x05,
	G_WINDOW_FRAME = 0x06,
	G_WINDOW_DESTROY = 0x07,
	G_CURSOR = 0x08,
};

enum seamless_host_type {
	H_HELLO_ACK = 0x81,
	H_OUTPUT = 0x82,
	H_WINDOW_RESIZE = 0x83,
	H_WINDOW_CLOSE = 0x84,
	H_WINDOW_FOCUS = 0x85,
	H_POINTER_ENTER = 0x86,
	H_POINTER_LEAVE = 0x87,
	H_POINTER_MOTION = 0x88,
	H_POINTER_BUTTON = 0x89,
	H_POINTER_AXIS = 0x8A,
	H_KEY = 0x8B,
};

enum seamless_window_kind { KIND_TOPLEVEL = 0, KIND_POPUP = 1 };

/* Growable output buffer. */
struct wbuf {
	uint8_t *p;
	size_t len, cap;
	bool failed;
};

void wbuf_free(struct wbuf *b);
void wbuf_u8(struct wbuf *b, uint8_t v);
void wbuf_u16(struct wbuf *b, uint16_t v);
void wbuf_u32(struct wbuf *b, uint32_t v);
void wbuf_i32(struct wbuf *b, int32_t v);
void wbuf_bytes(struct wbuf *b, const void *data, size_t n);
/* Truncated to SEAMLESS_MAX_STRING bytes without cutting a UTF-8 sequence. NULL is the empty string. */
void wbuf_str(struct wbuf *b, const char *s);

/* Starts a message (reserves the length) and finishes it by patching the length in. */
size_t wire_begin(struct wbuf *b, uint8_t type);
void wire_end(struct wbuf *b, size_t start);

/* H_POINTER_AXIS source (host_msg.u32a). */
enum axis_source {
	AXIS_CONTINUOUS = 0, /* trackpad: x/y in logical pixels */
	AXIS_WHEEL = 1,      /* mouse wheel: x/y in notches */
	AXIS_STOP = 2,       /* fingers lifted: x/y ignored */
};

/* A decoded host message. Unused fields are zero. */
struct host_msg {
	uint8_t type;
	uint32_t id;
	uint32_t u32a, u32b; /* helloAck/output: scale120 in u32a; resize: width, height; button: button; axis: enum axis_source in u32a */
	float x, y;          /* pointer position or axis deltas */
	bool flag;           /* focused / pressed */
	uint16_t version;
	uint32_t code; /* key */
};

/* 0 on success, -1 on a malformed message (the connection must be closed). */
int wire_parse_host(uint8_t type, const uint8_t *payload, size_t n, struct host_msg *out);

/* Incremental splitter for the host -> guest byte stream. */
struct rx {
	uint8_t *p;
	size_t len, cap;  /* bytes stored / allocated, starting at p */
	size_t head;      /* start of the unread data */
	size_t pending;   /* size of the message handed out by the last rx_next, dropped on the next call */
};

void rx_free(struct rx *r);
bool rx_append(struct rx *r, const uint8_t *data, size_t n);
/* 1: one message returned (payload valid until the next rx_* call), 0: need more bytes, -1: invalid stream. */
int rx_next(struct rx *r, uint8_t *type, const uint8_t **payload, size_t *n);

#endif
