#include <string.h>
#include <stddef.h> // Include for size_t definition

void *memset(void *dest, int c, size_t count)
{
	char *dst8 = (char *)dest;

	while (count--) {
		*dst8++ = c;
	}
	return dest;
}
