// SPDX-License-Identifier: MIT

#include "virtual_fly_device.h"
#include "virtual_fly_debug.h"

//#include <IOKit/usb/IOUSBHIDDriver.h>
#define kMaxHIDReportSize 256

#define super IOHIDDevice

OSDefineMetaClassAndStructors(VirtualFlyDevice, super)

bool VirtualFlyDevice::parseHidDescriptor(
                                const void *hidDescriptorData,
                                size_t      hidDescriptorDataSize)
{
    HIDPreparsedDataRef preparsedDataRef = 0;

    if(HIDOpenReportDescriptor(
                         const_cast< void* >(hidDescriptorData),
                         hidDescriptorDataSize,
                        &preparsedDataRef, 0) != kIOReturnSuccess)
    {
        return false;
    }

    bool result = (HIDGetCapabilities(preparsedDataRef, &m_Capabilities) == kIOReturnSuccess);
    HIDCloseReportDescriptor(preparsedDataRef);
    return result;
}

VirtualFlyDevice *VirtualFlyDevice::withHidDescriptor(
                                const void *hidDescriptorData,
                                size_t      hidDescriptorDataSize,
                                OSString   *productString,
                                OSString   *serialNumberString,
                                uint32_t    vendorID,
                                uint32_t    productID)
{
    VirtualFlyDevice *result = new VirtualFlyDevice();

    if(result != 0)
    {
        if(!result->init(hidDescriptorData, hidDescriptorDataSize, productString, serialNumberString, vendorID, productID))
        {
            result->release();
            result = 0;
        }
    }

    return result;
}

bool VirtualFlyDevice::init(
                const void      *hidDescriptorData,
                size_t           hidDescriptorDataSize,
                OSString        *productString,
                OSString        *serialNumberString,
                uint32_t         vendorID,
                uint32_t         productID,
                OSDictionary    *dictionary)
{
    m_ProductString         = 0;
    m_SerialNumberString    = 0;
    m_VendorID              = vendorID;
    m_ProductID             = productID;
    m_HIDReportDescriptor   = 0;
    m_StateBuffer           = 0;

    if(productString     == 0 ||
       hidDescriptorData == 0)
    {
        return false;
    }

    if(!super::init(dictionary))
        return false;

    if(!parseHidDescriptor(hidDescriptorData, hidDescriptorDataSize))
        return false;

    if(m_Capabilities.inputReportByteLength > kMaxHIDReportSize)
        return false;

    if(m_Capabilities.usagePage == kHIDPage_GenericDesktop)
    {
       if(m_Capabilities.usage == kHIDUsage_GD_Mouse ||
          m_Capabilities.usage == kHIDUsage_GD_Keyboard)
        {
            // hack for Apple HID subsystem
            OSString *str = OSString::withCString(
                                        (m_Capabilities.usage == kHIDUsage_GD_Mouse)?
                                            ("Mouse"):
                                            ("Keyboard"));

            if(str == NULL)
                return false;

            if(!setProperty("HIDDefaultBehavior", str))
            {
                str->release();
                return false;
            }

            str->release();
        }
    }

    m_HIDReportDescriptor = IOBufferMemoryDescriptor::withBytes(
                                                        hidDescriptorData,
                                                        hidDescriptorDataSize,
                                                        kIODirectionInOut);

    if(m_HIDReportDescriptor == 0)
        return false;

    m_StateBuffer = IOBufferMemoryDescriptor::withCapacity(
                                                m_Capabilities.inputReportByteLength,
                                                kIODirectionInOut);

    if(m_StateBuffer == 0)
        return false;

    memset(m_StateBuffer->getBytesNoCopy(), 0, m_StateBuffer->getLength());

    {
        static uint32_t lastId = locationIdBase;

        lastId++;
        m_LocationID = lastId;
    }

    m_ProductString         = productString;
    m_SerialNumberString    = serialNumberString;

    m_SerialNumberString->retain();
    m_ProductString->retain();

    dmsg("init");
    return true;
}

IOReturn VirtualFlyDevice::newReportDescriptor(IOMemoryDescriptor **descriptor) const
{
    IOBufferMemoryDescriptor *result = IOBufferMemoryDescriptor::withBytes(
                                                                    m_HIDReportDescriptor->getBytesNoCopy(),
                                                                    m_HIDReportDescriptor->getLength(),
                                                                    kIODirectionInOut);

    if(result == 0)
        return kIOReturnError;

    *descriptor = result;
	return kIOReturnSuccess;
}

OSString *VirtualFlyDevice::newTransportString() const
{
	return OSString::withCString("Virtual");
}

OSString *VirtualFlyDevice::newManufacturerString() const
{
    return OSString::withCString("mkrasnorutsky");
}

OSString *VirtualFlyDevice::newProductString() const
{
    return OSString::withString(m_ProductString);
}

OSString *VirtualFlyDevice::newSerialNumberString() const
{
	return OSString::withString(m_SerialNumberString);
}

OSNumber *VirtualFlyDevice::newVersionNumber() const
{
	return OSNumber::withNumber(1, 32);
}

OSNumber *VirtualFlyDevice::newSerialNumber() const
{
	uint32_t number = 0;
	return OSNumber::withNumber(number, 32);
}

OSNumber *VirtualFlyDevice::newVendorIDNumber() const
{
	return OSNumber::withNumber(m_VendorID, 32);
}

OSNumber *VirtualFlyDevice::newProductIDNumber() const
{
	return OSNumber::withNumber(m_ProductID, 32);
}

OSNumber *VirtualFlyDevice::newPrimaryUsageNumber() const
{
    return OSNumber::withNumber(m_Capabilities.usage, 32);
}

OSNumber *VirtualFlyDevice::newPrimaryUsagePageNumber() const
{
    return OSNumber::withNumber(m_Capabilities.usagePage, 32);
}

OSNumber *VirtualFlyDevice::newLocationIDNumber() const
{
    return OSNumber::withNumber(m_LocationID, 32);
}

OSNumber *VirtualFlyDevice::newVendorIDSourceNumber() const
{
	uint32_t number = 0;
	return OSNumber::withNumber(number, 32);
}

OSNumber *VirtualFlyDevice::newCountryCodeNumber() const
{
	uint32_t number = 0;
	return OSNumber::withNumber(number, 32);
}

bool VirtualFlyDevice::updateState(const void *hidData, size_t hidDataSize)
{
    if(m_StateBuffer->getLength() != hidDataSize)
        return false;

    memcpy(m_StateBuffer->getBytesNoCopy(), hidData, hidDataSize);
    return (handleReport(m_StateBuffer) == kIOReturnSuccess);
}

void VirtualFlyDevice::free()
{
    if(m_ProductString != 0)
        m_ProductString->release();

    if(m_SerialNumberString != 0)
        m_SerialNumberString->release();

    if(m_HIDReportDescriptor != 0)
        m_HIDReportDescriptor->release();

    if(m_StateBuffer != 0)
        m_StateBuffer->release();

    dmsg("free");
    super::free();
}
