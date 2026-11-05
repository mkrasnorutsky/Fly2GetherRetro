// SPDX-License-Identifier: MIT

#ifndef __VIRTUAL_FLY_DEBUG__
#define __VIRTUAL_FLY_DEBUG__

#include <libkern/libkern.h>

#ifdef DEBUG

    #define dmsg(message) \
                printf("%s - %s (%d): %s\n", \
                    __FILE__, __PRETTY_FUNCTION__, __LINE__, message)

	#define dmsgf(format, params ...) \
                printf("%s - %s (%d): " format "\n", \
                    __FILE__, __PRETTY_FUNCTION__, __LINE__, params)

#else /* DEBUG */

	#define dmsg(message)
	#define dmsgf(format, params ...)

#endif /* DEBUG */

#endif /* __VIRTUAL_FLY_DEBUG__ */
