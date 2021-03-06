#################################################################
#								#
# Copyright (c) 2018 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
# Copyright (c) 2018 Stephen L Johnson. All rights reserved.	#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

/* opp_svput.s */

/*
 * void op_svput(int varnum, mval *v)
 */

	.include "linkage.si"
	.include "g_msf.si"
#	include "debug.si"

	.data
	.extern	frame_pointer

	.text
	.extern	op_svput

ENTRY opp_svput
	mov	x29, sp					/* Save sp against potential adjustment */
	putframe
	CHKSTKALIGN					/* Verify stack alignment */
	bl	op_svput
	getframe
	mov	sp, x29					/* Restore sp */
	ret
