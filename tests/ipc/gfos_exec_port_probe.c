/* GFOpenGNUstep native IPC transport qualification, GFOS / AmigaOS 3.x.
 * Real Exec named message ports, *not* AF_UNIX socket emulation.
 * Guest execution is required before relying on it for Foundation ports.
 */
#include <stdio.h>
#include <string.h>
#include <exec/types.h>
#include <exec/ports.h>
#include <proto/exec.h>

struct GFProbeMessage {
    struct Message msg;
    ULONG magic;
    UBYTE payload[32];
};

int main(void)
{
    struct MsgPort *server = NULL, *replies = NULL, *found;
    struct Message *request;
    struct GFProbeMessage packet;
    int registered = 0, result = 1;
    const char *name = "GFOS.FOUNDATION.IPC.PROBE";

    server = CreateMsgPort();
    replies = CreateMsgPort();
    if (!server || !replies) goto cleanup;

    /* Search/register while task switches are inhibited, to avoid duplicate
     * names. This sample remains single-task; the real backend must add
     * close/in-flight lifetime control for concurrent users. */
    Forbid();
    if (!FindPort(name)) {
        server->mp_Node.ln_Name = (STRPTR)name;
        AddPort(server);
        registered = 1;
    }
    Permit();
    if (!registered) goto cleanup;

    memset(&packet, 0, sizeof(packet));
    packet.msg.mn_ReplyPort = replies;
    packet.msg.mn_Length = sizeof(packet);
    packet.magic = 0x47465350UL;  /* GFSP */
    memcpy(packet.payload, "Foundation", 11);

    Forbid();
    found = FindPort(name);
    if (found == server) PutMsg(found, &packet.msg);
    Permit();
    if (found != server) goto cleanup;

    request = GetMsg(server);
    if (request != &packet.msg || packet.magic != 0x47465350UL) goto cleanup;
    ReplyMsg(request);
    if (GetMsg(replies) != &packet.msg) goto cleanup;

    puts("GFOS_EXEC_PORT_PROBE_PASS");
    result = 0;
cleanup:
    if (registered) RemPort(server);
    /* Drain our single-threaded probe's queues before deleting. Production
     * shutdown must also coordinate concurrent tasks and in-flight replies. */
    if (server) {
        while ((request = GetMsg(server)) != NULL) {
            if (request->mn_ReplyPort) ReplyMsg(request);
        }
    }
    if (replies) {
        while (GetMsg(replies) != NULL) { }
    }
    if (server) DeleteMsgPort(server);
    if (replies) DeleteMsgPort(replies);
    return result;
}
