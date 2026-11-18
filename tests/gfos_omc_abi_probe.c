/* Compile-only GFOS/Oolite interface check against Team 4 canonical API.
 * NO runtime or card qualification implied. */
#include <libraries/gfopenmulticore.h>
#include <exec/libraries.h>
int gfos_omc_abi_probe(struct Library *base)
{
    struct OMCJob job = {0};
    struct OMCGrant grant = {0};
    job.omj_Target = OMC_ANY;
    job.omj_Flags = OMCF_STRICT;
    grant.og_Mode = OMCG_READ | OMCG_WRITE;
    if (OMC_HAS_JOBCALLS(base)) job.omj_TimeoutMS = OMC_DEFAULTTIMEOUT;
    if (OMC_HAS_RANGE(base)) job.omj_NArgs = OMC_RANGEMAXARGS;
    return (int)(sizeof(job) + sizeof(grant) + OMC_GRANTSIZE(16));
}
