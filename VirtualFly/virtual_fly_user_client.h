// SPDX-License-Identifier: MIT

#ifndef __VIRTUAL_FLY_USER_CLIENT__
#define __VIRTUAL_FLY_USER_CLIENT__

#include <IOKit/IOUserClient.h>
#include "virtual_fly_config.h"

class VirtualFly;
class VirtualFlyDevice;

class VirtualFlyUserClient : public IOUserClient
{
    OSDeclareDefaultStructors(VirtualFlyUserClient)
    public:
        virtual bool initWithTask(
                            task_t           owningTask,
                            void            *securityToken,
                            UInt32           type,
                            OSDictionary    *properties) override;

        virtual bool start(IOService *provider) override;
        virtual void stop(IOService *provider) override;

        virtual IOReturn clientClose() override;
        virtual bool didTerminate(IOService *provider, IOOptionBits options, bool *defer) override;

        virtual IOReturn externalMethod(
                                    uint32_t                     selector,
                                    IOExternalMethodArguments   *arguments,
									IOExternalMethodDispatch    *dispatch,
                                    OSObject                    *target,
                                    void                        *reference) override;

    protected:
        virtual void free() override;

    private:
        static const size_t                     externalMethodCount = 6;
        static const IOExternalMethodDispatch   externalMethodDispatchTable[externalMethodCount];

        VirtualFly          *m_Owner;
        VirtualFlyDevice    *m_Device;
        OSString            *m_DeviceProductString;
        OSString            *m_DeviceSerialNumberString;
        uint32_t             m_DeviceVendorID;
        uint32_t             m_DeviceProductID;

        static IOReturn _enableDevice(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args);
        static IOReturn _disableDevice(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args);
        static IOReturn _updateDeviceState(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args);
        static IOReturn _setDeviceProductString(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args);
        static IOReturn _setDeviceSerialNumberString(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args);
        static IOReturn _setDeviceVendorAndProductID(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args);

        bool openOwner(VirtualFly *owner);
        bool closeOwner();

        IOReturn enableDevice(const void *hidDescriptorData, uint32_t hidDescriptorDataSize);
        IOReturn disableDevice();
        IOReturn updateDeviceState(const void *hidData, uint32_t hidDataSize);
        IOReturn setDeviceProductString(const void *productString, uint32_t productStringSize);
        IOReturn setDeviceSerialNumberString(const void *serialNumberString, uint32_t serialNumberStringSize);
        IOReturn setDeviceVendorAndProductID(uint32_t vendorID, uint32_t productID);
};

#endif /* __VIRTUAL_FLY_USER_CLIENT__ */
