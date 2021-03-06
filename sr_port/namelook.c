/****************************************************************
 *								*
 * Copyright 2001, 2007 Fidelity Information Services, Inc	*
 *								*
 * Copyright (c) 2020 YottaDB LLC and/or its subsidiaries.	*
 * All rights reserved.						*
 *								*
 *	This source code contains the intellectual property	*
 *	of its copyright holder(s), and is made available	*
 *	under a license.  If you do not know the terms of	*
 *	the license, please stop and do not read further.	*
 *								*
 ****************************************************************/

#include "mdef.h"

#include "gtm_string.h"

#include "compiler.h"
#include "opcode.h"
#include "toktyp.h"
#include "nametabtyp.h"
#include "gtm_caseconv.h"
#include "namelook.h"

int namelook(const unsigned char offset_tab[], const nametabent *name_tab, char *str, int strlength)
{
	unsigned char		temp[NAME_ENTRY_SZ], x;
	const nametabent	*top, *i;

	if ((NAME_ENTRY_SZ < strlength) || (0 >= strlength))
		return -1;
	lower_to_upper(&temp[0], (uchar_ptr_t)str, strlength);
	if ((x = temp[0]) == '%')
		return -1;
	if (('A' > x) || ('Z' < x)) /* This enforces the boundaries of the offset_tab which is always used
	 			 * for indexes from A to Z.
				 */
		return -1;
	i = name_tab + offset_tab[x -= 'A'];
	top = name_tab + offset_tab[++x];
	assert(i == top || i->name[0] >= temp[0]);
	for (; i < top; i++)
	{
		if ((strlength == i->len) || ((strlength > i->len) && (i->name[i->len] == '*')))
		{
			if (!memcmp(&temp[0], i->name, (int4)(i->len)))
				return (int)(i - name_tab);
		}
	}
	return -1;
}
