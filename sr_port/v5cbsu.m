	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;								;
	;	Copyright 2005 Fidelity Information Services, Inc	;
	;								;
	;	This source code contains the intellectual property	;
	;	of its copyright holder(s), and is made available	;
	;	under a license.  If you do not know the terms of	;
	;	the license, please stop and do not read further.	;
	;								;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;
	; V5 Block Split Utility.
	;
	; Reads scan phase output file from DBCERTIFY and processes level-0 GVT blocks.
	; Rewrites the scan phase output file minus those blocks.
	;
	; Note that our input and output files contain binary data in the file and
	; record headers. GT.M I/O does not deal with this type of data well so these binary
	; stream files are treated as fixed record length files so far as GT.M is concerned
	; and we do our own buffering of the read and write IOs. This is basically the same
	; approach that GDE uses.
	;
v5cbsu
	Set p1outfile=$ZCMDLINE
	If p1outfile="" Use $P Write "Must specify the name of the SCAN phase output file",! Halt
	D init
	Do doopen(.p1outfile,readflg)
	D readp1hd
	If p1tag'=p1tagread Use $P Write "%GTM-E-DBCBADFILE, Source file ",p1outfile," does not appear to have been generated by DBCERTIFY SCAN - rerun SCAN or specify correct file",! Quit
	If (0=gvtleafc) Use $P Write "There are no GVT leaf (level 0) blocks to process in this database",! Quit
	If version>"V4.4-004" View "GVDUPSETNOOP":0
	Set dbfname=$View("GVFILE",regnameP)
	If dbfnP'=dbfname Use $P Write "Database for region ",regnameP,"(",dbfname,") does not match the recorded name from the scan phase (",dbfnP,")",! Quit
	;
	; Process the input file. Any records we do not handle are rewritten to tmpfile1.
	;
	Do doopen(.tmpfile1,writeflg)
	Set outrecs=0,byprecs=0,prorecs=0,releaf=0
	For rec=1:1:blkcnt Do
	. If $TLevel Use $P Zshow "*" Write "V5CBSU - GTMASSERT: $TLEVEL non zero at top of processing loop",! Halt
	. Do readp1rc
	. If ""=reckey Do  Quit	; If reckey="", then not a record we can process
	. . Do dowrite(.tmpfile1,p1rec)
	. . Set outrecs=outrecs+1
	. . If gvtleaf=blktype Set releaf=releaf+1	; This is a leaf block we cannot process (no key)
	. . Quit
	. TStart ()
	. Set exist=$DATA(@reckey)
	. If (1=exist)!(11=exist) Set value=$Get(@reckey) Set @reckey=value TCommit  Set prorecs=prorecs+1
	. Else  TRollback  Set byprecs=byprecs+1
	;
	; Close input and output files. Open new output file that will include the fileheader with the correct record count
	;
	Do doclose(.p1outfile)
	Do doclose(.tmpfile1)
	Set newp1hdr=p1tag_$$num2bin(hdrtn)_$$num2bin(outrecs)_$$num2bin(totblks)_$$num2bin(dtleafc)_$$num2bin(dtindxc)
	Set newp1hdr=newp1hdr_$$num2bin(releaf)_$$num2bin(gvtindxc)_regname_$Char(0)_dbfn_$Char(0)_$$num2bin(uidlen)_uniqueid
	Set $Piece(hdrpad,$C(0),33-$Length(uniqueid)+filBufSz-360)=""	; Create padding of zeroes of correct length to fill fixed size hdr
	Set newp1hdr=newp1hdr_hdrpad
	If $Length(newp1hdr)'=p1hdrlen Use $P Zshow "*" Write "V5CBSU - GTMASSERT: New fileheader not expected size. Size is ",$Length(newp1hdr)," - Expecting ",p1hdrlen,! Halt
	Do doopen(.tmpfile1,readflg)
	Do doopen(.tmpfile2,writeflg)
	Do dowrite(.tmpfile2,newp1hdr)
	For recs=1:1:outrecs Do
	. Set tmprec=$$doread(.tmpfile1,p1reclen)
	. Do dowrite(.tmpfile2,tmprec)
	;
	; New version of dbcertp1 file is written to tmpfile2. Close both files and effect the proper name change.
	;
	Do doclose(.tmpfile1)
	Do doclose(.tmpfile2)
	If VMS Set rename="RENAME" Set delete="DELETE" Set delver=".*"
	Else  Set rename="mv" Set delete="rm" Set delver=""
	ZSystem delete_" "_p1outfile_delver
	ZSystem rename_" "_tmpfile2_" "_p1outfile
	ZSystem delete_" "_tmpfile1_delver

	Use $P
	Write "Scan phase records read:      ",blkcnt,!
	Write "Scan phase records bypassed:  ",byprecs,!
	Write "Scan phase records processed: ",prorecs,!
	Write "Scan phase records left:      ",outrecs,!
	Quit

	;
	; Read in scan phase file header
	;
readp1hd
	Set p1hdr=$$doread(.p1outfile,p1hdrlen)
	Set p1tagread=$Extract(p1hdr,1,8)
	Set hdrtn=$$bin2num($Extract(p1hdr,9,12))
	Set blkcnt=$$bin2num($Extract(p1hdr,13,16))
	Set totblks=$$bin2num($Extract(p1hdr,17,20))
	Set dtleafc=$$bin2num($Extract(p1hdr,21,24))
	Set dtindxc=$$bin2num($Extract(p1hdr,25,28))
	Set gvtleafc=$$bin2num($Extract(p1hdr,29,32))
	Set gvtindxc=$$bin2num($Extract(p1hdr,33,36))
	Set regname=$Extract(p1hdr,37,67)
	; 1 byte of filler we don't care about
	Set dbfn=$Extract(p1hdr,69,323)
	; 1 byte of filler we don't care about
	Set uidlen=$$bin2num($Extract(p1hdr,325,328))
	; Size of field  varys (by platform) length unique id fields (we don't process them)
	Set uniqueid=$Extract(p1hdr,329,329+uidlen-1)
	; Eliminate trailing nulls
	Set regnameP=$Piece(regname,$Char(0),1)
	Set dbfnP=$Piece(dbfn,$Char(0),1)
	; Now that we have a region name, define our temps with regname embedded
	Set tmpfile1="dbcertp1"_regnameP_".tmp1"
	Set tmpfile2="dbcertp1"_regnameP_".tmp2"
	Quit

	;
	; Read in scan phase record (fixed size with optional varying length ascii key following)
	;
readp1rc
	Set p1rec=$$doread(.p1outfile,p1reclen)
	Set tn=$$bin2num($Extract(p1rec,1,4))
	Set blknum=$$bin2num($Extract(p1rec,5,8))
	Set blktype=$$bin2num($Extract(p1rec,9,12))
	Set blklevl=$$bin2num($Extract(p1rec,13,16))
	Set akeylen=$$bin2num($Extract(p1rec,17,20))
	If (blktype=gvtleaf)&(0'=akeylen) Set reckey=$$doread(.p1outfile,akeylen)
	Else  Set reckey="" If (0'=akeylen) Use $P ZShow "*" Write "V5CBSU - GTMASSERT: Error with non-zero akeylen for non-gvtleaf record",! Halt
	Quit

	;
	; Open given file (1st arg MUST be passed by refence) in read or write mode according to flag. Record flag
	; in file(1) so close knows whether to flush buffer or not. Buffer for this file is kept in file(2)
	;
doopen(file,readflag)
	Set file(1)=readflag
	If readflag Open file:@("(Readonly:Fixed:RecordSize="_filBufSz_":Blocksize="_filBufSz_")")
	Else        Open file:@("(New:Fixed:RecordSize="_filBufSz_":Blocksize="_filBufSz_")")
	Set file(2)=""	; Buffer for this file
	Quit

	;
	; Read given length from given file. Buffer is kept in file(2). We are rebuffering filBufSz byte fixed records
	; at the real IO level for the reasons described in the module header.
	;
doread(file,len)
	New rec,br
	; A record with ZWR format key can be very long indeed so read more than enough blocks to cover that
	; possibility. The max is higher than needs to be but satisfies criteria of not leaving the loop unbounded.
	For br=1:1:mxzwrxpr Quit:$Length(file(2))'<len  Do
	. Use file
	. Read rec#filBufSz
	. Set file(2)=file(2)_rec
	If br'<10 Use $P Zshow "*" Write !!,"V5CBSU - GTMASSERT: Read length exceeds buffer length",! Halt
	Set rec=$Extract(file(2),1,len)
	Set file(2)=$Extract(file(2),len+1,mxrecsln)
	Quit rec

	;
	; Write data to given file. If length of buffer (in file(2)) does not exceed filBufSz bytes
	; after the write, no real write is made.
	;
dowrite(file,data)
	New rec
	Set file(2)=file(2)_data
	If ($Length(file(2))<filBufSz) Quit ; Return
	; Write filBufSz byte chunk of data
	Use file
	Set rec=$Extract(file(2),1,filBufSz)
	Write rec
	Set file(2)=$Extract(file(2),513,mxrecsln)
	Quit

	;
	; Close given file and flush its output buffer if necessary
	;
doclose(file)
	If writeflg=file(1) Do
	. ; File was opened for write so flush buffer before we close file
	. Use file
	. Write file(2)
	Close file
	Quit

	;
	; Initialize arrays and such we will be using
	;
init
	Set FALSE=0
	Set TRUE=1
	Set readflg=1
	Set writeflg=0
	Set endian("AXP")=FALSE
	Set endian("x86")=FALSE
	Set endian("HP-PA")=TRUE
	Set endian("SPARC")=TRUE
	Set endian("RS6000")=TRUE
	Set endian("S390")=TRUE
	Set endian=endian($Piece($ZVersion," ",4))
	Set HEX(0)=1
	For x=1:1:8 Set HEX(x)=HEX(x-1)*16
	Set VMS=$ZVersion["VMS"
	Set gvtleaf=5		; gdsblk_gvtleaf - defined in dbcertify.h
	Set version=$Piece($ZVersion," ",2)
	Set p1hdrlen=512	; p1hdr struct defined in dbcertify.h
	Set p1reclen=20		; p1rec struct defined in dbcertify.h
	Set p1tag="GTMDBC01"	; P1HDR_TAG define in dbcertify.h
	Set filBufSz=p1hdrlen	; Real IO is done at this buffer size. Should coicide with size of header
	Set mxzwrxpr=10		; MAX_ZWR_EXP_RATIO - key can (in actuality) be much larger when using $C() notation
	Set mxrecsln=filBufSz*mxzwrxpr ; Rather than use 99999 for max rec len, use blocksize * MAX_ZWR_EXP_RATIO
	Quit

	;
	; Conversion routine - binary number from file to GT.M usable number
	;
bin2num:(bin)
	New num,i
	Set num=0
	If endian=TRUE For i=$l(bin):-1:1 Set num=$Ascii(bin,i)*HEX($Length(bin)-i*2)+num
	Else  For i=1:1:$l(bin) Set num=$Ascii(bin,i)*HEX(i-1*2)+num
	Quit num

	;
	; Conversion routine - GT.M number to binary (4 byte) number for file
	;
num2bin:(num)
	If endian=TRUE Quit $Char(num/16777216,num/65536#256,num/256#256,num#256)
	Quit $Char(num#256,num/256#256,num/65536#256,num/16777216)