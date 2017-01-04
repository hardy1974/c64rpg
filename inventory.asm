;; +----------------------------------+
;; |    INVENTORY UI STATE            |
;; +----------------------------------+
invCrsrArea .byte $00           ; Currently Active Box - $00 = Backpack, $01 = Body, $02 = Floor

invSelArea  .byte $ff           ; Selection In Box - $00 = Backpack, $01 = Body, $02 = Floor, $ff = No selection
invSelPos   .byte $00           ; Position of selected item in box

invBPOffset .byte $00           ; Offset in Backpack
invFLOffset .byte $00           ; Offset in Floor

boxPositions:
invBPPos    .byte $00           ; Position in Backpack box
invBDPos    .byte $00           ; Position in Body
invFLPos    .byte $00           ; Position in Floor

floorTableOriginTable:
.byte $00
.byte $00
.byte $00
.byte $00
.byte $00
.byte $00
.byte $00

floorTableSize .byte $00
floorTable:
.byte $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00

backPackTop = $01
backPackLeft = $15

;; +----------------------------------+
;; |    INITIALIZE INVENTORY MODE     |
;; +----------------------------------+
enterInventory:
                    lda #$00
                    sta invCrsrArea
                    sta invBPPos
                    sta invBPOffset
                    sta invFLOffset
                    sta invFLPos
                    sta invBDPos

                    lda #<inventoryirq    ; Disable game map interrupts
                    sta $0314
                    lda #>inventoryirq
                    sta $0315

                    lda #$00           ; Set screen background color
                    sta $d021
                    jsr clearscreen

                    lda #$82          ; Set cursor sprite pointers
                    sta $07f8
                    lda #$83          ; Set cursor sprite pointers
                    sta $07f9

                    lda #$84          ; Set nav arrow sprite pointers
                    sta $07fa
                    sta $07fc
                    lda #$85
                    sta $07fb
                    sta $07fd

                    lda #$03           ; Set cursor sprites to multicolor
                    sta $d01c

                    lda #$02           ; Set up sprite colors
                    sta $d027
                    sta $d028

                    lda #$0a
                    sta $d025
                    
                    lda #$0b           ; Set nav sprites to dark grey
                    sta $d029
                    sta $d02a
                    sta $d02b
                    sta $d02c

                    jsr populateFloorTable
                    jsr invPositionCrsr
                    
                    lda #$3d           ; Set BP nav sprite positions
                    sta $d004
                    sta $d006

                    lda #$38
                    sta $d005
                    lda #$af
                    sta $d007
                    
                    lda #$c0           ; Set FL nav sprite positions
                    sta $d008
                    sta $d00a
                    
                    lda #$d0
                    sta $d009
                    lda #$e0
                    sta $d00b
                    
                    lda #%00001110     ; Set hi bits for bp nav sprites
                    sta $d010

                    lda #%00111111     ; Enable inventory sprites
                    sta $d015

                    lda #$00
                    sta boxTop
                    sta boxLeft
                    lda #$0f
                    sta boxWidth
                    lda #$13
                    sta boxHeight
                    jsr drawBox

                    lda #$10
                    sta boxLeft
                    lda #$17
                    sta boxWidth
                    jsr drawBox

                    lda #$01
                    sta memcpy_rowSize

                    lda #<text_BACKPACK
                    sta $20
                    lda #>text_BACKPACK
                    sta $21
                    lda #$12
                    sta $22
                    lda #$04
                    sta $23
                    jsr memcpy_readRowsByte

                    lda #$00
                    sta boxLeft
                    lda #$27
                    sta boxWidth
                    lda #$13
                    sta boxTop
                    lda #$06
                    sta boxHeight
                    jsr drawBox

                    lda #<text_FLOOR
                    sta $20
                    lda #>text_FLOOR
                    sta $21
                    lda #$fa
                    sta $22
                    lda #$06
                    sta $23
                    jsr memcpy_readRowsByte

                    lda #$ff                    ; No selection on entry
                    sta invSelArea

                    jsr updateInventoryContents
                    jmp inventoryMainLoop


;; +----------------------------------+
;; |    INVENTORY MAIN LOOP           |
;; +----------------------------------+

key_INVENTORY_ACTION = #$20

inventoryMainLoop:
                    jsr inventoryReadKey

ilcont              lda #$15     ; wait for raster retrace
                    cmp $d012
                    bne ilcont

                    lda screenDirty
                    cmp #$00
                    beq inventoryMainLoop

                    jsr updateInventoryContents
                    lda #$00
                    sta screenDirty

                    jmp inventoryMainLoop

exitInventory:
                    jsr clearscreen
                    lda #<enterstatusirq    ; Interrupt vector
                    sta $0314
                    lda #>enterstatusirq
                    sta $0315
                    jsr enterMapMode
                    jsr initStatusArea
                    inc screenDirty
                    jmp mainloop

invPerformAction:
                    lda invSelArea
                    cmp #$ff
                    beq jmpSelectItem
                    jmp selectedItemAction
jmpSelectItem       jmp selectItem

inventoryReadKey:
                    jsr $ffe4
                    and #$3f

                    cmp key_INVENTORY
                    beq exitInventory

                    cmp key_INVENTORY_ACTION
                    beq invPerformAction

                    ldx invCrsrArea
                    cpx #$00
                    beq invReadBackpackAreaKey

                    cpx #$01
                    beq invReadBodyAreaKey

                    jmp invReadFloorAreaKey

invReadBackpackAreaKey:
                    cmp key_UP
                    beq moveBPCursorUp
                    cmp key_DOWN
                    beq moveBPCursorDown
                    cmp key_LEFT
                    beq moveBPCursorLeft
                    rts
moveBPCursorUp:
                    lda invBPPos
                    cmp #$00
                    beq moveBPUpTop
                    dec invBPPos
                    jmp invPositionCrsr
moveBPUpTop         lda invBPOffset
                    cmp #$00
                    beq moveInvNoAction
                    dec invBPOffset
                    inc screenDirty
                    rts

moveBPCursorDown:
                    ldx invBPPos
                    inx
                    cpx backpackSize
                    bcs invIntoFloorArea
                    cpx #$08
                    bcc incBPCursor
                    lda #$f1
                    cmp $d02a
                    bne invIntoFloorArea
                    inc invBPOffset
                    inc screenDirty
                    rts
incBPCursor         inc invBPPos
                    jmp invPositionCrsr
moveBPCursorLeft:
                    jsr invIntoBodyArea
                    jmp invPositionCrsr
invReadBodyAreaKey:
                    cmp key_UP
                    beq moveBDCursorUp
                    cmp key_DOWN
                    beq moveBDCursorDown
                    cmp key_RIGHT
                    beq moveBDCursorRight
                    rts
moveBDCursorRight:
                    jsr invIntoBackPackArea
                    jmp invPositionCrsr
moveBDCursorUp:
                    rts
moveBDCursorDown:
                    jsr invIntoFloorArea
                    jmp invPositionCrsr
moveInvNoAction     rts

invReadFloorAreaKey:
                    cmp key_UP
                    beq moveFLCursorUp
                    cmp key_DOWN
                    beq moveFLCursorDown
                    rts
moveFLCursorUp:
                    ldx invFLPos
                    cpx #$00
                    beq invIntoBackPackArea
                    dec invFLPos
                    jmp invPositionCrsr

moveFLCursorDown:
                    ldx invFLPos
                    inx
                    cpx floorTableSize
                    bcs moveInvNoAction
                    inc invFLPos
                    jmp invPositionCrsr

invIntoBodyArea:
                    lda #$01
                    sta invCrsrArea
                    rts

invIntoBackPackArea:
                    lda #$00
                    sta invCrsrArea
                    jmp invPositionCrsr

invIntoFloorArea:
                    lda #$02
                    sta invCrsrArea
                    jmp invPositionCrsr

invPositionCrsr:
                    lda invCrsrArea
                    cmp #$00
                    beq invPositionBPCrsr

                    cmp #$01
                    beq invPositionBDCrsr

invPositionFLCrsr:
                    lda invFLPos
                    sta num1
                    lda #$10
                    sta num2
                    jsr multiply
                    clc
                    adc #$cf
                    sta $d001
                    sta $d003

                    lda #$1a
                    sta $d000
                    lda #$b0
                    sta $d002
                    lda #%00001100
                    sta $d010
                    rts
invPositionBDCrsr:
                    lda #$1a
                    sta $d000
                    lda #$80
                    sta $d002
                    lda #%00001100
                    sta $d010
                    rts
invPositionBPCrsr:
                    lda invBPPos
                    sta num1
                    lda #$10
                    sta num2
                    jsr multiply
                    clc
                    adc #$37
                    sta $d001
                    sta $d003

                    lda #$9a
                    sta $d000
                    lda #$30
                    sta $d002
                    lda #%00001110
                    sta $d010
                    rts

;; +----------------------------------+
;; |    INVENTORY ACTIONS             |
;; +----------------------------------+

selectItem:
        lda invCrsrArea
        sta invSelArea
        tax
        lda boxPositions, x
        sta invSelPos
        inc screenDirty
        rts
selectedItemAction:
        lda invCrsrArea                 ; branch to move item if origin and target area differ
        cmp invSelArea
        bne moveSelectedItem

        tax                             ; Trade places if positions differ
        lda boxPositions, x
        cmp invSelPos
        bne rearrangeItem

        lda #$ff                        ; Else, deselect
        sta invSelArea
        sta invSelPos
        inc screenDirty
        rts

moveSelectedItem
        lda invCrsrArea
        cmp #$02
        beq dropItem

        cmp #$00
        beq pickUpItem
        rts

rearrangeItem
        rts

targetPos .byte $00
pickUpItem:
        lda #<itemTable
        sta $20
        lda #>itemTable
        sta $21
        lda itemTableRowSize
        sta inc20ModVal

        ldx invFLPos
        lda floorTableOriginTable, x
        sta targetPos

        ldx #$00
pickUpForwardLoop:
        cpx targetPos
        beq pickUpForwarded
        inx
        jsr inc20Ptr
        jmp pickUpForwardLoop
pickUpForwarded:
        jsr addToInventory
        jsr populateFloorTable
        inc screenDirty
        lda #$ff
        sta invSelArea
        rts

dropItem:
                        lda #$ff
                        sta invSelArea

                        lda #<backpackTable
                        sta $20
                        lda #>backpackTable
                        sta $21
                        lda backpackRowSize
                        sta inc20ModVal

                        lda #<itemTable
                        sta $22
                        lda #>itemTable
                        sta $23
                        lda itemTableRowSize
                        sta inc22ModVal

                        ldy #$00
                        ldx #$00
forwardToItemLoop       cpx invSelPos
                        beq forwardedToItem
                        jsr inc20Ptr
                        inx
                        jmp forwardToItemLoop
forwardedToItem         ldx #$00
forwardToEndOfItems     cpx itemTableSize
                        beq forwardedToEnd
                        jsr inc22Ptr
                        inx
                        jmp forwardToEndOfItems

forwardedToEnd          ldy #$00
                        lda ($20), y
                        sta ($22), y
                        and #%01111111
                        sta ($20), y

                        iny
                        lda playerX
                        sta ($22), y
                        iny
                        lda playerY
                        sta ($22), y

                        ldy #$01
                        lda ($20), y
                        ldy #$03
                        sta ($22), y

                        ldy #$02
                        lda ($20), y
                        ldy #$04
                        sta ($22), y

                        ldy #$03
                        lda ($20), y
                        ldy #$05
                        sta ($22), y

                        ldy #$04
                        lda ($20), y
                        ldy #$06
                        sta ($22), y

                        inc itemTableSize
itemDropped
                        jsr compactBackpack
                        jsr populateFloorTable
                        inc screenDirty
                        rts

updateInventoryContents:
        jsr drawBackPack
        jsr drawFloor
        rts

;; +----------------------------------+
;; |    DRAW BACKPACK CONTENTS        |
;; +----------------------------------+
drawBackPack        lda #$28
                    sta $20
                    sta $24
                    lda #$04
                    sta $21
                    lda #$d8
                    sta $25

                    lda #<backpackTable
                    sta $22
                    lda #>backpackTable
                    sta $23
                    lda backpackRowSize
                    sta inc22ModVal

                    lda invBPOffset
                    sta rollIterations
                    jsr roll22Ptr

                    lda #$08
                    sta itemContSize
                    lda backpackSize
                    sta itemSourceSize
                    lda #$15
                    sta itemContTextOff
                    lda #$12
                    sta itemContTileOff
                    lda #$24
                    sta itemContRight
                    lda #$00
                    sta itemContID

                    lda #$0b
                    ldx invBPOffset
                    cpx #$00
                    beq bpSetScrollUpColor
                    lda #$01
bpSetScrollUpColor  sta $d029

                    lda #$0b
                    ldx backpackSize
                    inx
                    cpx itemContSize
                    bcc bpSetScrollDownColor
                    lda invBPOffset
                    clc
                    adc itemContSize
                    tax
                    lda #$0b
                    cpx itemSourceSize
                    beq bpSetScrollDownColor
                    lda #$01
bpSetScrollDownColor sta $d02a
                    lda $d02a
                    sta $0410
                    jmp drawItemContainer

;; +----------------------------------+
;; |    DRAW FLOOR CONTENTS           |
;; +----------------------------------+
drawFloor           lda #$20
                    sta $20
                    sta $24
                    lda #$07
                    sta $21
                    lda #$db
                    sta $25

                    lda #<floorTable
                    sta $22
                    lda #>floorTable
                    sta $23
                    lda backpackRowSize
                    sta inc22ModVal

                    lda #$02
                    sta itemContSize
                    lda floorTableSize
                    sta itemSourceSize
                    lda #$05
                    sta itemContTextOff
                    lda #$02
                    sta itemContTileOff
                    lda #$14
                    sta itemContRight
                    lda #$02
                    sta itemContID
                    jmp drawItemContainer

;; +----------------------------------+
;; |    DRAW ITEM CONTAINER           |
;; +----------------------------------+

itemContSize        .byte $00
itemSourceSize      .byte $00
itemContTileOff     .byte $00
itemContTextOff     .byte $00
itemContRight       .byte $00
itemContID          .byte $00

drawItemContainer:
                    ldx #$00
                    stx iter
                    jmp drawItemContLoop
itemContFillRemain  cpx itemContSize
                    bcs drawItemContDone
                    ldy itemContTileOff

fillBLoop           lda #$20
                    sta ($20), y
                    tya
                    clc
                    adc #$28
                    tay
                    lda #$20
                    sta ($20), y
                    tya
                    sbc #$27
                    tay
                    iny
                    cpy itemContRight
                    bne fillBLoop
                    jsr incscreenoffset
                    inx
                    jmp itemContFillRemain
drawItemContDone    rts
drawItemContLoop    cpx itemSourceSize
                    beq itemContFillRemain
                    cpx itemContSize
                    beq drawItemContDone

                    ldy #$01
                    lda ($22), y
                    tax                         ; Item Tile Index in X
                    ldy itemContTileOff         ; Horiz position of backpack items
                    jsr drawItemTile

                    lda $20
                    clc
                    adc itemContTextOff
                    sta print_target
                    lda $21
                    sta print_target+1
                    ldy #$02
                    lda ($22), y
                    sta print_source
                    ldy #$03
                    lda ($22), y
                    sta print_source+1
                    ldy #$00
                    lda (print_source), y
                    sta print_source_length
                    inc print_source
                    jsr print_string

                    lda invSelArea              ; Check if area contains selection
                    cmp itemContID
                    bne drawItemNoSelect

                    lda invSelPos               ; Check if current position is selected
                    cmp iter
                    bne drawItemNoSelect

                    lda #$03
                    sta target_color
                    jmp addItemNameColor

drawItemNoSelect    lda #$01
                    sta target_color
addItemNameColor    lda $24
                    clc
                    adc itemContTextOff
                    sta print_target
                    lda $25
                    sta print_target+1
                    jsr apply_text_color

                    jsr incscreenoffset

                    jsr inc22Ptr
                    inc iter
                    ldx iter
                    jmp drawItemContLoop

drawItemTile:
                    lda tileChar1, x        ; Draw upper row of tile chars to screen
                    sta ($20), y
                    lda tileCharColor1, x
                    sta ($24), y

                    iny
                    lda tileChar2, x
                    sta ($20), y
                    lda tileCharColor2, x
                    sta ($24), y

                    tya                     ; Forward to lower row
                    adc #$27
                    tay

                    lda tileChar3, x        ; Draw lower row of tile chars to screen
                    sta ($20), y
                    lda tileCharColor3, x
                    sta ($24), y

                    iny
                    lda tileChar4, x
                    sta ($20), y
                    lda tileCharColor4, x
                    sta ($24), y

                    rts

;; +----------------------------------+
;; |    CURRENT POS INTERACTION       |
;; +----------------------------------+

populateFloorTable:
                    lda #$00
                    sta floorTableSize

                    lda #<itemTable
                    sta $20
                    lda #>itemTable
                    sta $21
                    lda itemTableRowSize
                    sta inc20ModVal

                    lda #<floorTable
                    sta $22
                    lda #>floorTable
                    sta $23
                    lda backpackRowSize
                    sta inc22ModVal

                    ldx #$00
floorTableLoop      cpx itemTableSize
                    beq endPopulateFloorTable

                    ldy var_itemXPos
                    lda ($20), y
                    cmp playerX
                    bne floorTableNextIter
                    ldy var_itemYPos
                    lda ($20), y
                    cmp playerY
                    bne floorTableNextIter

                    ldy #$00
                    lda ($20), y
                    sta ($22), y

                    ldy #$03
                    lda ($20), y
                    ldy #$01
                    sta ($22), y

                    ldy #$04
                    lda ($20), y
                    ldy #$02
                    sta ($22), y

                    ldy #$05
                    lda ($20), y
                    ldy #$03
                    sta ($22), y

                    ldy #$05
                    lda ($20), y
                    ldy #$03
                    sta ($22), y

                    txa
                    ldy floorTableSize
                    sta floorTableOriginTable, y

                    inc floorTableSize
                    jsr inc22Ptr

floorTableNextIter  jsr inc20Ptr
                    inx
                    jmp floorTableLoop

endPopulateFloorTable:
                    rts

;; +----------------------------------+
;; |    BACKPACK TABLE OPS            |
;; +----------------------------------+
tmpPos .byte $00
iterMax .byte $00

compactItemTable:
                    lda #<itemTable
                    sta $20
                    sta $22
                    lda #>itemTable
                    sta $21
                    sta $23

                    lda itemTableRowSize
                    sta inc20ModVal
                    sta inc22ModVal
                    sta memcpy_rowSize

                    lda #$01
                    sta memcpy_rows

                    lda itemTableSize
                    sta iterMax

                    ldx #$00
                    stx iter
compactITLoop       ldx iter
                    cpx iterMax
                    bcs endCompactIT

                    ldy #$00
                    lda ($20), y

                    and #%10000000
                    cmp #%10000000
                    beq compactITEntry
                    jsr inc20Ptr
                    dec itemTableSize
                    dec iterMax
compactITEntry
                    jsr memcpy              ; memcpy forwards both 20 and 22 pointers one step

                    inc iter
                    jmp compactITLoop

endCompactIT
                    rts

compactBackpack:
                    lda #<backpackTable         ; Set 20 and 22 pointers to backpack
                    sta $20
                    sta $22
                    lda #>backpackTable
                    sta $21
                    sta $23

                    lda backpackRowSize         ; Increment and copy full backpackTable row at a time
                    sta inc20ModVal
                    sta inc22ModVal
                    sta memcpy_rowSize

                    lda #$01                    ; Copy one row at a time
                    sta memcpy_rows

                    lda backpackSize
                    sta iterMax

                    ldx #$00
                    stx iter
compactBPLoop       ldx iter
                    cpx iterMax
                    bcs endCompactBP

                    ldy #$00
                    lda ($20), y

                    and #%10000000
                    cmp #%10000000
                    beq compactBPEntry
                    jsr inc20Ptr
                    dec backpackSize
                    dec iterMax
compactBPEntry
                    jsr memcpy              ; memcpy forwards both 20 and 22 pointers one step

                    inc iter
                    jmp compactBPLoop

endCompactBP
                    rts