// SPDX-License-Identifier: MIT

#include "virtual_fly.h"
#include "virtual_fly_user_client.h"
#include "virtual_fly_device.h"
#include "virtual_fly_debug.h"

#define super IOUserClient

OSDefineMetaClassAndStructors(VirtualFlyUserClient, super)

const IOExternalMethodDispatch VirtualFlyUserClient::externalMethodDispatchTable[externalMethodCount] =
{
    {
        (IOExternalMethodAction) VirtualFlyUserClient::_enableDevice,
        0, kIOUCVariableStructureSize, 0, 0
    },

    {
        (IOExternalMethodAction) VirtualFlyUserClient::_disableDevice,
        0, 0, 0, 0
    },

    {
        (IOExternalMethodAction) VirtualFlyUserClient::_updateDeviceState,
        0, kIOUCVariableStructureSize, 0, 0
    },

    {
        (IOExternalMethodAction) VirtualFlyUserClient::_setDeviceProductString,
        0, kIOUCVariableStructureSize, 0, 0
    },

    {
        (IOExternalMethodAction) VirtualFlyUserClient::_setDeviceSerialNumberString,
        0, kIOUCVariableStructureSize, 0, 0
    },

    {
        (IOExternalMethodAction) VirtualFlyUserClient::_setDeviceVendorAndProductID,
        0, kIOUCVariableStructureSize, 0, 0
    }
};

static bool checkString(const char *str, size_t maxLength)
{
    while(maxLength > 0)
    {
        if(*str == 0)
            return true;

        maxLength--;
        str++;
    }

    return false;
}

IOReturn VirtualFlyUserClient::_enableDevice(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args)
{
    return target->enableDevice(args->structureInput, args->structureInputSize);
}

IOReturn VirtualFlyUserClient::_disableDevice(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args)
{
    return target->disableDevice();
}

IOReturn VirtualFlyUserClient::_updateDeviceState(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args)
{
    return target->updateDeviceState(args->structureInput, args->structureInputSize);
}

IOReturn VirtualFlyUserClient::_setDeviceProductString(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args)
{
    return target->setDeviceProductString(args->structureInput, args->structureInputSize);
}

IOReturn VirtualFlyUserClient::_setDeviceSerialNumberString(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args)
{
    return target->setDeviceSerialNumberString(args->structureInput, args->structureInputSize);
}

IOReturn VirtualFlyUserClient::_setDeviceVendorAndProductID(VirtualFlyUserClient *target, void *reference, IOExternalMethodArguments *args)
{
    const char *data        = static_cast< const char* >(args->structureInput);
    size_t      dataSize    = args->structureInputSize;

    if(data == 0 || dataSize < (sizeof(uint32_t) * 2))
        return kIOReturnBadArgument;

    uint32_t vendorID   = 0;
    uint32_t productID  = 0;

    memcpy(&vendorID, data, sizeof(int32_t));
    memcpy(&productID, data + sizeof(uint32_t), sizeof(uint32_t));

    return target->setDeviceVendorAndProductID(vendorID, productID);
}

bool VirtualFlyUserClient::openOwner(VirtualFly *owner)
{
    if(owner == 0 || isInactive())
        return false;

    if(!owner->open(this))
        return false;

    m_Owner = owner;
    return true;
}

bool VirtualFlyUserClient::closeOwner()
{
    if(m_Owner != 0)
    {
        if(m_Owner->isOpen(this))
            m_Owner->close(this);

        m_Owner = 0;
    }

    disableDevice();
    return true;
}

bool VirtualFlyUserClient::initWithTask(
                                task_t           owningTask,
                                void            *securityToken,
                                UInt32           type,
                                OSDictionary    *properties)
{
    if(!super::initWithTask(owningTask, securityToken, type, properties))
        return false;

    m_Owner                     = 0;
    m_Device                    = 0;
    m_DeviceProductString       = OSString::withCString("VFly Virtual HID Device");
    m_DeviceSerialNumberString  = OSString::withCString("000000000000");
    m_DeviceVendorID            = 0;
    m_DeviceProductID           = 0;

    dmsg("initWithTask");
    return true;
}

void VirtualFlyUserClient::free()
{
    if(m_DeviceProductString != 0)
        m_DeviceProductString->release();

    if(m_DeviceSerialNumberString != 0)
        m_DeviceSerialNumberString->release();

    dmsg("free");
    super::free();
}

bool VirtualFlyUserClient::start(IOService *provider)
{
    VirtualFly *owner = OSDynamicCast(VirtualFly, provider);
    if(owner == 0)
        return false;

    if(!super::start(provider))
        return false;

    if(!openOwner(owner))
    {
        super::stop(provider);
        return false;
    }

    dmsgf("start, provider: %p", provider);
    return true;
}

void VirtualFlyUserClient::stop(IOService *provider)
{
    dmsgf("stop, provider: %p", provider);
    closeOwner();
    super::stop(provider);
}

IOReturn VirtualFlyUserClient::clientClose()
{
    dmsg("clientClose");
    closeOwner();
    terminate();
    return kIOReturnSuccess;
}

bool VirtualFlyUserClient::didTerminate(IOService *provider, IOOptionBits options, bool *defer)
{
    dmsg("didTerminate");
    closeOwner();
	*defer = false;
	return super::didTerminate(provider, options, defer);
}

IOReturn VirtualFlyUserClient::externalMethod(
                                    uint32_t                     selector,
                                    IOExternalMethodArguments   *arguments,
									IOExternalMethodDispatch    *dispatch,
                                    OSObject                    *target,
                                    void                        *reference)
{
    dmsg("externalMehtod");

    if(selector < externalMethodCount)
    {
        dispatch = const_cast< IOExternalMethodDispatch* >(&externalMethodDispatchTable[selector]);
        if(target == 0)
            target = this;
    }
        
	return super::externalMethod(selector, arguments, dispatch, target, reference);
}

IOReturn VirtualFlyUserClient::enableDevice(const void *hidDescriptorData, uint32_t hidDescriptorDataSize)
{
    dmsgf("enableDevice, param size = %d", hidDescriptorDataSize);

    if(m_Device != 0)
    {
        IOReturn result = disableDevice();
        if(result != kIOReturnSuccess)
            return result;
    }

    m_Device = VirtualFlyDevice::withHidDescriptor(
                                            hidDescriptorData,
                                            hidDescriptorDataSize,
                                            m_DeviceProductString,
                                            m_DeviceSerialNumberString,
                                            m_DeviceVendorID,
                                            m_DeviceProductID);

    if(m_Device == 0)
        return kIOReturnDeviceError;

    if(!m_Device->attach(this))
    {
        m_Device->release();
        m_Device = 0;
        return kIOReturnDeviceError;
    }

    if(!m_Device->start(this))
    {
        m_Device->detach(this);
        m_Device->release();
        m_Device = 0;
        return kIOReturnDeviceError;
    }

    return kIOReturnSuccess;
}

IOReturn VirtualFlyUserClient::disableDevice()
{
    dmsg("disableDevice");

    if(m_Device != 0)
    {
        m_Device->terminate(kIOServiceRequired);
        m_Device->release();
        m_Device = 0;
    }

    return kIOReturnSuccess;
}

IOReturn VirtualFlyUserClient::updateDeviceState(const void *hidData, uint32_t hidDataSize)
{
    // dmsgf("updateDeviceState, param size = %d", hidDataSize);

    if(m_Device == 0)
        return kIOReturnNoDevice;

    if(!m_Device->updateState(hidData, hidDataSize))
        return kIOReturnDeviceError;

    return kIOReturnSuccess;
}

IOReturn VirtualFlyUserClient::setDeviceProductString(const void *productString, uint32_t productStringSize)
{
    dmsgf("setDeviceProductString, productString size = %d", productStringSize);

    if(m_Device != 0)
        return kIOReturnBusy;

    if(!checkString(static_cast< const char* >(productString), productStringSize))
        return kIOReturnInvalid;

    OSString *newStr = OSString::withCString(static_cast< const char* >(productString));
    if(newStr == 0)
        return kIOReturnNoMemory;

    if(m_DeviceProductString != 0)
        m_DeviceProductString->release();

    m_DeviceProductString = newStr;

    dmsgf("newProductString = %s", newStr->getCStringNoCopy());
    return kIOReturnSuccess;
}

IOReturn VirtualFlyUserClient::setDeviceSerialNumberString(const void *serialNumberString, uint32_t serialNumberStringSize)
{
    dmsgf("setDeviceSerialNumberString, serialNumberString size = %d", serialNumberStringSize);

    if(m_Device != 0)
        return kIOReturnBusy;

    if(!checkString(static_cast< const char* >(serialNumberString), serialNumberStringSize))
        return kIOReturnInvalid;

    OSString *newStr = OSString::withCString(static_cast< const char* >(serialNumberString));
    if(newStr == 0)
        return kIOReturnNoMemory;

    if(m_DeviceSerialNumberString != 0)
        m_DeviceSerialNumberString->release();

    m_DeviceSerialNumberString = newStr;

    dmsgf("newSerialNumberString = %s", newStr->getCStringNoCopy());
    return kIOReturnSuccess;
}

IOReturn VirtualFlyUserClient::setDeviceVendorAndProductID(uint32_t vendorID, uint32_t productID)
{
    dmsgf("setDeviceVendorAndProductID, vendorID = %d, productID = %d", vendorID, productID);

    if(m_Device != 0)
        return kIOReturnBusy;

    m_DeviceVendorID    = vendorID;
    m_DeviceProductID   = productID;

    return kIOReturnSuccess;
}
