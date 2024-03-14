.586 ;pentru rdtsc
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Minion Rush",0
area_width EQU 500
area_height EQU 700
area DD 0
marime dd 0
poz dd 0
counter DD 0 ; numara evenimentele de tip timer
x dd 100
arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

end_game DD 0
;----------------------------------------------------------------
;coordonate minion
button_sizem dd 95 
button_xm dd 203
button_ym dd 550
;coordonate perete(enemy)
button_sizep dd 85
button_xp dd 210
button_yp dd -50
;coordonate perete(enemy)
button_sizep2 dd 85
button_xp2 dd 310
button_yp2 dd -80
;coordonate banane

button_sizeb dd 85
button_xb dd 110
button_yb dd 0

button_sizeb2 dd 85
button_xb2 dd 310
button_yb2 dd 80
viteza dd 30
marja equ 10
vechi dd 0
category dd 0
val dd 0
culoarePlayer equ 42f5f5h
culoareEnemy equ 964B00h
culoareBanane equ 0d7f542h
stergere equ 0FFFFFFh

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm
;-----------------------DESENARE----------------------------------------
colorare_minge macro  button_x, button_y, button_size,color
local bucla_linie,umplere,iesire
	
	;atribuiri
	mov edx,button_size
	shr edx,1
	mov edi,button_y
	mov eax, button_y
	add eax, button_size
	mov marime,eax
	
	umplere:
	cmp edi, marime
	ja iesire
	mov eax, edi;eax=y
	mov ebx, area_width
	mul ebx; eax=y*area*width
	add eax, button_x; eax=y*area_width+x
	shl eax,2; eax=(y*area_width+x)*4
	add eax,area;pointer la area
	mov ecx,button_size
	bucla_linie:
	mov dword ptr[eax], color
	add eax,4
	loop bucla_linie
	inc edi
	jmp umplere
	iesire:
endm

linie_verticala macro x,y,len,color
local bucla_linie
	mov eax, y;eax=y
	mov ebx, area_width
	mul ebx; eax=y*area*width
	add eax, x; eax=y*area_width+x
	shl eax,2; eax=(y*area_width+x)*4
	add eax,area;pointer la area
	mov ecx,len
bucla_linie:
	mov dword ptr[eax],color
	add eax,4*area_width
	loop bucla_linie
endm
;---------------------------------------------------------------
;--------------------------ALTE MACRO------------------------------------
random macro n
rdtsc
	mov edx, 0
	mov ecx, n
	div ecx
	mov eax, edx
endm
;---------------------------------------------------------------
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	cmp end_game, 1 ; s-a terminat jocul?
	jz final_draw
	
	mov eax, [ebp+arg1]
	;cmp eax, 1
	;jz evt_click
	cmp eax,3
	jz evt_tasta
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	

;--------------------------cod pentru cand se face un event cu tastatura--------------------------
	evt_tasta:  

;---------sageata stanga misca patratul spre stanga-----------
;---------sageata dreapta misca patratul spre dreapta---------

	mov eax, [ebp+arg2]
	cmp eax,1Bh
	je sfarsit_de_tot
	cmp eax,25h
	je tasta_stanga 
	cmp eax,27h
	je tasta_dreapta
	jmp final_tasta ;cazul este cand eventul nu e nici left arrow key nici right arrow key
	tasta_stanga: ;merge la stanga blocu cu 100 px
	cmp button_xm,13;coliziune cu peretele din stanga
	jle final_tasta
	;urm 3 linii face ca minionul sa mearga la stanga cu 100 px
	colorare_minge  button_xm, button_ym, button_sizem, stergere
	sub button_xm, 100
	colorare_minge  button_xm, button_ym, button_sizem, 0

	jmp final_tasta
	tasta_dreapta:;merge la dreapta blocu cu 100 px
	cmp button_xm,403;coliziune cu peretele din dreapta
	je final_tasta
	;urm 3 linii face ca minionul sa mearga la dreapta cu 100 px
	colorare_minge  button_xm, button_ym, button_sizem, stergere
	add button_xm, 100

	
	
	
	
	colorare_minge  button_xm, button_ym, button_sizem, 0
	jmp final_tasta
	
	final_tasta:;aici se iasa,deocamdata nu face nimic
;-----------------------------------------------------------------------	


evt_timer:
	;inc counter
	
	
	;---------------------COLORARE ECRAN------------------------------------
	linie_verticala 100,0,area_height,0FFh
	linie_verticala 200,0,area_height,0FFh
	linie_verticala 300,0,area_height,0FFh
	linie_verticala 400,0,area_height,0FFh

	;--------------------------PLAYER---------------------------------------------
	colorare_minge  button_xm, button_ym, button_sizem, culoarePlayer ;afisez primul patrat de pe mijloc la initializare
	
	
	;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	; mov eax, button_xp2
	; cmp eax,button_xb2
	; jnz here
	; mov eax, button_yb2
	; sub eax,button_xp2
	; cmp eax,50
	; jg here
	; colorare_minge  button_xb2, button_yb2, button_sizeb2, stergere
	; add button_yb2,30
	; colorare_minge  button_xb2, button_yb2, button_sizeb2, culoareBanane
	
	
	;---------------------------PERETE 1----------------------------------
	push ecx
	colorare_minge  button_xp, button_yp, button_sizep, stergere
	mov eax,viteza
	add button_yp,eax ;cresc aici daca vreau sa maresc viteza~~~~~~~~~~~~~~~~~~~~~~`
	colorare_minge  button_xp, button_yp, button_sizep, culoareEnemy
		
	pop ecx
	cmp button_yp, 490
	jge obstacle_at_player_position
	jmp obstacle_at_player_position_end
	
	obstacle_at_player_position:
	
	; aici verifici daca atinge playerul 
	push eax
	mov eax, button_xm
	add eax, 7
	cmp button_xp, eax
	pop eax
	jz hit_player
	jmp hit_player_end
	
	hit_player:
	
	jmp game_over
	
	hit_player_end:
	
	
	obstacle_at_player_position_end:
	
	
	cmp button_yp,550 
	jne next2
	
	;urm 3 linii de cod is ptr a disparea ultimul patrat negru(era o eroare fara liniile astea)
	push ecx
	
	colorare_minge  button_xp, button_yp, button_sizep, stergere
	pop ecx
	mov button_yp,-50
	
	random 3;de la coloana 0 la coloana 2
	mov ebx,100
	mul ebx
	
	mov button_xp,eax
	add button_xp,marja 
	jmp final
	next2:
	
	 final:
	;---------------------------------------------------------------
	
	;-----------------------------PERETE 2----------------------------------
	colorare_minge  button_xp2, button_yp2, button_sizep2, stergere
	mov eax,viteza
	add button_yp2,eax ;cresc aici daca vreau sa maresc viteza~~~~~~~~~~~~~~~~~~~~~~
	colorare_minge  button_xp2, button_yp2, button_sizep2, culoareEnemy

	cmp button_yp2,550 
	jne next3
	
	
	push ecx
	colorare_minge  button_xp2, button_yp2, button_sizep2, stergere
	pop ecx
	mov button_yp2,-80
	
	random 10
	cmp eax,5
	jb coloana4
	mov eax,400
	 mov button_xp2,eax
	 add button_xp2,marja 
	jmp final2 
	coloana4:
	mov eax,300
	 mov button_xp2,eax
	 add button_xp2,marja 
	next3:
	 
	cmp button_yp2, 490
	jz obstacle_at_player_position2;--------------------------------------------------------
	jmp obstacle_at_player_position_end2
	
	obstacle_at_player_position2:
	
	; aici verifici daca atinge playerul 
	push eax
	mov eax, button_xm
	add eax, 7
	cmp button_xp2, eax
	pop eax
	jz hit_player2
	jmp hit_player_end2
	
	hit_player2:
	
	jmp game_over
	
	hit_player_end2:
	
	
	obstacle_at_player_position_end2:
	
	
	final2:
	;---------------------------------------------------------------
	
	;--------------------------BANANA 1------------------------------------
	 colorare_minge  button_xb, button_yb, button_sizeb, stergere
	 mov eax,viteza
	 add button_yb,eax ;cresc aici daca vreau sa maresc viteza~~~~~~~~~~~~~~~~~~~~~~`
	 colorare_minge  button_xb, button_yb, button_sizeb, culoareBanane
	
	cmp button_yb, 480
	jae obstacle_at_player_position3
	jmp obstacle_at_player_position_end3
	
	obstacle_at_player_position3:
	
	; aici verifici daca atinge playerul 
	push eax
	mov eax, button_xm
	add eax, 7
	cmp button_xb, eax
	pop eax
	jz hit_player3
	jmp hit_player_end3
	
	hit_player3:
	
	
	colorare_minge  button_xb, button_yb, button_sizeb, stergere
	mov eax,20
	add counter,eax
	colorare_minge  button_xm, button_ym, button_sizem, culoarePlayer
	jmp banana_sf
	hit_player_end3:
	
	obstacle_at_player_position_end3:
	
	 cmp button_yb,550 
	 jb final3
	
	;urm 3 linii de cod is ptr a disparea ultimul patrat negru(era o eroare fara liniile astea)
	 push ecx
	 colorare_minge  button_xb, button_yb, button_sizeb, stergere
	 pop ecx
	 banana_sf:
	 mov button_yb,0
	
	 random 10;------
	 cmp eax,5
	 jbe coloana_2
	 mov eax,100
	 mov button_xb,eax
	 add button_xb,marja 
	 jmp final3
	
	 coloana_2:
	 mov eax,0
	 mov button_xb,eax
	 add button_xb,marja
	 jmp final3
	
	
	 final3:
	;---------------------------------------------------------------
	
	
	;------------------------BANANA 2--------------------------------------
	colorare_minge  button_xb2, button_yb2, button_sizeb2, stergere
	mov eax,viteza
	 add button_yb2,eax ;cresc aici daca vreau sa maresc viteza~~~~~~~~~~~~~~~~~~~~~~`
	 colorare_minge  button_xb2, button_yb2, button_sizeb2, culoareBanane
	
	cmp button_yb2, 480
	jae obstacle_at_player_position4
	jmp obstacle_at_player_position_end4
	
	obstacle_at_player_position4:
	
	; aici verifici daca atinge playerul 
	push eax
	mov eax, button_xm
	add eax, 7
	cmp button_xb2, eax
	pop eax
	jz hit_player4
	jmp hit_player_end4
	
	hit_player4:
	
	
	colorare_minge  button_xb2, button_yb2, button_sizeb2, stergere
	mov eax,20
	add counter,eax
	colorare_minge  button_xm, button_ym, button_sizem, culoarePlayer
	jmp banana_sf2
	hit_player_end4:
	
	obstacle_at_player_position_end4:
	

	 cmp button_yb2,550 
	 jb final4
	
	
	 push ecx
	 colorare_minge  button_xb2, button_yb2, button_sizeb2, stergere
	 pop ecx
	 banana_sf2:
	 mov button_yb2,0
	
	 random 15
	 cmp eax,5
	 jbe coloana_3
	 cmp eax,10
	 jbe coloana_4
	 mov eax,400
	 mov button_xb2,eax
	 add button_xb2,marja 
	 jmp final4
	coloana_3:
	mov eax,200
	 mov button_xb2,eax
	 add button_xb2,marja 
	jmp final4
	coloana_4:
	mov eax,300
	 mov button_xb2,eax
	 add button_xb2,marja
	jmp final4
	
	 final4:
	 ;---------------------------------------------------------------
	 
	 
	jmp afisare_litere
	;------------------------SFARSIT DE JOC--------------------------------------
	game_over:

	 
	 colorare_minge  button_xp, button_yp, button_sizep, stergere
	 mov eax,button_yp
	 sub eax,20
	 mov button_yp,eax
	 colorare_minge  button_xp, button_yp, button_sizep, culoareEnemy
	 colorare_minge  button_xp2, button_yp2, button_sizep2, culoareEnemy
	 
	 colorare_minge  button_xb, button_yb, button_sizeb, stergere
	 colorare_minge  button_xb2, button_yb2, button_sizeb2, stergere
	 colorare_minge  button_xm, button_ym, button_sizem, culoarePlayer
	 make_text_macro 'G', area, 210, 300
	 make_text_macro 'A', area, 220, 300
	 make_text_macro 'M', area, 230, 300
	 make_text_macro 'E', area, 240, 300
	 make_text_macro 'O', area, 260, 300
	 make_text_macro 'V', area, 270, 300
	 make_text_macro 'E', area, 280, 300
	 make_text_macro 'R', area, 290, 300
	 mov end_game, 1
	 
	 jmp final_draw
	;---------------------------------------------------------------
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 40, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	
	
	;cifra miilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
	;scriem un mesaj
	;make_text_macro 'P', area, 110, 100
	

	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
	
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2; inmul 4 - pe doubleword
	push eax
	call malloc;aloca memorie dinamica zonei de desenat 
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw;functie principala
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	sfarsit_de_tot:
	push 0
	call exit
end start
