;; +----------------------------------+
;; |                                  |
;; |    ITEM ROUTINES                 |
;; |                                  |
;; +----------------------------------+

;; +----------------------------------+
;; |    ITEM AT LOCATION              |
;; +----------------------------------+
getItemAt:
                    ldx #$00
                    cpx itemTableSize
                    beq endGetItemAt
                    jsr prepareItemIter
getItemAtLoop       lda ($20), y
                    and #%10000000
                    cmp #%10000000
                    bne getItemNextIter
                    iny
                    lda ($20), y
                    cmp tmpX
                    bne getItemNextIter
                    iny
                    lda ($20), y
                    cmp tmpY
                    bne getItemNextIter
                    txa
                    rts
getItemNextIter     inx
                    cpx itemTableSize
                    beq endGetItemAt
                    ldy #$00
                    jsr inc20Ptr
                    jmp getItemAtLoop
endGetItemAt        lda #$ff
                    rts

prepareItemIter:
                    lda #>itemTable
                    sta $21
                    lda #<itemTable
                    sta $20
                    lda itemTableRowSize
                    sta inc20ModVal
                    ldy #$00
                    rts

;; +----------------------------------+
;; |    PICK UP ITEM                  |
;; +----------------------------------+
attemptPickUp:
                    lda playerX             ; Check for item at player Pos
                    sta tmpX
                    lda playerY
                    sta tmpY
                    jsr getItemAt
                    cmp #$ff
                    beq nothingToPickUp

                    ldy var_itemValue      ; Look up and store item specs as arg-vars
                    lda ($20), y
                    sta argItemVal
                    ldy var_itemModes
                    lda ($20), y
                    sta argItemModes
                    ldy var_itemTypeID
                    lda ($20), y
                    sta argItemType

                    jsr addToInventory      ; Add item to Inventory

                    lda #<text_PICKED_UP    ; Output pick up message
                    sta $20
                    lda #>text_PICKED_UP
                    sta $21
                    jsr addToMessageBuffer
                    jsr addFullItemDesignationToMessageBuffer
                    jsr addMessage

                    jmp dummyMove

nothingToPickUp     lda #<text_NOTHING_TO_PICK_UP
                    sta $20
                    lda #>text_NOTHING_TO_PICK_UP
                    sta $21
                    jsr addToMessageBuffer
                    jsr addMessage
                    rts

goldPickedUp .byte $00, $00

;; +----------------------------------+
;; |    ADD TO INVENTORY              |
;; +----------------------------------+
addToInventory:     ldy #$00
                    sty goldPickedUp
                    lda ($20), y
                    ora #%10000000
                    cmp #%10000000
                    bne addToBackpack

                    lda ($20), y
                    and #%01111111
                    sta ($20), y

                    ldy var_itemValue
                    lda ($20), y
                    sta goldPickedUp
                    clc
                    adc playerGoldBalance
                    sta playerGoldBalance
                    jsr compactItemTable
                    rts

addToBackpack       lda #<backpackTable     ; Set pointer to backpack
                    sta $22
                    lda #>backpackTable
                    sta $23

                    lda backpackSize        ; Forward pointer to end of backpack
                    sta num1
                    lda backpackRowSize
                    sta num2
                    jsr multiply
                    sta inc22ModVal
                    jsr inc22Ptr

                    ldy #$00
                    lda ($20), y
                    sta ($22), y
                    and #%01111111
                    sta ($20), y

                    ldy var_itemTileID
                    lda ($20), y
                    ldy #$01
                    sta ($22), y

                    ldy var_itemTypeID
                    lda ($20), y
                    ldy #$02
                    sta ($22), y

                    ldy var_itemIdentifyToTypeID
                    lda ($20), y
                    ldy #$03
                    sta ($22), y

                    ldy var_itemValue
                    lda ($20), y
                    ldy #$04
                    sta ($22), y

                    inc backpackSize
                    jsr compactItemTable
                    rts

;; +----------------------------------+
;; |    RESOLVE ITEM SUB LINE         |
;; +----------------------------------+
argItemVal   .byte $00
argItemModes .byte $00
argItemType  .byte $00

itemSubLineToPrintSource
                    lda argItemModes
                    and #%00011111      ; Switch off flag bits
                    sta argItemModes

                    cmp #$00            ; Pieces of Gold
                    beq itemAmountToPrintSource

                    cmp #$06            ; SubType/Identifiable/Effect
                    bcc itemSubTypeToPrintSource

                    jmp itemDurabilityToPrintSource

itemAmountToPrintSource:
                    ldx argItemVal
                    jsr byte_to_decimal
                    lda $20
                    sta print_source
                    lda $21
                    sta print_source+1
                    lda #$07
                    sta target_color
                    rts

itemSubTypeToPrintSource:
                    ldx argItemVal
                    lda itemSubType_nameLo, x
                    sta print_source
                    lda itemSubType_nameHi, x
                    sta print_source+1
                    lda itemSubType_color, x
                    sta target_color
                    rts

itemDurabilityToPrintSource:
                    jsr resolveItemDurability
                    lda itemDurability_nameLo, x
                    sta print_source
                    lda itemDurability_nameHi, x
                    sta print_source+1
                    lda itemDurability_color, x
                    sta target_color
                    rts

;; +----------------------------------+
;; |    RESOLVE ITEM DURABILITY       |
;; +----------------------------------+
resolveItemDurability:
                    ldx #$00
                    lda argItemVal
rslvDurLoop         cmp itemDurability_threshold, x
                    bcs rslvDurFound
                    inx
                    cpx #$05
                    bne rslvDurLoop
rslvDurFound        txa
                    rts

;; +----------------------------------+
;; |    FULL ITEM NAME                |
;; +----------------------------------+

addFullItemDesignationToMessageBuffer
                    lda argItemModes
                    and #%00011111      ; Switch off flag bits
                    sta argItemModes

                    cmp #$00            ; Pieces of Gold
                    beq amountOfItemToMessageBuffer

                    cmp #$06            ; SubType/Identifiable/Effect
                    bcc subTypeItemToMessageBuffer
                    jmp durableItemToMessageBuffer

amountOfItemToMessageBuffer:
                    ldx argItemVal
                    jsr byte_to_decimal
                    jsr addToMessageBuffer
                    jmp itemNameToMessageBuffer
subTypeItemToMessageBuffer:
                    ldx argItemVal
                    cpx #$00
                    bne identifiedItemToMessageBuffer
                    jsr subTypeToMessageBuffer
                    jmp itemNameToMessageBuffer
durableItemToMessageBuffer:
                    jsr resolveItemDurability
                    lda itemDurability_nameLo, x
                    sta $20
                    lda itemDurability_nameHi, x
                    sta $21
                    jsr addToMessageBuffer
itemNameToMessageBuffer:
                    lda #$20
                    jsr addCharToMessageBuffer
itemNameToMBNoPad   ldx argItemType
                    lda itemNameLo, x
                    sta $20
                    lda itemNameHi, x
                    sta $21
                    jsr addToMessageBuffer
                    rts
identifiedItemToMessageBuffer
                    jsr itemNameToMBNoPad
                    lda #$20
                    jsr addCharToMessageBuffer
                    lda #<text_OF
                    sta $20
                    lda #>text_OF
                    sta $21
                    jsr addToMessageBuffer
subTypeToMessageBuffer
                    ldx argItemVal
                    lda itemSubType_nameLo, x
                    sta $20
                    lda itemSubType_nameHi, x
                    sta $21
                    jsr addToMessageBuffer
                    rts
