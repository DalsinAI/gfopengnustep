/* GFOpenGNUstep GFOS native message transport — API draft v1.
 * Copyright 2026 DalsinAI. Released under LGPL-2.0-or-later.
 * No POSIX AF_UNIX / socket emulation.
 */
#ifndef GFOS_GNUSTEP_TRANSPORT_H
#define GFOS_GNUSTEP_TRANSPORT_H
#include <exec/types.h>
#include <exec/ports.h>

#define GFOS_PORT_MAGIC 0x47465031UL /* GFP1 */
#define GFOS_PORT_MAX_PAYLOAD 32768UL

typedef struct GFOSPort {
    struct MsgPort *execPort;
    char *name;
    int publicPort;
    ULONG outgoing; /* messages sent via this reply port awaiting delivery */
} GFOSPort;

typedef struct GFOSMessage {
    struct Message execMessage;
    ULONG magic;
    ULONG payloadLength;
    ULONG requestId;
    ULONG status;
    ULONG state; /* NEW=0, IN_FLIGHT=1, REPLIED=2 */
    UBYTE payload[1];
} GFOSMessage;

/* All functions return 0 for success, nonzero for failure. */
int gfos_port_create(GFOSPort *out, const char *publicName);
int gfos_port_close(GFOSPort *port); /* refuses closure if outgoing != 0 */
GFOSMessage *gfos_message_alloc(ULONG payloadBytes, ULONG requestId);
int gfos_message_free(GFOSMessage *message); /* refuses in-flight messages */
int gfos_port_send(const char *destinationName, GFOSPort *replyTo,
                   GFOSMessage *message);
GFOSMessage *gfos_port_receive(GFOSPort *port);
void gfos_message_reply(GFOSMessage *message, ULONG status);
GFOSMessage *gfos_port_poll_reply(GFOSPort *port);

/* Caller ownership: never free or reuse a sent message before its reply.
 * Caller must keep replyTo alive until all outstanding replies are received.
 * No bounded wait/timeout or run-loop yet: these are next integration gates.
 */
#endif
