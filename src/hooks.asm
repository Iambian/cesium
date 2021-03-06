hook_token_stop := $d9 - $ce
hook_parser:
	db	$83			; hook signifier
	cp	a,2
	jr	z,.maybe_stop
	xor	a,a
	ret
.maybe_stop:
	ld	a,hook_token_stop	; check if stop token
	cp	a,b
	ld	a,$ab
	jp	z,_JError
	xor	a,a
	ret

hook_app_change:
	db	$83
	;ld	c,a			; huh
	ld	a,b
	cp	a,cxPrgmEdit		; only allow when editing
	ld	b,a
	ret	nz
	ld	a,c
	cp	a,kEnter		; wut ti, this is how you run a program?
	jr	nz,.wut
	push	hl
	call	_PopOP1
	pop	hl
	ret
.wut:
	call	_CursorOff
	call	_CloseEditEqu
	call	_PopOP1
	call	_ChkFindSym
	jr	c,.dont_archive
	ld	a,(edit_status)
	or	a,a
	call	nz,_Arc_Unarc
.dont_archive:
	ld	a,return_prgm
	ld	(return_info),a
	jp	cesium_start

hook_get_key:
	db	$83
	cp	a,$1b
	ret	nz
	ld	a,b
	push	af
	push	hl
	ld	hl,$f0202c
	ld	(hl),l
	ld	l,h
	bit	0,(hl)
	pop	hl
	jr	nz,.check_for_shortcut_key
	pop	af
	cp	a,sk2nd
	ret	nz
	ld	a,sk2nd - 1				; maybe some other day
	inc	a
	ret
.check_for_shortcut_key:
	pop	af
	cp	a,skStat
	jp	z,hook_password
	cp	a,skGraph
	jr	z,hook_show_labels
	cp	a,skPrgm
	jr	z,hook_execute_cesium
	cp	a,sk8
	jr	z,hook_backup_ram
	cp	a,sk5
	jr	z,hook_clear_backup
	cp	a,sk2
	jr	z,hook_restore_ram
	ret

hook_show_labels:
	jr	hook_get_key_none

hook_clear_backup:
	call	flash_code_copy
	call	flash_clear_backup
	jr	hook_get_key_none

hook_restore_ram:
	push	hl
	push	af
	ld	hl,$3c0001
	ld	a,$a5
	cp	a,(hl)
	jr	nz,.none
	dec	hl
	ld	a,$5a
	cp	a,(hl)
	jp	z,0
.none:
	pop	af
	pop	hl
	inc	a
	dec	a
	ret

hook_get_key_none:
	xor	a,a
	inc	a
	dec	a
	ret

hook_backup_ram:
	call	_os_ClearStatusBarLow
	di
	ld	de,$e71c
	ld.sis	(drawFGColor and $ffff),de
	ld.sis	de,(statusBarBGColor and $ffff)
	ld.sis	(drawBGColor and $ffff),de
	ld	a,14
	ld	(penRow),a
	ld	de,2
	ld.sis	(penCol and $ffff), de
	ld	hl,string_ram_backup
	call	_VPutS
	call	flash_code_copy
	call	flash_backup_ram
	call	_DrawStatusBar
	jr	hook_get_key_none

hook_execute_cesium:
	xor	a,a
	ld	(menuCurrent),a
	call	_CursorOff
	call	_RunIndicOff
	di
	ld	hl,data_string_cesium_name	; execute app
	ld	de,$d0082e			; honestly no idea what this address is...
	push	de
	ld	bc,8
	push	bc
	ldir
	pop	bc
	pop	hl
	ld	de,progtoedit			; copy it here just to be safe
	ldir
	ld	a,cxExtApps
	jp	_NewContext

hook_password:
	ld	hl,data_cesium_appvar
	call	_Mov9ToOP1
	call	_ChkFindSym
	call	_ChkInRam
	push	af
	call	z,_Arc_Unarc			; archive it
	pop	af
	jr	z,hook_password			; find the settings appvar
	ex	de,hl
	ld	de,9
	add	hl,de
	ld	e,(hl)
	add	hl,de
	inc	hl
	inc	hl
	inc	hl
	ld	de,settings_data
	ld	bc,settings_size
	ldir					; copy in the password
.wrong:
	call	_CursorOff
	ld	a,cxCmd
	call	_NewContext0
	call	_CursorOff
	call	_ClrSCrn
	call	_HomeUp
	ld	hl,data_string_password
	call	_PutS
	di
	call	_EnableAPD
	ld	a,1
	ld	hl,apdSubTimer
	ld	(hl),a
	inc	hl
	ld	(hl),a
	set	apdRunning,(iy + apdFlags)
	ei
	ld	hl,setting_password
	ld	a,(hl)				; password length
	or	a,a
	jr	z,.correct
	ld	b,a
	ld	c,0
	inc	hl
.get_user_password:
	call	.get_key
	cp	a,(hl)
	inc	hl
	jr	z,.draw_character
	inc	c
.draw_character:
	ld	a,'*'
	call	_PutC
	djnz	.get_user_password
	dec	c
	inc	c
	jr 	nz,.wrong
.correct:
	ld	a,kClear
	jp	_SendKPress
.get_key:
	push	hl
   	call	_GetCSC
	pop	hl
	or	a,a
	jr	z,.get_key
	ret

hook_home:
	db	$83
	cp	a,3
	ret	nz
	bit	appInpPrmptDone,(iy + apiFlg2)
	res	appInpPrmptDone,(iy + apiFlg2)
	ld	a,b
	ld	b,0
	jr	z,.restore_home_hooks
.establish:
	call	_ReloadAppEntryVecs
	ld	hl,.vectors
	call	_AppInit
	or	a,1
	ld	a,cxExtApps
	ld	(cxCurApp),a
	ret
.set:
	ld	hl,hook_home
	call	_SetHomescreenHook
	jr	.establish
.restore_home_hooks:
	push	af
	push	bc
	call	_ClrHomescreenHook
	res	appWantHome,(iy + sysHookFlg)
	pop	bc
	pop	af
	cp	a,cxError
	jp	z,return_basic
	cp	a,cxPrgmInput
	jp	z,return_basic
	ld	hl,backup_home_hook_location
	ld	a,(hl)
	or	a,a
	ret	z
	push	bc
	ld	hl,(hl)
	call	_SetHomescreenHook
	set	appWantHome,(iy + sysHookFlg)
	pop	bc
	ret
.save:
	xor	a,a
	sbc	hl,hl
	bit	appWantHome,(iy + sysHookFlg)
	jr	z,.done
	ld	hl,(homescreenHookPtr)
.done:
	ld	(backup_home_hook_location),hl
	ret

.put_away:
	xor    a,a
	ld     (currLastEntry),a
	bit    appInpPrmptInit,(iy + apiFlg2)
	jr     nz,.skip
	call	_ClrHomescreenHook
.skip:
	call	_ReloadAppEntryVecs
	call	_PutAway
	ld	b,0
	ret
.vectors:
	dl	$f8
	dl	_SaveShadow
	dl	.put_away
	dl	_RstrShadow
	dl	$f8
	dl	$f8
	db	0
