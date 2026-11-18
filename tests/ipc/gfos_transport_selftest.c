/* Single-process Exec-transport roundtrip. Guest execution is mandatory. */
#include "gfos_transport.h"
#include <string.h>
#include <stdio.h>
int main(void)
{
    GFOSPort server, replies;
    GFOSMessage *message, *request, *response;
    int rc = 1, hasServer = 0, hasReplies = 0;
    if (gfos_port_create(&server,"GFOS.FOUNDATION.TRANSPORT.TEST")) return 2;
    hasServer = 1;
    if (gfos_port_create(&replies,NULL)) goto finish;
    hasReplies = 1;
    message = gfos_message_alloc(12, 17);
    if (!message) goto finish;
    memcpy(message->payload, "hello-gfos!", 12);
    if (gfos_port_send(server.name,&replies,message)) { gfos_message_free(message); goto finish; }
    if (gfos_port_send(server.name,&replies,message) == 0) goto finish; /* no double queue */
    if (gfos_message_free(message) == 0) goto finish; /* cannot free in flight */
    if (gfos_port_close(&replies) == 0) goto finish; /* cannot drop reply port */
    request = gfos_port_receive(&server);
    if (!request || request != message || request->requestId != 17 ||
        memcmp(request->payload,"hello-gfos!",12)) {
        if (request) gfos_message_reply(request, 9);
        response = gfos_port_poll_reply(&replies);
        if (response) gfos_message_free(response);
        goto finish;
    }
    gfos_message_reply(request, 42);
    response = gfos_port_poll_reply(&replies);
    if (!response || response != message || response->status != 42 || response->state != 2) {
        if (response) gfos_message_free(response);
        goto finish;
    }
    if (gfos_message_free(response)) goto finish;
    if (replies.outgoing != 0) goto finish;
    puts("GFOS_TRANSPORT_ROUNDTRIP_PASS");
    rc = 0;
finish:
    if (hasServer) gfos_port_close(&server);
    if (hasReplies) gfos_port_close(&replies);
    return rc;
}
