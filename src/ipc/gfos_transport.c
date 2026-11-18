/* GFOpenGNUstep GFOS native message transport — implementation draft v1.
 * Copyright 2026 DalsinAI. LGPL-2.0-or-later.
 * References public MsgPort under Forbid() only during lookup and PutMsg(),
 * protecting against concurrent RemPort() before delivery. Do not wait under
 * Forbid(); clients poll their own reply port asynchronously.
 */
#include "gfos_transport.h"
#include <stddef.h>
#include <string.h>
#include <proto/exec.h>

#define GFOS_HDR ((ULONG)offsetof(GFOSMessage, payload))

int gfos_port_create(GFOSPort *out, const char *publicName)
{
    struct MsgPort *port;
    ULONG n = 0;
    char *name = NULL;
    if (!out) return -1;
    memset(out, 0, sizeof(*out));
    if (publicName) {
        n = (ULONG)strlen(publicName);
        if (!n || n > 128) return -2;
        name = (char *)AllocVec(n + 1, MEMF_PUBLIC);
        if (!name) return -3;
        memcpy(name, publicName, n + 1);
    }
    port = CreateMsgPort();
    if (!port) { if (name) FreeVec(name); return -4; }
    if (name) {
        Forbid();
        if (FindPort(name)) {
            Permit();
            DeleteMsgPort(port);
            FreeVec(name);
            return -5;
        }
        port->mp_Node.ln_Name = name;
        AddPort(port);
        Permit();
    }
    out->execPort = port;
    out->name = name;
    out->publicPort = name != NULL;
    return 0;
}

/* Close is only legal once the application has stopped new dispatch and
 * all request ownership/replies are complete. It returns no success flag;
 * production NSMessagePort will add in-flight lifetime accounting. */
int gfos_port_close(GFOSPort *port)
{
    struct Message *item;
    if (!port || !port->execPort) return -1;
    if (port->outgoing) return -2;
    if (port->publicPort) {
        Forbid();
        RemPort(port->execPort);
        Permit();
    }
    while ((item = GetMsg(port->execPort)) != NULL) {
        /* Private reply queues must never bounce an acknowledgement again. */
        if (port->publicPort && item->mn_ReplyPort) ReplyMsg(item);
    }
    DeleteMsgPort(port->execPort);
    if (port->name) FreeVec(port->name);
    memset(port, 0, sizeof(*port));
    return 0;
}

GFOSMessage *gfos_message_alloc(ULONG payloadBytes, ULONG requestId)
{
    GFOSMessage *message;
    ULONG bytes = GFOS_HDR + payloadBytes;
    if (payloadBytes > GFOS_PORT_MAX_PAYLOAD || bytes > 65535UL)
        return NULL; /* Exec Message.mn_Length is UWORD. */
    message = (GFOSMessage *)AllocVec(bytes, MEMF_PUBLIC | MEMF_CLEAR);
    if (!message) return NULL;
    message->execMessage.mn_Length = (UWORD)bytes;
    message->magic = GFOS_PORT_MAGIC;
    message->payloadLength = payloadBytes;
    message->requestId = requestId;
    return message;
}

int gfos_message_free(GFOSMessage *message)
{
    if (!message) return -1;
    if (message->state == 1) return -2;
    FreeVec(message);
    return 0;
}

int gfos_port_send(const char *destinationName, GFOSPort *replyTo,
                   GFOSMessage *message)
{
    struct MsgPort *dest;
    if (!destinationName || !replyTo || !replyTo->execPort ||
        !message || message->magic != GFOS_PORT_MAGIC ||
        message->payloadLength > GFOS_PORT_MAX_PAYLOAD ||
        message->state != 0 ||
        message->execMessage.mn_Length != GFOS_HDR + message->payloadLength)
        return -1;
    message->execMessage.mn_ReplyPort = replyTo->execPort;
    Forbid();
    dest = FindPort(destinationName);
    if (dest) {
        message->state = 1;
        replyTo->outgoing++;
        PutMsg(dest, &message->execMessage);
    } else {
        message->execMessage.mn_ReplyPort = NULL;
    }
    Permit();
    return dest ? 0 : -2;
}

GFOSMessage *gfos_port_receive(GFOSPort *port)
{
    struct Message *item;
    GFOSMessage *message;
    if (!port || !port->execPort) return NULL;
    item = GetMsg(port->execPort);
    if (!item) return NULL;
    message = (GFOSMessage *)item;
    if (item->mn_Length < GFOS_HDR || message->magic != GFOS_PORT_MAGIC ||
        message->payloadLength > GFOS_PORT_MAX_PAYLOAD ||
        message->state != 1 ||
        item->mn_Length != GFOS_HDR + message->payloadLength) {
        /* Return ownership to caller even when message is malformed. */
        if (item->mn_ReplyPort) ReplyMsg(item);
        return NULL;
    }
    return message;
}

void gfos_message_reply(GFOSMessage *message, ULONG status)
{
    if (!message || !message->execMessage.mn_ReplyPort) return;
    message->status = status;
    ReplyMsg(&message->execMessage);
}

GFOSMessage *gfos_port_poll_reply(GFOSPort *port)
{
    GFOSMessage *message = gfos_port_receive(port);
    if (message) {
        message->state = 2;
        if (port->outgoing) port->outgoing--;
    }
    return message;
}
