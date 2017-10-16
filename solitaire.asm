section .data
deck:   
    db  16, 24, 51, 43, 38, 12, 17, 14, 40, 7, 22, 35, 8,
    db  48, 15, 49, 9, 36, 23, 5, 25, 32, 47, 45, 0, 19,
    db  11, 4, 39, 28, 42, 31, 2, 29, 6, 34, 33, 46, 51,
    db  20, 37, 30, 27, 13, 41, 44, 26, 21, 3, 50, 10, 18
deck_pointer:   db 51
piles:
    times 352 db 0xFF
card_repr:
    db  0x1B, 0x5B, 0x33, 0x32, 0x6D, 0x20, 0x20, 0x20, 0x85, 0x20, 0x20
;    db  0x1B, 0x5B, 0x33, 0x32, 0x6D, 0x78, 0xD1, 0x85, 0xD1, 0x85
;    db  0x20, 0x20
card_len: equ 12
end_line:
    db  0x1B, 0x5B, 0x30, 0x6D, 0x0a
column:    db 0x1B, 0x5B, 0x33, 0x37, 0x6D, " ", " ", " ", " ", " "
ranks:     db "A23456789TJQK"
suits:      db "cdsh"
tableaux_pointers: db 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6
random_file: db "/dev/urandom"
section .text
global _start
_start:
    call shuffle

; First we set up all the piles.
; To do this we take the shuffled deck and pop each card from the bottom
; It does this one pile at a time.  so draws one card for pile one, next two
; for pile two, etc.
; We are going to use the move_to_pile subroutine to do this.
; move_to_pile takes AL as the source (0xFF means from the deck)
; and BL is which pile to move to.
setup_piles:
    mov al, 0xFF    ; 0xFF represents waste, the source
    mov bl, 0xFF    ; after first inc will be 0.  which pile index
    mov [free_place], byte 0x1

; Iterates through each pile.  Stops after it's finished 7 piles.
; BL is the counter.
.loop:
    mov cl, 0x00    ; which card in this pile.  Counter
    cmp bl, 0x6     ; If we move onto the eighth pile, quit 
    je .end
    inc bl          ; moves up to next pile (or moves to 0 if starting)
; .loop falls down into this, and keeps drawing cards until number of cards
; in the pile is equivalent to which pile it is.  Then it goes back to .loop
.subloop:
    call move_to_pile
    inc cl          ; iterate which_card counter
    cmp cl, bl      ; if equal to which_pile counter break loop
    jg .loop
    jmp .subloop    ; continue loop
    
; After the piles are all set up, prepare graphical stuff
.end:
    call prepare_output
    call draw_all
    call WRITE
    jmp EXIT


prepare_output:
    mov rdi, output
    mov bl, 0
.main_loop:             ; This creates all of the 32 lines
    cmp bl, 32          
    je .end_main
    call .make_line     ; make a single line
    inc bl
    jmp .main_loop

.make_line:             ; creates 7 columns, then creates an eol
    mov cl, 0
.make_line_loop:
    cmp cl, 7
    je .end_make_line
    call .make_col
    inc cl
    jmp .make_line_loop
.end_make_line:
    call .make_eol
    ret


.make_col:
    mov ch, 0
    mov rsi, column
.make_col_loop:
    cmp ch, byte 10
    je .end_make_col
    lodsb
    stosb
    inc ch
    jmp .make_col_loop
.end_make_col:
    ret

.make_eol:
    mov dl, byte 0
    mov rsi, end_line
.make_eol_loop:
    cmp dl, 0x05
    je .end_make_eol
    lodsb
    stosb
    inc dl
    jmp .make_eol_loop
.end_make_eol:
    ret

.end_main:
;    mov eax, 1
;    int 0x80
    ret


shuffle:
    push rax
    push rbx
    push rcx
    push rdx
    xor rax, rax
    xor rcx, rcx
    mov rax, shuffled_cards
    mov cl, 0
.loop:
    cmp cl, 52
    je .end_loop
    mov [rax], byte 0xFF
    inc rax
    inc cl
    jmp .loop
.end_loop:
    xor rax, rax
    xor rcx, rcx
.grab_random_page:
    call .read_from_random
    ; now rsi = start of random page

    xor rax, rax
    xor rbx, rbx
    xor rdx, rdx
.write_to_deck:
    cmp cl, 52
    jge .end_write_to_deck
    cmp dl, 0xFF
    jae .grab_random_page
    xor rax, rax
    lodsb           ; al = random byte
    inc dl
    mov bl, 52  
    div bl          ; now al = quotient, ah = remainder
    mov bl, ah      ; bl = remainder
    mov rax, shuffled_cards
    add rax, rbx    ; rax = random offset into shuffled_cards
    cmp byte [rax], 0xFF   ; if offset value is 0xFF, continue
    jne .skip
    mov byte [rax], cl  ; move value of card into that position
    inc cl              ; increment value of card
    jmp .write_to_deck



.skip:
    jmp .write_to_deck
.end_write_to_deck:
    pop rdx
    pop rcx
    pop rbx
    pop rax


    ret
.read_from_random:
    push rax
    push rbx
    push rcx
    push rdx
    mov rax, 5
    mov rbx, random_file 
    mov rcx, 0
    mov rdx, 666q
    int 0x80

    mov rbx, rax
    mov rax, 3
    mov rcx, random_buffer
    mov rdx, 256
    int 0x80
    mov rsi, random_buffer
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

WRITE_STATUS:
    push rax
    push rbx
    push rcx
    push rdx
;    mov rdi, output_line
    lodsb
    mov eax, 4
    mov ebx, 1
;    mov ecx, output_line
    mov edx, 1000
    int 0x80

    pop rdx
    pop rcx
    pop rbx
    pop rax
WRITE:
    mov eax, 4
    mov ebx, 1
    mov ecx, output
    mov edx, 2784
    int 0x80

EXIT:
    mov eax, 1
    int 0x80
    
draw_board:
    ; draws the "game board"
    mov cl, 0x0
.main_loop:
    cmp cl, 0x7
    je .end_main
    call .draw_pile


    inc cl
    jmp .main_loop
.end_main:
    ret

.draw_pile:
    push rcx
    mov bl, cl  
    call find_end_of_pile
    mov [len_pile], al
    mov bh, 0x0
.draw_pile_loop:
    cmp bh, dl
    je .end_draw_pile
    ; Draw card here
    ; args: 
    ;   bl: which pile
    ;   bh: which card in pile
    
    inc bh
    jmp .draw_pile_loop
.end_draw_pile:
    pop rcx
    ret
draw_all:
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    xor rdx, rdx
    mov bh, 0
    mov bl, 0

.piles_loop:
    cmp bl, 0x7
    jge .end_piles
    mov cl, bl
    mov rax, tableaux_pointers
    add rax, rcx
    mov dl, byte [rax]
    call .subpiles_loop
    mov bh, 0
    inc bl
    jmp .piles_loop
.subpiles_loop:
    cmp bh, dl
    jg .end_subpiles
    call draw_card
    inc bh
    jmp .subpiles_loop
.end_subpiles:
    ret
    
.end_piles:
    ret

draw_card:
    ; args:
    ;   bl: which pile
    ;   bh: which card in pile
    push rax
    push rbx
    push rcx
    push rdx
    xor rax, rax
    xor rcx, rcx
    xor rdx, rdx
    ; Save the two arguments into memory
    mov [current_deck], bl
    mov [current_position], bh

;    mov [current_deck], byte 1
;    mov [current_position], byte 2


    ;---------
    ; This entire section just defines current_card,
    ; And then its rank and suit
    call find_address_of_pile
    ; rax = location in mem of this pile

    mov cl, bh
    add rax, rcx            
    ; rax = where this card is in memory

    xor rbx, rbx
    xor rcx, rcx

    ; define current_card
    mov cl, byte [rax]          ; cl = value of card
    mov [current_card], cl      ; current_card = value of card
    xor rcx, rcx                ; rcx = 0

    call get_suit_and_rank          ; al = rank, bl = suit
    mov [current_suit], al
    mov [current_rank], bl
    mov rax, rax
    xor rbx, rbx
    mov rcx, rax                ; rcx = rank
    mov rdi, card_graphic       ; rdi points to card graphic area
                                ; to start writing to it
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    ;------------
    ; This section actually writes the "graphics" of the card to memory
    ; First, the rank (A-K)
    mov rax, ranks              ; rax = where rank labels are in mem
    mov cl, [current_rank]
    add rax, rcx                ; rax = where this rank label is in mem
    mov bl, byte [rax]
    mov rax, rbx                ; rax = ascii value of this rank label
    stosb                       ; stores rax into [rdi]
    xor rax, rax

    ; Then a space 
    mov al, "-"
    stosb                   

    ; Then the suit.
    mov rax, suits
    mov bl, [current_suit]
    call .get_color
    add rax, rbx
    xor rbx, rbx
    mov bl, byte [rax]
    mov rax, rbx
    stosb

    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx

.move_to_output:
    call visual_location
    mov rsi, card_graphic
    mov rdi, rax
    add rdi, 5
;    add rdi, 12
;    times 8 dec rdi
    mov cl, 3
.move_loop:
    cmp cl, 0
    je .end_move
    movsb
    dec cl
    jmp .move_loop
.end_move:
    dec rdi
    dec rdi
    dec rdi
    dec rdi
    dec rdi
    xor rax, rax
    mov al, [current_color]
    stosb 
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

.get_color:
    cmp bl, 0
    je .is_black
    cmp bl, 1
    je .is_red
    cmp bl, 2
    je .is_black
    cmp bl, 3
    je .is_red
.is_black:
    mov byte [current_color], 0x34
    jmp .end_color
.is_red:
    mov byte [current_color], 0x31
.end_color:
    ret
visual_location:
    push rbx
    push rcx
    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    mov al, [current_position]
    add al, 2
    mov ah, 75
    mul ah
    mov bx, ax
    ; bx = which row to write to
    xor rax, rax
    mov al, [current_deck]
    mov ah, 10
    mul ah
    add ax, bx
    add rax, output

    pop rcx
    pop rbx
    ret
find_address_of_pile:
    mov al, bl
    mov ah, 32
    mul ah
    add rax, piles
    ret

find_end_of_pile:
    push rcx
    ; Converts pile number to length of pile
    ; arguments: bl (pile index)
    ; returns: rax (length of pile)
    call find_address_of_pile
    xor rcx, rcx
.loop:
    cmp byte [rax], 0xFF
    je .exit
    inc rax
    inc cl
    jmp .loop
.exit:
    mov rax, rcx
    pop rcx
    ret
get_suit_and_rank:
    ; No input: looks at mem value current_card
    ; Returns: rank in al, suit in bl
    push rcx
    xor rax, rax
    xor rbx, rbx
    mov al, [current_card]
    mov cl, 13
    div cl
    mov bl, ah
    xor ah, ah
    xor bh, bh
    pop rcx
    ret
    
resolve_destination:
    cmp bl, 12
    jne .not_to_foundation
    mov bl, 7
    add bl, byte [current_suit]
    ; TODO: error catching
.not_to_foundation:
    ret

are_piles_compatible:
    ; Checks if source pile can legally be moved to 
    ; destination pile.
    ; arguments:
    ;   AL (source)
    ;   BL (destination)
    ; returns:
    ;   CL (answer)
    ; values of answer:
    ;   0: no
    ;   1: yes
get_bottom_card:
    ; Gets the bottom card of a pile.
    ; arguments:
    ;   BL (pile to look at)
    ; returns:
    ;   CL (value of card)
determine_compatible:
    ; determines the two compatible cards, or 4 if empty tableau
    ; (king) or 1 if empty foundation (ace)
    ; arguments:
    ;   CL (value of card)
    ; returns:
    ;   AL (first compatible card)
    ;   BL (second compatible card)
    ; if AL is 0xFF, it can be any king
    ; if AL is between 0xF0 and 0xF3, that species
    ; it can only be an ace of the specific suit in order, minus 0xF0


search_source:
    ; 

move_to_pile:
    ; Move a card from one pile to another.
    ; arguments:
    ;   AL (source)
    ;   BL (destination)
    ;   TODO: CL (free move)
    ; The source can be any of the following values:
    ;   0xFF: waste
    ;   0x00-0x06: any of the seven tableau piles
    ;   0x07-0x0A: any of the four foundations
    ; The destination can be any of the following values:
    ;   0x00-0x06: any of the seven tableau piles
    ;   0x0C: the foundation pile for the suit of
    ;         the card at the bottom of the source pile
    ; If you are moving from a tableau to another tableau
    ; first the bottom card of the destination pile is checked
    ; for the suit and rank.  Then the source pile is searched
    ; until either of the two valid cards is found in the 
    ; unhidden cards.  Then the move is performed.

    push rax
    push rbx
    push rcx
    mov byte [current_deck], bl
    ; First we look if we're moving from the waste. We need
    ; to know this in case we're moving to a foundation.
    ; If it is from the waste, save card to current_card
    cmp rax, 0xFF   ; moving from waste
    jne .next
    ; This section is only if we're moving from the waste
    mov al, [deck_pointer]
    add rax, deck
    mov bl, byte [rax]
    mov [current_card], bl
    dec byte [deck_pointer]

    ; Pick up execution here.
.next:
    
    
    call get_suit_and_rank
    mov byte [current_rank], bl
    mov byte [current_suit], al
    mov bl, byte [current_deck]
    call resolve_destination
    call find_end_of_pile
    mov [len_pile], al
    xor rax, rax
    mov al, bl
    mov ah, 32
    mul ah
    add rax, piles
    xor rcx, rcx
    mov cl, [len_pile]

    add rax, rcx
    mov bl, byte [current_card]
    mov byte [rax], bl

.exit:
    pop rcx
    pop rbx
    pop rax
    ret
write_card:
    ; this function draws a card in memory
    ; There are multiple slots to put a card
    ; seven across and 32 down
    ; bl = which column, bh = which row
    ; dl = is hidden?, dh = card value
    ; First, determine which column it's going to be
    ; Second, determine the row
    ; Third, Find the specific byte to start writing to
    ; Fourth, write it in
    call .which_col
    mov [which_vcol], ax
    call .which_row
    mov [which_vrow], ax
    mov rax, output
    add rax, [which_vcol]
    add rax, [which_vrow]
    mov [rax], byte "Q"
    jmp Exit
.which_col:
    mov al, bl
    mov ah, 12
    mul ah
    ret
.which_row:
    mov al, bh
    mov ah, 87
    mul ah
    ret


Write:
    mov cl, 12
    mov esi, card_repr
    mov edi, line
.loop:
    cmp cl, 0x0
    je .end
    lodsb
    stosb
    dec cl
    jmp .loop
.end:
Exit:
    mov eax, 4
    mov ebx, 1
    mov ecx, output
    mov edx, 87
    int 0x80
    ret
;    mov rax, line
;    mov cl, 0x0 ; which card across
;.loop:
;    mov rbx, card_repr  ; rbx = start of string
;    cmp cl, 0x7 ; if goes past last card, quit
;    je .end
;    call .subloop   ; draw a card
;    mov ch, 0x0 ; character of chard
;    inc cl  ; increment which card across
;    jmp .loop   ; restart this loop
;.subloop
;    cmp ch, 12  ;
;    je .subloopend
;    mov dl, byte [rbx]
;    mov byte [rax], dl
;    inc ch
;    inc rax
;    inc rbx
;    jmp .subloop
;.subloopend:
;    ret
;.end:
;    mov eax, 4
;    mov ebx, 1
;    mov ecx, line
;    mov edx, 87
;    int 0x80
;    ret 
;

section .bss
;piles:  times 11 resb 32
current_card: resb 1
current_suit: resb 1
current_rank: resb 1
current_deck: resb 1
current_position: resb 1
free_place: resb 1
len_pile: resb 1
line:
    resb 87
which_vcol: resb 2
which_vrow: resb 2
output: resb 2784
card_graphic: resb 3
current_color: resb 1
shuffled_cards: resb 52
random_buffer: resb 256
