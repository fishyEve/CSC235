; 
; Load a list of olympians into an array of structs
; print them out, calculating the olympian's total medals
;
; Name: Eve Collier
; 

include Irvine32.inc
include macros.inc	; maybe get rid of this idk tho champ

; define some constants
FSIZE = 150							; max file name size
CR = 0Dh							; c/r
LF = 0Ah							; line feed
ASTERISK = 2Ah						; asterisk for new entry
NULL = 00h							; null character
SPACE = 20h							; space character
STRSIZE = 32						; string sizes in struct
NUMTESTS = 3						; number of olympian medals
ROUND = 1							; cutoff for rounding
BUFFSIZE = 5000						; maximum buffer size

olympian STRUCT
	sname BYTE STRSIZE DUP('n')		; 32 bytes	
	country BYTE STRSIZE DUP('c')	; 32
	medals DWORD NUMTESTS DUP(0)	; NUMMEDALS x 32
olympian ENDS						; 160 total

.data
filename BYTE FSIZE DUP(?)			; array to hold the file name
fileptr DWORD 0						; the file pointer
prompt1 BYTE "Enter the number of olympians: ",0	; prompt for a string
prompt2 BYTE "Enter a filename: ",0	; prompt for a string
ferror BYTE "Invalid input...",0	; error message

outname2 BYTE "Olympian: ",0
medals2 BYTE "Medals: ", 0

maxnum DWORD 0						; max number of olympians
maxnum2 DWORD 0						; max number of olympians
slistptr DWORD 0					; pointer to olympian list
numread	DWORD 0						; number of olympians loaded

; for output listing (these can be used as globals)
outname  BYTE "Olympian: ",0
outcountry BYTE "Country: ",0
outmedals  BYTE "Medals: ",0


hHeap   DWORD ?						; handle to the process heap
fileHandle HANDLE ?					; file handle
buffer BYTE STRSIZE DUP (?)			; buffer to hold contents of the file provided WAS byte

slist olympian FSIZE DUP (<>)		; array of structs


.code
main PROC
	call GetProcessHeap				; get handle to prog's heap
	cmp eax, 0						; check for failure
	je ERROR
	mov hHeap, eax					; can only do this on success

	; prompt for the number of olympians 
    mov edx,OFFSET prompt1			; output the prompt
	call WriteString				; uses edx 
	call ReadInt					; get the maximium number of olympians
	mov maxnum,eax					; save it
	mov maxnum2, eax				; save it here as well
	

	;mov eax, maxnum				; move num of olympians back into eax
	push eax						; num of olympians we need structs made for
	call allocOlympians				; call PROC that will allocate memory for array of structs
	;mov slist, eax
	jc ERROR						; if carry flag is set, allocOlympians has failed
	mov slistptr, eax				; store the pointer to the beginning of the struct array 

	; prompt for the file name 
    mov edx,OFFSET prompt2			; output the prompt
	call WriteString				; uses edx 

	; read the file name
	mov edx,OFFSET filename			; point to the start of the file name string
	mov ecx,FSIZE				    ; max size for file name
	call ReadString					; load the file name (string pointer in edx, max size in ecx)
	


	call Crlf						; print extra line for neatness


	mov edx, OFFSET filename
	call OpenInputFile						; open the file
	mov fileptr, eax						; store the file handle fileptr WAS fileHandle
	cmp fileptr, INVALID_HANDLE_VALUE		; error check filename file ptr WAS fileHandle
	je ERROR								; if file not found, this is a error



	mov ebx, OFFSET slistptr	; set up ptr for array of structs
	mov edi, fileptr

	push ebx					; pass in array of struct ptr to loadAll
	mov ecx, STRSIZE
	push maxnum					; pass in max number of olympians to loadAll
	push edi					; pass in file ptr to loadAll


	call loadAllOlympians		; and call loadALl
	lea edx, [0]				; zero out edx

	mov edx, OFFSET slistptr	; reset slist ptr
	push maxnum2
	push edx
	call outputAllOlympians

	call DONE					; we can exit the program



ERROR:
	mov eax, fileptr
	call CloseFile
	call WriteWindowsMsg
	call WaitMsg
	invoke ExitProcess,0

DONE:
	mov eax, fileptr
	call CloseFile
	call WaitMsg					; wait for user to hit enter
	invoke ExitProcess,0			; bye

	ret

main ENDP


;----------------------------------------------------------------
;
; access the heap and allocate memory for olympian struct array
; recieves:
;	number of olympians we need memory allocated for (maxnum) [ebp+8]
; returns:
;	EAX = a pointer to allocated array of structs
;
;----------------------------------------------------------------
allocOlympians PROC
	push ebp
	mov ebp, esp


	mov eax, SIZEOF olympian
	mov ebx, [ebp+8]
	mul ebx						; stored in ebx
	push edx					; struct size
	push HEAP_ZERO_MEMORY		; zero the memory
	push hHeap
	call HeapAlloc

	cmp eax, 0					; pointer to memory
	jne OK
	stc
	jmp DONE

OK:
	clc							; return with CF = 0

DONE:
	mov esp, ebp
	pop ebp
	ret


allocOlympians ENDP


;----------------------------------------------------------------
;
; read a character from a file
; receives:
;	[ebp+8]  = file pointer
; returns:
;	eax = character read, or system error code if carry flag is set
;
;----------------------------------------------------------------
readFileChar PROC
	push ebp						; save the base pointer
	mov ebp,esp						; base of the stack frame
	sub esp,4						; create a local variable for the return value
	push edx						; save the registers
	push ecx

	mov eax,[ebp+8]					; file pointer
	lea edx,[ebp-4]					; pointer to value read
	mov ecx,1						; number of chars to read
	call ReadFromFile				; gets file handle from eax (loaded above)
	jc DONE							; if CF is set, leave the error code in eax
	mov eax,[ebp-4]					; otherwise, copy the char read from local variable

DONE:
	pop ecx							; restore the registers
	pop edx
	mov esp,ebp						; remove local var from stack 
	pop ebp
	ret 4
readFileChar ENDP


;----------------------------------------------------------------
;
; read a file line by line and store olympian information into array
; recieves:
;	pointer to the open file [ebp+8]
;	pointer to the output BYTE array (string type) [ebp + 16]
;	maximum size of the string (1-end of BYTE array for null terminating character) [ebp+12]
; returns:
;	the number of characters read in eax
;	the characters read will be stored in the target array
;
;----------------------------------------------------------------
readFileLine PROC
	push ebp
	mov ebp, esp
	push edx
	push ebx
	push ecx

	;mov ecx, [ebp+12]		; string size
	mov edx, [ebp+16]		; buffer
	mov edi, [ebp+8]		; file ptr		


	mov eax, 0

	LR:
	; loop till carry flag is set
	push edi							; file ptr
	call readFileChar				
	jc ERROR							; if carry flag is set, we are occuring an error
	mov ebx, LF							; move line feed into register
	cmp al, bl ;eax, ebx				; compare character returned to LF
	je NUL								; if equal, need to insert null terminator
	mov ebx, CR							; move CR into register
	cmp al,bl ;eax, ebx					; compare character returned to CR
	je CLR								; just need to increment buffer if equal
	


	mov [edx], eax						; fill buffer with file conents
	add edx, TYPE BYTE					; increment
	jmp LR								; loop

ERROR:
	call WriteWindowsMsg	
	mov eax, fileptr
	call CloseFile
	call WaitMsg					; wait for user to hit enter
	invoke ExitProcess,0			; bye
	jmp DONE

NUL:
	mov ebx, NULL					; move null terminator into register
	mov [edx-1], ebx				; add the null terminator at the end of the line
	add edx, TYPE BYTE				; increment buffer
	jmp DONE						; line is done


CLR:
	add edx, TYPE BYTE				; increment
	jmp LR							; loop

DONE:
	mov eax, OFFSET buffer			; store line in eax and return it
	pop ecx
	pop ebx
	pop edx
	mov esp, ebp
	pop ebp
	ret 



readFileLine ENDP




;----------------------------------------------------------------
;
; read info from file and load it into olympian struct
;
; recieves:
;			ptr to beginning of struct [ebp+12]
;			file ptr [ebp+8]
;
; returns:
;			updated file ptr
;			carry flag (being set if an error occured)
;
;----------------------------------------------------------------

; looked at student.asm
loadOlympians PROC 
	LOCAL data:DWORD

	push ecx
	push edx

	mov edx, OFFSET buffer	; send buffer to readfileline
	push edx
	mov esi, STRSIZE	; store max string size in esi
	push esi			; send max string size to readfileline
	mov ecx, [ebp+8]	; store file ptr in ecx
	push ecx			; send file ptr to read file line
    call readFileLine



	cmp eax, ASTERISK		; are we at the beginning of an olympian?
	;JNE ERROR				

    mov ebx, [ebp+12]	; store struct ptr into ebx



 	mov edx, OFFSET buffer	; send buffer
	push edx
	push STRSIZE		; send max string size
	mov ecx, [ebp+8]	; load file ptr
	push ecx			; send file ptr
    call readFileLine
	



	mov ebx, [ebp+12]		; store struct ptr into ebx should be slist ptr
  
	add ebx, OFFSET olympian.sname
	push ebx
	push eax
	mov edx, eax
	call Str_copy		;load the name

 

 	mov edx, OFFSET buffer	; send buffer
	push edx
	push STRSIZE		; send max string size
	mov ecx, [ebp+8]	; store file ptr
	push ecx			; send file ptr
	call readFileLine

	mov ebx, [ebp+12]

	add ebx, OFFSET olympian.country
	push ebx
	push eax
	call Str_copy		; load first country


	mov edx, 0
	mov ebx, 0
	
	mov edx, OFFSET buffer  ; send buffer
	push edx
	push STRSIZE		; send max string size
	mov ecx, [ebp+8]	; store file ptr
	push ecx			; send file ptr
	call readFileLine
	mov edx, eax			; store result in edx
	call StrLength		; find result's length
	mov ecx, eax			; store that result in ecx
	call ParseInteger32	; parse string into number
	add ebx, eax			; store first medal num in ebx



	mov edx, OFFSET buffer	; send buffer
	push edx
	push STRSIZE		; send max string size
	mov ecx, [ebp+8]	; store file ptr
	push ecx			; send file ptr
	call readFileLine
	mov edx, eax			; save result in edx
	call StrLength		; get length of result
	mov ecx, eax			; store the length in ecx
	call ParseInteger32	; prase string into number
	add ebx, eax			; add second medal number to ebx



	mov edx, OFFSET buffer	; send buffer
	push edx
	push STRSIZE		; send max string size
	mov ecx, [ebp+8]	; load file ptr
	push ecx			; send file ptr
	call readFileLine
	mov edx, eax			; store result in edx
	call StrLength		; get length of result
	mov ecx, eax			; store that in ecx
	call ParseInteger32	; parse string into number
	add ebx, eax			; add third medal count to ebx 

	mov eax, ebx		; store medals in eax

    mov ebx, [ebp+12];reset strcuct ptr


	add ebx, OFFSET olympian.medals	;increment ptr to medals 

	mov [ebx], eax
	mov edx, [ebp+12]		;reset struct ptr

	jmp DONE

  


ERROR:
	mov eax, fileHandle
	call CloseFile
	call WriteWindowsMsg
	call WaitMsg
	invoke ExitProcess,0


DONE:
	mov ecx, [ebp+8]
	mov eax, ecx			; returns updated file ptr
	pop ecx
	ret


loadOlympians ENDP





;----------------------------------------------------------------
;
; calls loadOlympians multiple times until array of olympian structs is filled
;
; recieves:
;			ptr to beginning of struct array [ebp+16]
;			file ptr [ebp+8]
;			maxnum   [ebp+12]
;
; returns:
;			num of olympians read (in eax)
;
;----------------------------------------------------------------

loadAllOlympians PROC

	push ebp
	mov ebp, esp
	push edx	
	push ecx
	mov edx, [ebp+16]			; slist ptr
	mov ebx, [ebp+8]			; file ptr

	mov esi, 0				; clear out esi

 	

	add maxnum, 1			; add one to maxnum so we can use it to loop

	L1:
	sub maxnum, 1		; decrement loop num
	cmp maxnum, 0		; if 0 we are done
	je DONE
	;mov edx, [ebp+16]	; update slist ptr
	push edx			; send to loadOlympians
	push ebx			; send file ptr to loadOlympians
	call loadOlympians
	mov ebx, eax				; store updated fileptr in edx
	add edx, SIZEOF olympian	; move to the next olympian in list
	jmp L1 
	




DONE:
	 pop ecx
	 pop edx
	 mov esp, ebp
	 pop ebp
	 ret

loadAllOlympians ENDP



;----------------------------------------------------------------
;
; outputs ONE olympian from the array of structs
;
; recieves:
;			ptr to olympian struct [ebp+8]
; returns:
;			nothing
;
;----------------------------------------------------------------


outputOlympian PROC
	;ENTER 0,0
	push ebp
	mov ebp, esp
	push edx
	push eax

	mov edx, 0
	mov edx, OFFSET outname2
	call WriteString
	
	mov edx, [ebp+8]
	add edx, OFFSET olympian.sname	; move to name element 
	call WriteString				; print it
	call Crlf

	mov edx, OFFSET outcountry
	call WriteString
 	mov edx, [ebp+8]
	add edx, OFFSET olympian.country	; move to country element
	call WriteString					; print it
	call Crlf

	mov edx, OFFSET medals2
	call WriteString
	mov edx, [ebp+8]
	add edx, OFFSET olympian.medals		; move to medal element
	mov eax, [edx]						; print it
	call WriteDec
	call Crlf

	call Crlf							; print extra line for neatness

	pop eax
	pop edx
	mov esp, ebp
	pop ebp
	;LEAVE
	;mov edx, [ebp+8]
	ret 


outputOlympian ENDP






;----------------------------------------------------------------
;
; outputs ALL olympians from the array of structs
;
; recieves:
;			ptr to first olympian struct [ebp+8]
;			maxnum - number of olympians to output [ebp+12]
; returns:
;			nothing
;
;----------------------------------------------------------------

outputAllOlympians PROC
	push ebp
	mov ebp, esp
	
	push edx
	push edi

	mov edx, [ebp+8]        ; OFFSET slistptr
	mov edi, [ebp+12]		; num of olympians to print
	mov edi, maxnum2

	add maxnum2, 1
	L1:
		sub maxnum2, 1
		cmp maxnum2, 0
		je DONE						; if at zero, we're done
		push edx					; send struct ptr to outputOlympian
		call outputOlympian
		add edx, SIZEOF olympian	; increment struct ptr
		jmp L1

	DONE:
		pop edi
		pop edx
		mov esp, ebp
		pop ebp
		ret


outputAllOlympians ENDP



END main
