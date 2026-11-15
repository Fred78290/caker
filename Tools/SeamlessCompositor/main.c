// caker-seamlessd: the guest half of Caker's seamless windows.
//
// A headless Wayland compositor (wlroots) that, instead of showing windows on a display, streams each toplevel and
// popup to the macOS host over vsock (see wire.h and Sources/cakedlib/Seamless/SeamlessProtocol.swift), and feeds the
// host's keyboard and pointer input back to the Wayland clients. Same idea as WSLg's Weston+RDP, without RDP.
//
//   caker-seamlessd [--connect vsock:5100|unix:/path|tcp:host:port] [--socket name] [-- command args...]
//
// With a command, it is started with WAYLAND_DISPLAY pointing at this compositor and the compositor exits with it.

#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/vm_sockets.h>
#include <lz4.h>
#include <math.h>
#include <netdb.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include <drm_fourcc.h>
#include <wayland-server-core.h>
#include <wlr/backend.h>
#include <wlr/backend/headless.h>
#include <wlr/interfaces/wlr_keyboard.h>
#include <wlr/render/allocator.h>
#include <wlr/render/drm_format_set.h>
#include <wlr/render/pass.h>
#include <wlr/render/wlr_renderer.h>
#include <wlr/types/wlr_compositor.h>
#include <wlr/types/wlr_cursor_shape_v1.h>
#include <wlr/types/wlr_data_device.h>
#include <wlr/types/wlr_fractional_scale_v1.h>
#include <wlr/types/wlr_keyboard.h>
#include <wlr/types/wlr_output.h>
#include <wlr/types/wlr_output_layout.h>
#include <wlr/types/wlr_primary_selection_v1.h>
#include <wlr/types/wlr_seat.h>
#include <wlr/types/wlr_subcompositor.h>
#include <wlr/types/wlr_viewporter.h>
#include <wlr/types/wlr_xdg_decoration_v1.h>
#include <wlr/types/wlr_xdg_output_v1.h>
#include <wlr/types/wlr_xdg_shell.h>
#include <wlr/util/box.h>
#include <wlr/util/log.h>
#include <xkbcommon/xkbcommon.h>

#include "wire.h"

#define MAX_OUTQ_BYTES (64u * 1024 * 1024)
#define FRAME_INTERVAL_MS 16
#define RECONNECT_MS 1000

struct server;

enum window_kind_internal { WIN_TOPLEVEL, WIN_POPUP };

struct window {
	struct wl_list link;
	struct server *srv;
	enum window_kind_internal kind;
	struct wlr_xdg_surface *xdg;
	struct wlr_xdg_toplevel *toplevel;
	struct wlr_xdg_popup *popup;
	struct window *parent;

	uint32_t id; /* 0 while not announced to the host */
	bool mapped, dirty, force_full;
	uint32_t hints[4];
	bool hints_known;

	uint8_t *prev; /* previous frame, tightly packed BGRA, to find what changed */
	size_t prev_size;
	uint32_t prev_w, prev_h;
	struct wlr_buffer *rbuf;
	int rbuf_w, rbuf_h;

	struct wl_listener map, unmap, destroy, commit;
	struct wl_listener set_title, set_app_id, request_maximize, request_fullscreen, request_minimize, request_move, request_resize;
};

struct out_item {
	struct out_item *next;
	size_t len, off;
	uint8_t data[];
};

struct server {
	struct wl_display *display;
	struct wl_event_loop *loop;
	struct wlr_backend *backend;
	struct wlr_renderer *renderer;
	struct wlr_allocator *allocator;
	struct wlr_compositor *compositor;
	struct wlr_xdg_shell *xdg_shell;
	struct wlr_seat *seat;
	struct wlr_output_layout *layout;
	struct wlr_output *output;
	struct wlr_fractional_scale_manager_v1 *fractional;
	struct wlr_cursor_shape_manager_v1 *cursor_shape;
	struct wlr_xdg_decoration_manager_v1 *decoration_manager;

	struct wlr_keyboard keyboard;
	struct xkb_context *xkb;

	struct wl_list windows; /* announce order: parents before popups */
	uint32_t next_id;
	struct window *pointer_win, *focus_win;

	/* host connection */
	const char *connect_spec;
	int fd;
	bool ready; /* hello acknowledged */
	uint32_t scale120;
	struct wl_event_source *fd_source, *reconnect_timer, *frame_timer;
	struct rx rx;
	struct out_item *outq_head, *outq_tail;
	size_t outq_bytes;
	bool frame_timer_armed;

	struct wl_listener new_surface, new_toplevel, new_popup, new_decoration, request_set_shape, request_set_cursor;
	struct wl_listener kb_key, kb_modifiers;
	pid_t child;
};

static struct server srv;

static uint32_t now_msec(void) {
	struct timespec ts;

	clock_gettime(CLOCK_MONOTONIC, &ts);

	return (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

/* ======================================================================== transport */

static void transport_close(struct server *s);
static void announce_all(struct server *s);

static void outq_clear(struct server *s) {
	while (s->outq_head) {
		struct out_item *i = s->outq_head;

		s->outq_head = i->next;
		free(i);
	}

	s->outq_tail = NULL;
	s->outq_bytes = 0;
}

static void update_write_interest(struct server *s) {
	if (s->fd_source)
		wl_event_source_fd_update(s->fd_source, WL_EVENT_READABLE | (s->outq_head ? WL_EVENT_WRITABLE : 0));
}

static bool flush_out(struct server *s) {
	while (s->outq_head) {
		struct out_item *i = s->outq_head;
		ssize_t n = send(s->fd, i->data + i->off, i->len - i->off, MSG_NOSIGNAL);

		if (n < 0) {
			if (errno == EINTR)
				continue;
			if (errno == EAGAIN || errno == EWOULDBLOCK)
				break;

			return false;
		}

		i->off += (size_t)n;
		s->outq_bytes -= (size_t)n;

		if (i->off < i->len)
			break;

		s->outq_head = i->next;

		if (!s->outq_head)
			s->outq_tail = NULL;

		free(i);
	}

	update_write_interest(s);

	return true;
}

/* Queues a finished message. Returns false when nothing is connected or the queue is over its cap (the caller
 * then forgets what it sent and resends in full later). */
static bool send_message(struct server *s, struct wbuf *b) {
	if (s->fd < 0 || b->failed || b->len == 0)
		return false;

	if (s->outq_bytes + b->len > MAX_OUTQ_BYTES)
		return false;

	struct out_item *i = malloc(sizeof(*i) + b->len);

	if (!i)
		return false;

	i->next = NULL;
	i->len = b->len;
	i->off = 0;
	memcpy(i->data, b->p, b->len);

	if (s->outq_tail)
		s->outq_tail->next = i;
	else
		s->outq_head = i;

	s->outq_tail = i;
	s->outq_bytes += b->len;

	if (!flush_out(s)) {
		transport_close(s);
		return false;
	}

	return true;
}

static struct window *window_by_id(struct server *s, uint32_t id) {
	struct window *w;

	if (id == 0)
		return NULL;

	wl_list_for_each(w, &s->windows, link) {
		if (w->id == id)
			return w;
	}

	return NULL;
}

static void send_hello(struct server *s) {
	struct wbuf b = {0};
	size_t st = wire_begin(&b, G_HELLO);

	wbuf_u16(&b, SEAMLESS_VERSION);
	wbuf_str(&b, "caker-seamlessd 0.1");
	wire_end(&b, st);
	send_message(s, &b);
	wbuf_free(&b);
}

static void send_cursor(struct server *s, struct window *w, const char *shape) {
	if (!s->ready || !w || w->id == 0)
		return;

	struct wbuf b = {0};
	size_t st = wire_begin(&b, G_CURSOR);

	wbuf_u32(&b, w->id);
	wbuf_str(&b, shape);
	wire_end(&b, st);
	send_message(s, &b);
	wbuf_free(&b);
}

static void send_title(struct server *s, struct window *w, uint8_t type, const char *text) {
	if (!s->ready || w->id == 0)
		return;

	struct wbuf b = {0};
	size_t st = wire_begin(&b, type);

	wbuf_u32(&b, w->id);
	wbuf_str(&b, text);
	wire_end(&b, st);
	send_message(s, &b);
	wbuf_free(&b);
}

static void send_hints(struct server *s, struct window *w) {
	if (!s->ready || w->id == 0 || w->kind != WIN_TOPLEVEL)
		return;

	struct wlr_xdg_toplevel_state *cur = &w->toplevel->current;
	uint32_t h[4] = {(uint32_t)cur->min_width, (uint32_t)cur->min_height, (uint32_t)cur->max_width, (uint32_t)cur->max_height};

	if (w->hints_known && memcmp(h, w->hints, sizeof(h)) == 0)
		return;

	memcpy(w->hints, h, sizeof(h));
	w->hints_known = true;

	struct wbuf b = {0};
	size_t st = wire_begin(&b, G_WINDOW_HINTS);

	wbuf_u32(&b, w->id);

	for (int i = 0; i < 4; i++)
		wbuf_u32(&b, h[i]);

	wire_end(&b, st);
	send_message(s, &b);
	wbuf_free(&b);
}

static void transport_close(struct server *s) {
	if (s->fd_source) {
		wl_event_source_remove(s->fd_source);
		s->fd_source = NULL;
	}

	if (s->fd >= 0) {
		close(s->fd);
		s->fd = -1;
	}

	s->ready = false;
	outq_clear(s);
	rx_free(&s->rx);

	/* The host forgot everything: windows get announced again on the next connection. */
	struct window *w;

	wl_list_for_each(w, &s->windows, link) {
		w->id = 0;
		w->hints_known = false;
		w->force_full = true;
		free(w->prev);
		w->prev = NULL;
		w->prev_size = 0;
	}

	s->pointer_win = NULL;
	s->focus_win = NULL;

	if (s->reconnect_timer)
		wl_event_source_timer_update(s->reconnect_timer, RECONNECT_MS);
}

/* ---- host messages ---- */

static void focus_window(struct server *s, struct window *w, bool focused);
static void pointer_enter_or_motion(struct server *s, struct window *w, float x, float y, bool enter);
static void apply_scale(struct server *s, uint32_t scale120);

static struct wlr_surface *root_surface_of(struct window *w) {
	return w->xdg->surface;
}

static void handle_host_message(struct server *s, const struct host_msg *m) {
	struct window *w = window_by_id(s, m->id);

	if (m->type != H_POINTER_MOTION && m->type != H_POINTER_AXIS)
		wlr_log(WLR_DEBUG, "host message 0x%02x id=%u flag=%d code=%u", m->type, m->id, m->flag, m->code);

	switch (m->type) {
	case H_HELLO_ACK:
		if (m->version != SEAMLESS_VERSION) {
			wlr_log(WLR_ERROR, "host speaks protocol %u, expected %u", m->version, SEAMLESS_VERSION);
			transport_close(s);
			return;
		}

		s->ready = true;
		apply_scale(s, m->u32a);
		announce_all(s);
		break;
	case H_OUTPUT:
		apply_scale(s, m->u32a);
		break;
	case H_WINDOW_RESIZE:
		if (w && w->kind == WIN_TOPLEVEL && m->u32a > 0 && m->u32b > 0 && m->u32a <= SEAMLESS_MAX_DIMENSION && m->u32b <= SEAMLESS_MAX_DIMENSION)
			wlr_xdg_toplevel_set_size(w->toplevel, (int32_t)m->u32a, (int32_t)m->u32b);
		break;
	case H_WINDOW_CLOSE:
		if (w && w->kind == WIN_TOPLEVEL)
			wlr_xdg_toplevel_send_close(w->toplevel);
		else if (w && w->kind == WIN_POPUP)
			wlr_xdg_popup_destroy(w->popup);
		break;
	case H_WINDOW_FOCUS:
		if (w && w->kind == WIN_TOPLEVEL)
			focus_window(s, w, m->flag);
		break;
	case H_POINTER_ENTER:
		if (w)
			pointer_enter_or_motion(s, w, m->x, m->y, true);
		break;
	case H_POINTER_MOTION:
		if (w)
			pointer_enter_or_motion(s, w, m->x, m->y, false);
		break;
	case H_POINTER_LEAVE:
		/* Moving between two host windows may deliver the enter of the new one first. */
		if (w && s->pointer_win == w) {
			wlr_seat_pointer_notify_clear_focus(s->seat);
			s->pointer_win = NULL;
		}
		break;
	case H_POINTER_BUTTON:
		if (w) {
			wlr_seat_pointer_notify_button(s->seat, now_msec(), m->u32a, m->flag ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
			wlr_seat_pointer_notify_frame(s->seat);
		}
		break;
	case H_POINTER_AXIS:
		if (w) {
			if (m->y != 0.0f)
				wlr_seat_pointer_notify_axis(s->seat, now_msec(), WL_POINTER_AXIS_VERTICAL_SCROLL, m->y, 0, WL_POINTER_AXIS_SOURCE_FINGER,
					WL_POINTER_AXIS_RELATIVE_DIRECTION_IDENTICAL);

			if (m->x != 0.0f)
				wlr_seat_pointer_notify_axis(s->seat, now_msec(), WL_POINTER_AXIS_HORIZONTAL_SCROLL, m->x, 0, WL_POINTER_AXIS_SOURCE_FINGER,
					WL_POINTER_AXIS_RELATIVE_DIRECTION_IDENTICAL);

			wlr_seat_pointer_notify_frame(s->seat);
		}
		break;
	case H_KEY: {
		struct wlr_keyboard_key_event ev = {
			.time_msec = now_msec(),
			.keycode = m->code,
			.update_state = true,
			.state = m->flag ? WL_KEYBOARD_KEY_STATE_PRESSED : WL_KEYBOARD_KEY_STATE_RELEASED,
		};

		wlr_keyboard_notify_key(&s->keyboard, &ev);
		break;
	}
	}
}

static int on_host_fd(int fd, uint32_t mask, void *data) {
	struct server *s = data;

	if (mask & (WL_EVENT_HANGUP | WL_EVENT_ERROR)) {
		wlr_log(WLR_INFO, "host connection closed");
		transport_close(s);
		return 0;
	}

	if (mask & WL_EVENT_WRITABLE) {
		if (!flush_out(s)) {
			transport_close(s);
			return 0;
		}
	}

	if (mask & WL_EVENT_READABLE) {
		uint8_t chunk[4096];
		ssize_t n = recv(fd, chunk, sizeof(chunk), 0);

		if (n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR)) {
			wlr_log(WLR_INFO, "host connection closed");
			transport_close(s);
			return 0;
		}

		if (n > 0 && !rx_append(&s->rx, chunk, (size_t)n)) {
			transport_close(s);
			return 0;
		}

		for (;;) {
			uint8_t type;
			const uint8_t *payload;
			size_t len;
			int r = rx_next(&s->rx, &type, &payload, &len);

			if (r == 0)
				break;

			struct host_msg m;

			if (r < 0 || wire_parse_host(type, payload, len, &m) < 0) {
				wlr_log(WLR_ERROR, "protocol error from the host, closing");
				transport_close(s);
				return 0;
			}

			handle_host_message(s, &m);

			/* A handler may have closed the connection. */
			if (s->fd < 0)
				return 0;
		}
	}

	return 0;
}

static int connect_to_host(const char *spec) {
	int fd = -1;

	if (strncmp(spec, "vsock:", 6) == 0) {
		struct sockaddr_vm a = {.svm_family = AF_VSOCK, .svm_cid = VMADDR_CID_HOST, .svm_port = (unsigned)atoi(spec + 6)};

		fd = socket(AF_VSOCK, SOCK_STREAM | SOCK_CLOEXEC, 0);

		if (fd >= 0 && connect(fd, (struct sockaddr *)&a, sizeof(a)) < 0) {
			close(fd);
			return -1;
		}
	} else if (strncmp(spec, "unix:", 5) == 0) {
		struct sockaddr_un a = {.sun_family = AF_UNIX};

		if (strlen(spec + 5) >= sizeof(a.sun_path))
			return -1;

		strcpy(a.sun_path, spec + 5);
		fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);

		if (fd >= 0 && connect(fd, (struct sockaddr *)&a, sizeof(a)) < 0) {
			close(fd);
			return -1;
		}
	} else if (strncmp(spec, "tcp:", 4) == 0) {
		char host[256];
		const char *colon = strrchr(spec + 4, ':');

		if (!colon || (size_t)(colon - (spec + 4)) >= sizeof(host))
			return -1;

		memcpy(host, spec + 4, (size_t)(colon - (spec + 4)));
		host[colon - (spec + 4)] = 0;

		struct addrinfo hints = {.ai_family = AF_UNSPEC, .ai_socktype = SOCK_STREAM}, *res = NULL;

		if (getaddrinfo(host, colon + 1, &hints, &res) != 0)
			return -1;

		for (struct addrinfo *p = res; p; p = p->ai_next) {
			fd = socket(p->ai_family, p->ai_socktype | SOCK_CLOEXEC, p->ai_protocol);

			if (fd >= 0 && connect(fd, p->ai_addr, p->ai_addrlen) == 0)
				break;

			if (fd >= 0)
				close(fd);

			fd = -1;
		}

		freeaddrinfo(res);
	}

	return fd;
}

static int on_reconnect_timer(void *data) {
	struct server *s = data;

	if (s->fd >= 0)
		return 0;

	int fd = connect_to_host(s->connect_spec);

	if (fd < 0) {
		wl_event_source_timer_update(s->reconnect_timer, RECONNECT_MS);
		return 0;
	}

	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
	s->fd = fd;
	s->fd_source = wl_event_loop_add_fd(s->loop, fd, WL_EVENT_READABLE, on_host_fd, s);
	wlr_log(WLR_INFO, "connected to the host (%s)", s->connect_spec);
	send_hello(s);

	return 0;
}

/* ======================================================================== rendering and frames */

struct render_ctx {
	struct wlr_render_pass *pass;
	struct wlr_box geo;
	double k;
};

static void render_surface(struct wlr_surface *surface, int sx, int sy, void *data) {
	struct render_ctx *c = data;
	struct wlr_texture *tex = wlr_surface_get_texture(surface);

	if (!tex || surface->current.width <= 0 || surface->current.height <= 0)
		return;

	struct wlr_fbox src;

	wlr_surface_get_buffer_source_box(surface, &src);

	int x0 = (int)lround((sx - c->geo.x) * c->k);
	int y0 = (int)lround((sy - c->geo.y) * c->k);
	int x1 = (int)lround((sx - c->geo.x + surface->current.width) * c->k);
	int y1 = (int)lround((sy - c->geo.y + surface->current.height) * c->k);

	if (x1 <= x0 || y1 <= y0)
		return;

	wlr_render_pass_add_texture(c->pass,
		&(struct wlr_render_texture_options){
			.texture = tex,
			.src_box = src,
			.dst_box = {.x = x0, .y = y0, .width = x1 - x0, .height = y1 - y0},
			.transform = surface->current.transform,
			.filter_mode = WLR_SCALE_FILTER_BILINEAR,
			.blend_mode = WLR_RENDER_BLEND_MODE_PREMULTIPLIED,
		});
}

static void frame_done_iter(struct wlr_surface *surface, int sx, int sy, void *data) {
	wlr_surface_send_frame_done(surface, data);
}

static void window_frame_done(struct window *w) {
	struct timespec now;

	clock_gettime(CLOCK_MONOTONIC, &now);
	wlr_xdg_surface_for_each_surface(w->xdg, frame_done_iter, &now);
}

static bool window_geometry(struct window *w, struct wlr_box *geo) {
	*geo = w->xdg->geometry;

	if (geo->width <= 0 || geo->height <= 0) {
		geo->x = geo->y = 0;
		geo->width = w->xdg->surface->current.width;
		geo->height = w->xdg->surface->current.height;
	}

	return geo->width > 0 && geo->height > 0;
}

/* Bounding box of the pixels that differ from the previous frame. */
static bool diff_bounds(const uint8_t *cur, size_t stride, const uint8_t *prev, uint32_t w, uint32_t h, uint32_t *rx, uint32_t *ry, uint32_t *rw, uint32_t *rh) {
	size_t row = (size_t)w * 4;
	uint32_t y0 = h, y1 = 0, x0 = w, x1 = 0;

	for (uint32_t y = 0; y < h; y++) {
		const uint8_t *a = cur + y * stride, *b = prev + y * row;

		if (memcmp(a, b, row) == 0)
			continue;

		if (y0 == h)
			y0 = y;

		y1 = y;

		const uint32_t *pa = (const uint32_t *)a, *pb = (const uint32_t *)b;
		uint32_t lo = 0, hi = w - 1;

		while (lo < w && pa[lo] == pb[lo])
			lo++;

		while (hi > lo && pa[hi] == pb[hi])
			hi--;

		if (lo < x0)
			x0 = lo;

		if (hi + 1 > x1)
			x1 = hi + 1;
	}

	if (y0 == h)
		return false;

	*rx = x0;
	*ry = y0;
	*rw = x1 - x0;
	*rh = y1 - y0 + 1;

	return true;
}

static void announce_window(struct server *s, struct window *w) {
	if (w->id != 0 || !s->ready || !w->mapped)
		return;

	/* A popup needs its parent on the host first. */
	if (w->kind == WIN_POPUP && (!w->parent || w->parent->id == 0))
		return;

	w->id = s->next_id++;

	int32_t px = 0, py = 0;

	if (w->kind == WIN_POPUP) {
		struct wlr_box pgeo;

		double dx = 0, dy = 0;

		wlr_xdg_popup_get_position(w->popup, &dx, &dy);
		px = (int32_t)lround(dx);
		py = (int32_t)lround(dy);
		window_geometry(w->parent, &pgeo);
		px -= pgeo.x;
		py -= pgeo.y;
	}

	struct wbuf b = {0};
	size_t st = wire_begin(&b, G_WINDOW_CREATE);

	wbuf_u32(&b, w->id);
	wbuf_u32(&b, w->kind == WIN_POPUP && w->parent ? w->parent->id : 0);
	wbuf_u8(&b, w->kind == WIN_POPUP ? KIND_POPUP : KIND_TOPLEVEL);
	wbuf_i32(&b, px);
	wbuf_i32(&b, py);
	wbuf_str(&b, w->kind == WIN_TOPLEVEL ? w->toplevel->title : "");
	wbuf_str(&b, w->kind == WIN_TOPLEVEL ? w->toplevel->app_id : "");
	wire_end(&b, st);

	bool ok = send_message(s, &b);

	wbuf_free(&b);

	if (!ok) {
		w->id = 0;
		return;
	}

	w->force_full = true;
	w->dirty = true;
	send_hints(s, w);
}

static void announce_all(struct server *s) {
	struct window *w;

	wl_list_for_each(w, &s->windows, link) {
		announce_window(s, w);
	}
}

static void render_and_send(struct server *s, struct window *w) {
	struct wlr_box geo;

	if (!w->mapped || !window_geometry(w, &geo) || w->id == 0)
		return;

	double k = s->scale120 / 120.0;
	int pw = (int)lround(geo.width * k), ph = (int)lround(geo.height * k);

	if (pw < 1)
		pw = 1;

	if (ph < 1)
		ph = 1;

	if (pw > SEAMLESS_MAX_DIMENSION || ph > SEAMLESS_MAX_DIMENSION || (long)pw * ph > SEAMLESS_MAX_PIXELS) {
		wlr_log(WLR_ERROR, "window %u is too large (%dx%d)", w->id, pw, ph);
		return;
	}

	if (!w->rbuf || w->rbuf_w != pw || w->rbuf_h != ph) {
		if (w->rbuf)
			wlr_buffer_drop(w->rbuf);

		const struct wlr_drm_format_set *formats = wlr_renderer_get_texture_formats(s->renderer, s->allocator->buffer_caps);
		const struct wlr_drm_format *fmt = formats ? wlr_drm_format_set_get(formats, DRM_FORMAT_ARGB8888) : NULL;

		w->rbuf = fmt ? wlr_allocator_create_buffer(s->allocator, pw, ph, fmt) : NULL;
		w->rbuf_w = pw;
		w->rbuf_h = ph;

		if (!w->rbuf) {
			wlr_log(WLR_ERROR, "cannot allocate a %dx%d buffer", pw, ph);
			return;
		}
	}

	struct wlr_render_pass *pass = wlr_renderer_begin_buffer_pass(s->renderer, w->rbuf, NULL);

	if (!pass)
		return;

	wlr_render_pass_add_rect(pass,
		&(struct wlr_render_rect_options){
			.box = {0, 0, pw, ph},
			.color = {0, 0, 0, 0},
			.blend_mode = WLR_RENDER_BLEND_MODE_NONE,
		});

	struct render_ctx ctx = {.pass = pass, .geo = geo, .k = k};

	wlr_xdg_surface_for_each_surface(w->xdg, render_surface, &ctx);

	if (!wlr_render_pass_submit(pass))
		return;

	void *data;
	uint32_t format;
	size_t stride;

	if (!wlr_buffer_begin_data_ptr_access(w->rbuf, WLR_BUFFER_DATA_PTR_ACCESS_READ, &data, &format, &stride))
		return;

	const uint8_t *cur = data;
	uint32_t rx = 0, ry = 0, rw = (uint32_t)pw, rh = (uint32_t)ph;
	bool changed = true;
	size_t packed = (size_t)pw * ph * 4;

	if (!w->force_full && w->prev && w->prev_w == (uint32_t)pw && w->prev_h == (uint32_t)ph)
		changed = diff_bounds(cur, stride, w->prev, (uint32_t)pw, (uint32_t)ph, &rx, &ry, &rw, &rh);

	if (changed) {
		/* Copy the changed rectangle tightly packed, and remember the frame for the next diff. */
		uint8_t *raw = malloc((size_t)rw * rh * 4);
		uint8_t *keep = w->prev && w->prev_size == packed ? w->prev : realloc(w->prev, packed);

		if (raw && keep) {
			for (int y = 0; y < ph; y++)
				memcpy(keep + (size_t)y * pw * 4, cur + y * stride, (size_t)pw * 4);

			for (uint32_t y = 0; y < rh; y++)
				memcpy(raw + (size_t)y * rw * 4, keep + ((size_t)(ry + y) * pw + rx) * 4, (size_t)rw * 4);

			size_t rawlen = (size_t)rw * rh * 4;
			int bound = LZ4_compressBound((int)rawlen);
			char *packed_data = bound > 0 ? malloc((size_t)bound) : NULL;
			int clen = packed_data ? LZ4_compress_default((const char *)raw, packed_data, (int)rawlen, bound) : 0;
			bool use_lz4 = clen > 0 && (size_t)clen < rawlen;

			struct wbuf b = {0};
			size_t st = wire_begin(&b, G_WINDOW_FRAME);

			wbuf_u32(&b, w->id);
			wbuf_u32(&b, (uint32_t)pw);
			wbuf_u32(&b, (uint32_t)ph);
			wbuf_u8(&b, 0); /* BGRA premultiplied */
			wbuf_u16(&b, 1);
			wbuf_u32(&b, rx);
			wbuf_u32(&b, ry);
			wbuf_u32(&b, rw);
			wbuf_u32(&b, rh);
			wbuf_u8(&b, use_lz4 ? 1 : 0);
			wbuf_u32(&b, (uint32_t)(use_lz4 ? (size_t)clen : rawlen));
			wbuf_bytes(&b, use_lz4 ? (const void *)packed_data : (const void *)raw, use_lz4 ? (size_t)clen : rawlen);
			wire_end(&b, st);

			if (send_message(s, &b)) {
				w->prev = keep;
				w->prev_size = packed;
				w->prev_w = (uint32_t)pw;
				w->prev_h = (uint32_t)ph;
				w->force_full = false;
			} else {
				/* Not sent (queue full): keep nothing so the next frame is a full one. */
				w->prev = keep;
				w->prev_size = packed;
				w->prev_w = 0;
				w->force_full = true;
			}

			wbuf_free(&b);
			free(packed_data);
		}

		free(raw);
	}

	wlr_buffer_end_data_ptr_access(w->rbuf);
}

static void flush_dirty(struct server *s) {
	struct window *w;

	wl_list_for_each(w, &s->windows, link) {
		if (!w->dirty)
			continue;

		w->dirty = false;

		if (s->ready)
			render_and_send(s, w);

		if (w->mapped)
			window_frame_done(w);
	}
}

static int on_frame_timer(void *data) {
	struct server *s = data;

	s->frame_timer_armed = false;
	flush_dirty(s);

	return 0;
}

static void mark_dirty(struct server *s, struct window *w) {
	w->dirty = true;

	if (!s->frame_timer_armed) {
		s->frame_timer_armed = true;
		wl_event_source_timer_update(s->frame_timer, FRAME_INTERVAL_MS);
	}
}

/* ======================================================================== windows */

static struct window *window_of_surface(struct wlr_surface *surface) {
	struct wlr_surface *root = wlr_surface_get_root_surface(surface);
	struct wlr_xdg_surface *xs = wlr_xdg_surface_try_from_wlr_surface(root);

	return xs ? xs->data : NULL;
}

static void on_surface_commit_global(struct wlr_surface *surface) {
	struct wlr_xdg_surface *xs = wlr_xdg_surface_try_from_wlr_surface(surface);

	/* The first commit of an xdg role must be answered with a configure, otherwise the client never maps. */
	if (xs && xs->initial_commit) {
		if (xs->role == WLR_XDG_SURFACE_ROLE_TOPLEVEL && xs->toplevel)
			wlr_xdg_toplevel_set_size(xs->toplevel, 0, 0);
		else
			wlr_xdg_surface_schedule_configure(xs);
	}

	struct window *w = window_of_surface(surface);

	if (w && w->mapped) {
		send_hints(w->srv, w);
		mark_dirty(w->srv, w);
	}
}

struct surface_hook {
	struct wl_listener commit, destroy;
	struct wlr_surface *surface;
};

static void hook_commit(struct wl_listener *l, void *data) {
	struct surface_hook *h = wl_container_of(l, h, commit);

	on_surface_commit_global(h->surface);
}

static void hook_destroy(struct wl_listener *l, void *data) {
	struct surface_hook *h = wl_container_of(l, h, destroy);

	wl_list_remove(&h->commit.link);
	wl_list_remove(&h->destroy.link);
	free(h);
}

static void set_surface_scale(struct wlr_surface *surface, uint32_t scale120) {
	wlr_fractional_scale_v1_notify_scale(surface, scale120 / 120.0);
	wlr_surface_set_preferred_buffer_scale(surface, (int32_t)ceil(scale120 / 120.0));
}

static void on_new_surface(struct wl_listener *l, void *data) {
	struct wlr_surface *surface = data;
	struct surface_hook *h = calloc(1, sizeof(*h));

	if (!h)
		return;

	h->surface = surface;
	h->commit.notify = hook_commit;
	wl_signal_add(&surface->events.commit, &h->commit);
	h->destroy.notify = hook_destroy;
	wl_signal_add(&surface->events.destroy, &h->destroy);
	set_surface_scale(surface, srv.scale120);
}

static void scale_iter(struct wlr_surface *surface, int sx, int sy, void *data) {
	set_surface_scale(surface, *(uint32_t *)data);
}

static void apply_scale(struct server *s, uint32_t scale120) {
	if (scale120 < 60 || scale120 > 960)
		scale120 = 120;

	if (s->scale120 == scale120)
		return;

	s->scale120 = scale120;

	if (s->output) {
		struct wlr_output_state st;

		wlr_output_state_init(&st);
		wlr_output_state_set_scale(&st, (float)ceil(scale120 / 120.0));
		wlr_output_commit_state(s->output, &st);
		wlr_output_state_finish(&st);
	}

	struct window *w;

	wl_list_for_each(w, &s->windows, link) {
		wlr_xdg_surface_for_each_surface(w->xdg, scale_iter, &scale120);
		w->force_full = true;
		mark_dirty(s, w);
	}
}

static void window_free(struct window *w) {
	struct server *s = w->srv;

	if (s->pointer_win == w)
		s->pointer_win = NULL;

	if (s->focus_win == w)
		s->focus_win = NULL;

	struct window *o;

	wl_list_for_each(o, &s->windows, link) {
		if (o->parent == w)
			o->parent = NULL;
	}

	wl_list_remove(&w->link);
	wl_list_remove(&w->map.link);
	wl_list_remove(&w->unmap.link);
	wl_list_remove(&w->destroy.link);
	wl_list_remove(&w->commit.link);

	if (w->kind == WIN_TOPLEVEL) {
		wl_list_remove(&w->set_title.link);
		wl_list_remove(&w->set_app_id.link);
		wl_list_remove(&w->request_maximize.link);
		wl_list_remove(&w->request_fullscreen.link);
		wl_list_remove(&w->request_minimize.link);
		wl_list_remove(&w->request_move.link);
		wl_list_remove(&w->request_resize.link);
	}

	if (w->rbuf)
		wlr_buffer_drop(w->rbuf);

	free(w->prev);
	free(w);
}

static void send_destroy(struct server *s, struct window *w) {
	if (w->id == 0)
		return;

	if (s->ready) {
		struct wbuf b = {0};
		size_t st = wire_begin(&b, G_WINDOW_DESTROY);

		wbuf_u32(&b, w->id);
		wire_end(&b, st);
		send_message(s, &b);
		wbuf_free(&b);
	}

	w->id = 0;
}

static void on_window_map(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, map);

	w->mapped = true;
	announce_window(w->srv, w);
	mark_dirty(w->srv, w);

	/* Debug aid for hosts that can't report focus (a host window that is not the active app). */
	if (w->kind == WIN_TOPLEVEL && getenv("SEAMLESS_FORCE_FOCUS"))
		focus_window(w->srv, w, true);
}

static void on_window_unmap(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, unmap);

	w->mapped = false;
	send_destroy(w->srv, w);
	w->hints_known = false;
	free(w->prev);
	w->prev = NULL;
	w->prev_size = 0;
}

static void on_window_destroy(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, destroy);

	send_destroy(w->srv, w);
	window_free(w);
}

static void on_window_commit(struct wl_listener *l, void *data) {
	/* Handled by the global per-surface hook (it also covers subsurfaces). */
}

static void on_title(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, set_title);

	send_title(w->srv, w, G_WINDOW_TITLE, w->toplevel->title);
}

static void on_app_id(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, set_app_id);

	send_title(w->srv, w, G_WINDOW_APPID, w->toplevel->app_id);
}

/* Maximize, fullscreen and minimize belong to the host's window manager: acknowledge without changing anything. */
static void ack_request(struct window *w) {
	if (w->xdg->initialized)
		wlr_xdg_surface_schedule_configure(w->xdg);
}

static void on_request_maximize(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, request_maximize);

	ack_request(w);
}

static void on_request_fullscreen(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, request_fullscreen);

	ack_request(w);
}

static void on_request_minimize(struct wl_listener *l, void *data) {
	struct window *w = wl_container_of(l, w, request_minimize);

	ack_request(w);
}

static void on_request_ignored(struct wl_listener *l, void *data) {
}

static struct window *window_create(struct server *s, enum window_kind_internal kind, struct wlr_xdg_surface *xdg) {
	struct window *w = calloc(1, sizeof(*w));

	if (!w)
		return NULL;

	w->srv = s;
	w->kind = kind;
	w->xdg = xdg;
	xdg->data = w;
	wl_list_insert(s->windows.prev, &w->link);

	w->map.notify = on_window_map;
	wl_signal_add(&xdg->surface->events.map, &w->map);
	w->unmap.notify = on_window_unmap;
	wl_signal_add(&xdg->surface->events.unmap, &w->unmap);
	w->commit.notify = on_window_commit;
	wl_signal_add(&xdg->surface->events.commit, &w->commit);
	w->destroy.notify = on_window_destroy;

	return w;
}

static void on_new_toplevel(struct wl_listener *l, void *data) {
	struct server *s = wl_container_of(l, s, new_toplevel);
	struct wlr_xdg_toplevel *tl = data;
	struct window *w = window_create(s, WIN_TOPLEVEL, tl->base);

	if (!w)
		return;

	w->toplevel = tl;
	wl_signal_add(&tl->events.destroy, &w->destroy);
	w->set_title.notify = on_title;
	wl_signal_add(&tl->events.set_title, &w->set_title);
	w->set_app_id.notify = on_app_id;
	wl_signal_add(&tl->events.set_app_id, &w->set_app_id);
	w->request_maximize.notify = on_request_maximize;
	wl_signal_add(&tl->events.request_maximize, &w->request_maximize);
	w->request_fullscreen.notify = on_request_fullscreen;
	wl_signal_add(&tl->events.request_fullscreen, &w->request_fullscreen);
	w->request_minimize.notify = on_request_minimize;
	wl_signal_add(&tl->events.request_minimize, &w->request_minimize);
	w->request_move.notify = on_request_ignored;
	wl_signal_add(&tl->events.request_move, &w->request_move);
	w->request_resize.notify = on_request_ignored;
	wl_signal_add(&tl->events.request_resize, &w->request_resize);
}

static void on_new_popup(struct wl_listener *l, void *data) {
	struct server *s = wl_container_of(l, s, new_popup);
	struct wlr_xdg_popup *popup = data;
	struct wlr_xdg_surface *parent = popup->parent ? wlr_xdg_surface_try_from_wlr_surface(popup->parent) : NULL;
	struct window *pw = parent ? parent->data : NULL;

	if (!pw) {
		wlr_xdg_popup_destroy(popup);
		return;
	}

	struct window *w = window_create(s, WIN_POPUP, popup->base);

	if (!w)
		return;

	w->popup = popup;
	w->parent = pw;
	wl_signal_add(&popup->events.destroy, &w->destroy);
}

/* ======================================================================== input */

static void focus_window(struct server *s, struct window *w, bool focused) {
	if (focused) {
		if (s->focus_win && s->focus_win != w)
			wlr_xdg_toplevel_set_activated(s->focus_win->toplevel, false);

		s->focus_win = w;
		wlr_xdg_toplevel_set_activated(w->toplevel, true);
		wlr_seat_set_keyboard(s->seat, &s->keyboard);
		wlr_seat_keyboard_notify_enter(s->seat, root_surface_of(w), s->keyboard.keycodes, s->keyboard.num_keycodes, &s->keyboard.modifiers);
	} else if (s->focus_win == w) {
		wlr_xdg_toplevel_set_activated(w->toplevel, false);
		wlr_seat_keyboard_notify_clear_focus(s->seat);
		s->focus_win = NULL;
	}
}

static void pointer_enter_or_motion(struct server *s, struct window *w, float x, float y, bool enter) {
	struct wlr_box geo;
	double sub_x = 0, sub_y = 0;

	window_geometry(w, &geo);

	struct wlr_surface *surface = wlr_xdg_surface_surface_at(w->xdg, x + geo.x, y + geo.y, &sub_x, &sub_y);

	if (!surface) {
		wlr_seat_pointer_notify_clear_focus(s->seat);
		s->pointer_win = NULL;
		return;
	}

	s->pointer_win = w;

	if (enter || s->seat->pointer_state.focused_surface != surface) {
		wlr_seat_pointer_notify_enter(s->seat, surface, sub_x, sub_y);
	} else {
		wlr_seat_pointer_notify_motion(s->seat, now_msec(), sub_x, sub_y);
	}

	wlr_seat_pointer_notify_frame(s->seat);
}

static void on_kb_key(struct wl_listener *l, void *data) {
	struct server *s = wl_container_of(l, s, kb_key);
	struct wlr_keyboard_key_event *ev = data;

	wlr_seat_set_keyboard(s->seat, &s->keyboard);
	wlr_seat_keyboard_notify_key(s->seat, ev->time_msec, ev->keycode, ev->state);
}

static void on_kb_modifiers(struct wl_listener *l, void *data) {
	struct server *s = wl_container_of(l, s, kb_modifiers);

	wlr_seat_set_keyboard(s->seat, &s->keyboard);
	wlr_seat_keyboard_notify_modifiers(s->seat, &s->keyboard.modifiers);
}

static void on_request_set_shape(struct wl_listener *l, void *data) {
	struct server *s = wl_container_of(l, s, request_set_shape);
	struct wlr_cursor_shape_manager_v1_request_set_shape_event *ev = data;

	if (ev->device_type != WLR_CURSOR_SHAPE_MANAGER_V1_DEVICE_TYPE_POINTER || s->seat->pointer_state.focused_client != ev->seat_client)
		return;

	send_cursor(s, s->pointer_win, wlr_cursor_shape_v1_name(ev->shape));
}

static void on_request_set_cursor(struct wl_listener *l, void *data) {
	struct server *s = wl_container_of(l, s, request_set_cursor);
	struct wlr_seat_pointer_request_set_cursor_event *ev = data;

	if (s->seat->pointer_state.focused_client != ev->seat_client)
		return;

	/* Client-drawn cursor images are not streamed (yet): show a plain arrow, or nothing when asked to hide it. */
	send_cursor(s, s->pointer_win, ev->surface ? "default" : "none");
}

static void on_new_decoration(struct wl_listener *l, void *data) {
	/* The host draws the title bar: ask clients for server side decorations. */
	struct wlr_xdg_toplevel_decoration_v1 *d = data;

	if (d->toplevel->base->initialized)
		wlr_xdg_toplevel_decoration_v1_set_mode(d, WLR_XDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE);
}

/* ======================================================================== setup */

static void usage(const char *argv0) {
	fprintf(stderr,
		"usage: %s [--connect SPEC] [--socket NAME] [-v] [-- command args...]\n"
		"  --connect SPEC  vsock:PORT (default vsock:%d), unix:/path or tcp:host:port\n"
		"  --socket NAME   Wayland socket name (default: automatic)\n"
		"  -v              verbose logging\n",
		argv0, SEAMLESS_DEFAULT_VSOCK_PORT);
}

static void on_sigchld(int sig) {
	(void)sig;
}

static int on_signal(int sig, void *data) {
	struct server *s = data;

	if (sig == SIGCHLD) {
		int status;
		pid_t pid;

		while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
			if (pid == s->child)
				wl_display_terminate(s->display);
		}

		return 0;
	}

	wl_display_terminate(s->display);

	return 0;
}

int main(int argc, char **argv) {
	const char *connect_spec = NULL, *socket_name = NULL;
	enum wlr_log_importance level = WLR_INFO;
	int cmd_index = argc;

	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--") == 0) {
			cmd_index = i + 1;
			break;
		} else if (strcmp(argv[i], "--connect") == 0 && i + 1 < argc) {
			connect_spec = argv[++i];
		} else if (strcmp(argv[i], "--socket") == 0 && i + 1 < argc) {
			socket_name = argv[++i];
		} else if (strcmp(argv[i], "-v") == 0) {
			level = WLR_DEBUG;
		} else {
			usage(argv[0]);
			return 2;
		}
	}

	char default_spec[32];

	if (!connect_spec) {
		snprintf(default_spec, sizeof(default_spec), "vsock:%d", SEAMLESS_DEFAULT_VSOCK_PORT);
		connect_spec = default_spec;
	}

	wlr_log_init(level, NULL);
	signal(SIGPIPE, SIG_IGN);

	struct server *s = &srv;

	memset(s, 0, sizeof(*s));
	s->fd = -1;
	s->next_id = 1;
	s->scale120 = 120;
	s->connect_spec = connect_spec;
	wl_list_init(&s->windows);

	s->display = wl_display_create();
	s->loop = wl_display_get_event_loop(s->display);
	s->backend = wlr_headless_backend_create(s->loop);

	if (!s->backend) {
		wlr_log(WLR_ERROR, "cannot create the headless backend");
		return 1;
	}

	/* No GPU in the guest: render windows in software. */
	setenv("WLR_RENDERER", "pixman", 0);
	s->renderer = wlr_renderer_autocreate(s->backend);
	s->allocator = s->renderer ? wlr_allocator_autocreate(s->backend, s->renderer) : NULL;

	if (!s->renderer || !s->allocator) {
		wlr_log(WLR_ERROR, "cannot create the renderer");
		return 1;
	}

	wlr_renderer_init_wl_display(s->renderer, s->display);

	s->compositor = wlr_compositor_create(s->display, 6, s->renderer);
	wlr_subcompositor_create(s->display);
	wlr_data_device_manager_create(s->display);
	wlr_primary_selection_v1_device_manager_create(s->display);
	wlr_viewporter_create(s->display);
	s->fractional = wlr_fractional_scale_manager_v1_create(s->display, 1);
	s->cursor_shape = wlr_cursor_shape_manager_v1_create(s->display, 1);
	s->layout = wlr_output_layout_create(s->display);
	wlr_xdg_output_manager_v1_create(s->display, s->layout);
	s->xdg_shell = wlr_xdg_shell_create(s->display, 6);
	s->decoration_manager = wlr_xdg_decoration_manager_v1_create(s->display);
	s->seat = wlr_seat_create(s->display, "seat0");

	/* One big virtual output so maximize/popup placement has room; the host window size is what matters. */
	s->output = wlr_headless_add_output(s->backend, 3840, 2160);

	if (s->output) {
		wlr_output_init_render(s->output, s->allocator, s->renderer);

		struct wlr_output_state st;

		wlr_output_state_init(&st);
		wlr_output_state_set_enabled(&st, true);
		wlr_output_state_set_custom_mode(&st, 3840, 2160, 0);
		wlr_output_commit_state(s->output, &st);
		wlr_output_state_finish(&st);
		wlr_output_layout_add_auto(s->layout, s->output);
		wlr_output_create_global(s->output, s->display);
	}

	/* A virtual keyboard: the host sends evdev key codes, xkb turns them into symbols and modifiers. */
	static const struct wlr_keyboard_impl kb_impl = {.name = "seamless-keyboard"};

	wlr_keyboard_init(&s->keyboard, &kb_impl, "seamless-keyboard");
	s->xkb = xkb_context_new(XKB_CONTEXT_NO_FLAGS);

	struct xkb_rule_names rules = {0}; /* XKB_DEFAULT_LAYOUT & co. from the environment, "us" otherwise */
	struct xkb_keymap *keymap = xkb_keymap_new_from_names(s->xkb, &rules, XKB_KEYMAP_COMPILE_NO_FLAGS);

	if (!keymap) {
		wlr_log(WLR_ERROR, "cannot compile the XKB keymap: the guest needs the XKB data files (Debian/Ubuntu: xkb-data, Fedora/Alpine: xkeyboard-config)");
		return 1;
	}

	wlr_keyboard_set_keymap(&s->keyboard, keymap);
	xkb_keymap_unref(keymap);
	wlr_keyboard_set_repeat_info(&s->keyboard, 25, 600);
	wlr_seat_set_capabilities(s->seat, WL_SEAT_CAPABILITY_POINTER | WL_SEAT_CAPABILITY_KEYBOARD);
	wlr_seat_set_keyboard(s->seat, &s->keyboard);

	s->kb_key.notify = on_kb_key;
	wl_signal_add(&s->keyboard.events.key, &s->kb_key);
	s->kb_modifiers.notify = on_kb_modifiers;
	wl_signal_add(&s->keyboard.events.modifiers, &s->kb_modifiers);

	s->new_surface.notify = on_new_surface;
	wl_signal_add(&s->compositor->events.new_surface, &s->new_surface);
	s->new_toplevel.notify = on_new_toplevel;
	wl_signal_add(&s->xdg_shell->events.new_toplevel, &s->new_toplevel);
	s->new_popup.notify = on_new_popup;
	wl_signal_add(&s->xdg_shell->events.new_popup, &s->new_popup);
	s->request_set_shape.notify = on_request_set_shape;
	wl_signal_add(&s->cursor_shape->events.request_set_shape, &s->request_set_shape);
	s->request_set_cursor.notify = on_request_set_cursor;
	wl_signal_add(&s->seat->events.request_set_cursor, &s->request_set_cursor);

	s->new_decoration.notify = on_new_decoration;
	wl_signal_add(&s->decoration_manager->events.new_toplevel_decoration, &s->new_decoration);

	if (!wlr_backend_start(s->backend)) {
		wlr_log(WLR_ERROR, "cannot start the backend");
		return 1;
	}

	const char *sock = socket_name ? socket_name : wl_display_add_socket_auto(s->display);

	if (socket_name && wl_display_add_socket(s->display, socket_name) != 0) {
		wlr_log(WLR_ERROR, "cannot create the wayland socket %s", socket_name);
		return 1;
	}

	if (!sock) {
		wlr_log(WLR_ERROR, "cannot create a wayland socket (is XDG_RUNTIME_DIR set?)");
		return 1;
	}

	setenv("WAYLAND_DISPLAY", sock, 1);
	wlr_log(WLR_INFO, "seamless compositor on WAYLAND_DISPLAY=%s, host at %s", sock, connect_spec);

	s->frame_timer = wl_event_loop_add_timer(s->loop, on_frame_timer, s);
	s->reconnect_timer = wl_event_loop_add_timer(s->loop, on_reconnect_timer, s);
	wl_event_source_timer_update(s->reconnect_timer, 1);

	wl_event_loop_add_signal(s->loop, SIGINT, on_signal, s);
	wl_event_loop_add_signal(s->loop, SIGTERM, on_signal, s);
	wl_event_loop_add_signal(s->loop, SIGCHLD, on_signal, s);
	signal(SIGCHLD, on_sigchld);

	if (cmd_index < argc) {
		s->child = fork();

		if (s->child == 0) {
			execvp(argv[cmd_index], &argv[cmd_index]);
			perror(argv[cmd_index]);
			_exit(127);
		}
	}

	wl_display_run(s->display);

	transport_close(s);
	wl_display_destroy_clients(s->display);
	wl_display_destroy(s->display);

	return 0;
}
