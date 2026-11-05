// SPDX-License-Identifier: MIT

#ifndef __VIRTUAL_FLY__
#define __VIRTUAL_FLY__

#include <IOKit/IOService.h>
#include "virtual_fly_config.h"

class VirtualFly : public IOService
{
    OSDeclareDefaultStructors(VirtualFly)
    public:
        virtual bool start(IOService *provider) override;

        virtual bool handleOpen(
                            IOService       *forClient,
                            IOOptionBits     options,
                            void            *arg) override;
};

#endif /* __VIRTUAL_FLY__ */
