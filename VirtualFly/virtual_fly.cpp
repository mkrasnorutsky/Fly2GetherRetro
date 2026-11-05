// SPDX-License-Identifier: MIT

#include "virtual_fly.h"
#include "virtual_fly_debug.h"

#define super IOService

OSDefineMetaClassAndStructors(VirtualFly, super)
 
bool VirtualFly::start(IOService *provider)
{
    if(!super::start(provider))
        return false;

    registerService();
    dmsg("started");
    return true;
}

bool VirtualFly::handleOpen(
                        IOService       *forClient,
                        IOOptionBits     options,
                        void            *arg)
{
    dmsg("handleOpen");
    return (!isOpen(forClient));
}
