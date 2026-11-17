#include "wire.h"

#include <stdlib.h>
#include <string.h>

static bool wbuf_reserve(struct wbuf *b, size_t extra) {
	if (b->failed)
		return false;

	if (b->len + extra <= b->cap)
		return true;

	size_t cap = b->cap ? b->cap : 256;

	while (cap < b->len + extra)
		cap *= 2;

	uint8_t *p = realloc(b->p, cap);

	if (!p) {
		b->failed = true;
		return false;
	}

	b->p = p;
	b->cap = cap;

	return true;
}

void wbuf_free(struct wbuf *b) {
	free(b->p);
	memset(b, 0, sizeof(*b));
}

void wbuf_bytes(struct wbuf *b, const void *data, size_t n) {
	if (n == 0 || !wbuf_reserve(b, n))
		return;

	memcpy(b->p + b->len, data, n);
	b->len += n;
}

void wbuf_u8(struct wbuf *b, uint8_t v) {
	wbuf_bytes(b, &v, 1);
}

void wbuf_u16(struct wbuf *b, uint16_t v) {
	uint8_t t[2] = {(uint8_t)v, (uint8_t)(v >> 8)};
	wbuf_bytes(b, t, 2);
}

void wbuf_u32(struct wbuf *b, uint32_t v) {
	uint8_t t[4] = {(uint8_t)v, (uint8_t)(v >> 8), (uint8_t)(v >> 16), (uint8_t)(v >> 24)};
	wbuf_bytes(b, t, 4);
}

void wbuf_i32(struct wbuf *b, int32_t v) {
	wbuf_u32(b, (uint32_t)v);
}

void wbuf_str(struct wbuf *b, const char *s) {
	size_t n = s ? strlen(s) : 0;

	if (n > SEAMLESS_MAX_STRING) {
		n = SEAMLESS_MAX_STRING;

		/* Don't cut in the middle of a UTF-8 sequence: back up to a lead byte. */
		while (n > 0 && ((uint8_t)s[n] & 0xC0) == 0x80)
			n--;
	}

	wbuf_u16(b, (uint16_t)n);
	wbuf_bytes(b, s, n);
}

size_t wire_begin(struct wbuf *b, uint8_t type) {
	size_t start = b->len;

	wbuf_u32(b, 0);
	wbuf_u8(b, type);

	return start;
}

void wire_end(struct wbuf *b, size_t start) {
	if (b->failed)
		return;

	uint32_t length = (uint32_t)(b->len - start - 4);

	b->p[start] = (uint8_t)length;
	b->p[start + 1] = (uint8_t)(length >> 8);
	b->p[start + 2] = (uint8_t)(length >> 16);
	b->p[start + 3] = (uint8_t)(length >> 24);
}

/* ---- parsing ---- */

struct rd {
	const uint8_t *p;
	size_t n, off;
	bool bad;
};

static const uint8_t *rd_take(struct rd *r, size_t k) {
	if (r->bad || r->n - r->off < k) {
		r->bad = true;
		return NULL;
	}

	const uint8_t *p = r->p + r->off;

	r->off += k;

	return p;
}

static uint8_t rd_u8(struct rd *r) {
	const uint8_t *p = rd_take(r, 1);
	return p ? p[0] : 0;
}

static uint16_t rd_u16(struct rd *r) {
	const uint8_t *p = rd_take(r, 2);
	return p ? (uint16_t)(p[0] | p[1] << 8) : 0;
}

static uint32_t rd_u32(struct rd *r) {
	const uint8_t *p = rd_take(r, 4);
	return p ? (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24 : 0;
}

static float rd_f32(struct rd *r) {
	uint32_t bits = rd_u32(r);
	float f;

	memcpy(&f, &bits, sizeof(f));

	/* Reject NaN and infinities, like the host does. */
	if (f != f || f > 3.0e38f || f < -3.0e38f)
		r->bad = true;

	return f;
}

int wire_parse_host(uint8_t type, const uint8_t *payload, size_t n, struct host_msg *out) {
	struct rd r = {payload, n, 0, false};

	memset(out, 0, sizeof(*out));
	out->type = type;

	switch (type) {
	case H_HELLO_ACK:
		out->version = rd_u16(&r);
		out->u32a = rd_u32(&r);
		break;
	case H_OUTPUT:
		out->u32a = rd_u32(&r);
		break;
	case H_WINDOW_RESIZE:
		out->id = rd_u32(&r);
		out->u32a = rd_u32(&r);
		out->u32b = rd_u32(&r);
		break;
	case H_WINDOW_CLOSE:
	case H_POINTER_LEAVE:
		out->id = rd_u32(&r);
		break;
	case H_WINDOW_FOCUS:
		out->id = rd_u32(&r);
		out->flag = rd_u8(&r) != 0;
		break;
	case H_POINTER_ENTER:
	case H_POINTER_MOTION:
		out->id = rd_u32(&r);
		out->x = rd_f32(&r);
		out->y = rd_f32(&r);
		break;
	case H_POINTER_AXIS:
		out->id = rd_u32(&r);
		out->x = rd_f32(&r);
		out->y = rd_f32(&r);
		out->u32a = rd_u8(&r);

		if (out->u32a > AXIS_STOP)
			r.bad = true;
		break;
	case H_POINTER_BUTTON:
		out->id = rd_u32(&r);
		out->u32a = rd_u32(&r);
		out->flag = rd_u8(&r) != 0;
		break;
	case H_KEY:
		out->code = rd_u32(&r);
		out->flag = rd_u8(&r) != 0;
		break;
	default:
		return -1;
	}

	if (r.bad || r.off != n)
		return -1;

	return 0;
}

/* ---- stream splitter ---- */

void rx_free(struct rx *r) {
	free(r->p);
	memset(r, 0, sizeof(*r));
}

static void rx_drop_consumed(struct rx *r) {
	r->head += r->pending;
	r->pending = 0;

	if (r->head == r->len) {
		r->head = r->len = 0;
	} else if (r->head > 0 && r->head >= r->cap / 2) {
		memmove(r->p, r->p + r->head, r->len - r->head);
		r->len -= r->head;
		r->head = 0;
	}
}

bool rx_append(struct rx *r, const uint8_t *data, size_t n) {
	rx_drop_consumed(r);

	if (r->len + n > r->cap) {
		size_t cap = r->cap ? r->cap : 1024;

		while (cap < r->len + n)
			cap *= 2;

		uint8_t *p = realloc(r->p, cap);

		if (!p)
			return false;

		r->p = p;
		r->cap = cap;
	}

	memcpy(r->p + r->len, data, n);
	r->len += n;

	return true;
}

int rx_next(struct rx *r, uint8_t *type, const uint8_t **payload, size_t *n) {
	rx_drop_consumed(r);

	size_t avail = r->len - r->head;
	const uint8_t *p = r->p + r->head;

	if (avail < 4)
		return 0;

	uint32_t length = (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24;

	if (length < 1 || length > SEAMLESS_MAX_HOST_FRAME)
		return -1;

	if (avail < 4 + (size_t)length)
		return 0;

	*type = p[4];
	*payload = p + 5;
	*n = length - 1;
	r->pending = 4 + (size_t)length;

	return 1;
}
