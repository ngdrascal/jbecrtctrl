$MACROFILE M0D85
; VERSION 1.3 PUB REV. B
;FILENAME CRT.SRC CREATED 17 NOV 1979 BY TOM ROSSI
        NAME    CRT
;THIS FILE CONTAINS THE SOURCE FOR THE 8275 CRT DEMO DESIGNED
;BY TOM ROSSI AND BASED ON THE APPLICATION NOTE WRITTEN BY
;JOHN KATAUSKY

LINSIZ EQU  80                  ;80 CHARACTERS PER LINE.
NUMLIN EQU  25                  ;25 CHARACTER LINES PER FRAME.

;MEMORY MAP
;   ROM      0000-7FFF
;   USART    2000-2001
;   PIO      4000-4003
;   RAM      6000-6FFF
;THE RAM IS FURTHER BROKEN DOWN INTO FOUR SECTIONS:
;   STORE DATA   6000-67FF
;   8275 CS + RAM    6800-6FFF
;   8275 DACK + RAM      7000-77FF
;   8253 + RAM   7800-7FFF
;THE FIRST (LINSIZ*NUMLIN) RAM LOCATIONS ARE RESERVED FOR THE CRT DISPLAY.
;   THE REMAINING LOCATIONS ARE USED FOR LOCAL VARIABLES, STACK,
;   AND TO INITIALIZE THE 8253 AND 8275.
;CHARACTERS ARE ADDED TO THE DISPLAY BY WRITING TO THE 'STORE DATA'
;   ADDRESSES. THE SYSTEM REFRESHES THE CRT DISPLAY BY READING THE SAME
;   LOCATIONS THROUGH THE .'8275 + DACK' ADDRESSES.
;THE 8253 IS INITIALIZED BY WRITING THE APPROPRIATE PARAMETERS DIRECTLY 
;   TO THE PERIPHERAL. BECAUSE OF THE MINIMAL ADDRESA DECODING USED,
;   THIS WILL ALSO WRITE OVER FOUR OF THE 'STORE DATA' LOCATIONS.
;TWO OF THESE LOCATIONS ARE ALSO USED TO INITIALIZE THE 8275.
;   THIS IS ACCOMPLISHED BY WRITING THE INITIALIZATION PARAMETERS TO THE
;   APPROPRIATE 'STORE DATA' LOCATIONS, AND THE PERFORMING A READ
;   TO THE 8275 CS ADDRESS.

$EJECT
        ASEG
        ORG     6000H           ;START OF RAM.

RAM:
TOPDIS: DS      LINSIZ*NUMLIN-1
BOTDIS: DS      1
LAST:

        ORG     2*( ($+1)/2 )   ;ALIGN TO EVEN ADDRESS.
LD75:   DS      4               ;BUFFER USED^TO INIT 8275,8253.

CURAD:  DS      2
TOPAD:  DS      2
L0C80:  DS      2
CURSY:  DS      1
CURSX:  DS      1
USCHR:  DS      1
KEYDWN: DS      1
KBCHR:  DS      1
BAUD:   DS      1
KEYOK:  DS      1
ESCP:   DS      1
SHCON:  DS      1
RETLIN: DS      1
SCNLIN: DS      1
LINCNT: DS      1

STPTR   EQU     RAM+800H        ;PROGRAM STACK.
CS75    EQU     LD75+800H
DACK    EQU     TOPDIS+1000H    ;RAM + 8275 DACK
BASE53  EQU     LD75+1800H      ;RAM + 8253 CS.
BASE55  EQU     4000H           ;8255 BASE ADDRESS.
PORTA   EQU     BASE55+0        ;
PORTB   EQU     BASE55+1        ;
PORTC   EQU     BASE55+2        ;
CMD55   EQU     BASE55+3        ;
BASE51  EQU     2000H           ;8251 BASE ADDRESS.
SERDAT  EQU     BASE51+0
SERCMD  EQU     BASE51+1
CNTO    EQU     BASE53+0
CNT1    EQU     BASE53+1
CNT2    EQU     BASE53+2
CNTM    EQU     BASE53+3
CRTPAR  EQU     CS75+0
CRTCMD  EQU     CS75+1
CURBOT  EQU     NUMLIN-1
VRTC    EQU     08H             ;CONNECTED TO 8255A PORT C BIT 3.
LCL     EQU     80H             ;CONNECTED TO 8255A PORT C BIT 7.
EOR     EQU     0F0H            ;END-OF-RDW CMD FOR 8275.
$EJECT

        ASEG
        ORG 0
;INITIALIZE VARIABLES.
INIT:   DI                  ;DISABLE INTERRUPTS
        LXI     SP,STPTR    ;LOAD STACK POINTER
        LXI     H,TOPDIS    ;LOAD H&L WITH TOP OF DISPLAY
        SHLD    TOPAD       ; SET TOP = TOP OF DISPLAY
        SHLD    CURAD       ;STORE THE CURRENT ADDRESS
        LXI     H,CURSY     ;CLEAR VARIABLES 'CURSY' TO 'LINCNT'..
        MVI     C,LINCNT-CURSY
INIT1:  MVI     M,0
        INX     H
        DCR     C
        JNZ     INIT1
        MVI     M,NUMLIN    ; INIT LINCNT
        ;THIS ROUTINE CLEARS THE ENTIRE SCREEN BY PUTTING
        ;SPACE CODES (20H) IN EVERY LOCATION ON THE SCREEN.
        ;
        LXI     B,LAST
        LXI     H,TOPDIS
        MVI     E,' '
LOOPF:  MOV     M,E
        INX     H
        MOV     A,L
        CMP     C
        JNZ     LOOPF
        MOV     A,H
        CMP     B
        JNZ     LOOPF
        JMP     INIT55

$EJECT
;RST 6.5 LINE INTERRUPT ROUTINE.
;THIS ROUTINE IS EXECUTED ONCE EVERY CHARACTER LINE.
;THE PROCESSOR THEN SENDS THE NEXT LINE TO THE 8275 ROH DUFFER,
;THEN CHECKS TO SEE IF IT IS THE LAST LINE IN THE FRAME.
        ORG     34H
POPDAT: PUSH    PSW             ;SAVE A AND FLAGS
        PUSH    D               ;SAVE D AND E
        PUSH    H               ;SAVE H AND L
        LXI     H,0000H         ;ZERO H AND L
        DAD     SP              ;PUT STACK POINTER IN H AND I
        XCHG                    ;PUK STACK IN D AND E
        LHLD    CURAD           ;GET POINTER
        LXI     SP,DACK-TOPDIS  ;ADD DACK OFFSET.
        DAD     SP
        SPHL                    ;BUT CURRENT LINE INTO SP
        REPT    (LINSIZ/2)
        POP     H
        ENDM
        LXI     H,TOPDIS-DACK   ;CORRECT FOR DACK OFFSET.
        DAD     SP              ;ADD STACK
        XCHG                    ;PUT STACK IN H AND L
        SPHL                    ;RESTORE STACK
;CHECK FOR DISPLAY MEMORY WRAPAROUND.
        LXI     H, - (LAST)
        DAD     D
        XCHG
        JNC     NOWRAP
        LXI     H,TOPDIS
NOWRAP: SHLD    CURAD           ;PUT BACK CURRENT ADDRESS

;CHECK FOR LAST LINE IN THE FRANE.
        LXI     H,LINCNT
        DCR     M
        JNZ     LINE            ;JMP    IF MORE LINES.
        MVI     M,NUMLIN        ;RE-INIT    LINE COUNT.
        ;
        ;FRAME ROUTINE.
        ;THIS ROUTINE CHECKS THE BAUD RATE SWITCHES, RESETS THE
        ;SCREEN POINTERS AND READS AND LOOKS UP THE KEYBOARD.
        ;
        ;SET UP THE POINTER
        ;
FRAME:  PUSH    B
        LHLD    TOPAD           ;LOAD TOP IN H AND L
        SHLD    CURAD           ;STORE TOP IN CURRENT ADDRESS
        ;
        ;SET UP BAUD RATE
        ;
        LDA     PORTC           ;READ BAUD RATE SWITCHES
        ANI     111B
        LXI     H,BAUD
        CMP     M
        CNZ     STB1            ;IF NOT SAME, THEN CHANGE USART CLOCKS
        ;
        ;READ KEYBOARD
        ;
        LDA     KEYDWN          ;SEE IF A KEY IS DOWN
        ANI     40H             ;SET THE FLAGS
        JNZ     KYDOWN          ;IF KEY IS DOWN JUMP AROUND
        CALL    RDKB            ;GO READ THE KEYBOARD
EFRAME: POP     B

LINE:   POP     H
        POP     D
        POP     PSW
        EI
        RET

;REST OF POWER-ON INITIALIZATION CONTINUES HERE.
INIT55: MVI     A,8BH          ;MOVE 8255 CONTROL WORD INTO A
        STA     CMD55           ;PUT CONTROL WORD INTO 8255
        ;
        ; 8251 INITIALIZATION
        ;
INIT51: LXI     H,SERCMD        ;PQINT TO 8251A COMMAND REGISTER
        MVI     M,80H           ;DUMMY STORE TO 8251
        MVI     M,00H           ;RESET 8251
        MVI     M,40H
        NOP                     ;WAIT FOR RESET TO OCCUR.
        NOP
        NOP
        NOP
        MVI     M,0EAH          ;2 STOP BITS, NO PARITY, 16X RATE, 8 DATA BITS
        MVI     M,27H           ;ENABLE RTS, TX, RX
        ;
        ;8253 INITIALIZATION
        ;
        MVI     A,32H           ;CONTROL WORD FOR 8253
        STA     CNTM            ;PUT CONTROL WORD INTO 8253
        MVI     A,32H           ;LSB 8253
        STA     CNTO            ;PUT IT IN 8253
        MVI     A,00H           ;MSD 8253
        STA     CNTO            ;PUT IT IN 8253
        CALL    SIBAUD          ;CO DO BAUD RATE
        ;
        ;B275 INITIALIZATION
        ;
IN75:   LXI     D,CRTCMD
        LXI     H,LD75+1
        MVI     M,00H           ;RESET AND STOP DISPLAY
        LDAX    D
        DCX     D
        DCX     H               ;HL=1000H
        MVI     M,LINSIZ-1
        LDAX    D
        MVI     M, 40H+(NUMLIN-1);2 ROWS/VRTC, (NUMLIN) CHARACTER ROWS
        LDAX    D
        MVI     M,0B9H          ;UNDERLINE ROW 8, 10 HRTC/CHAR
        LDAX    D
        MVI     M, 0DDH         ;NON-DFFSET, TRANSPARENT, BLINK UNDERLINE, HRTC=28 CCLK
        LDAX    D
        CALL    LDCUR           ;LOAD THE CURSOR
        INX     H
        INX     D
        MVI     M,0E0H          ;PRESET COUNTERS
        LDAX    D
        MVI     M, 23H          ;START DISPLAY
        LDAX    D
;CRT INITIALIZATION IS COMPLETE AT THIS POINT, AND VRTC AND HUTC ARE
;FREE-RUNNING. INTERRUPTS WILL NOT BE ENABLED UNTIL THE FIRST VERTICAL
;RETRACE INTERVAL. THIS WILL SYNC THE SOFTWARE TO THE CRT DMA REQUESTS.
;VRTC IS MONITORED VIA BIT 7 OF THE B255A. WHEN A L-TO-H IS
;DETECTED, THE PROGRAM WILL DROP THRU TO THE IDLE LOOP AND ENABLE
;INTERRUPTS.
        LXI     H,PORTC
IN75A:  MOV     A, M
        ANI     VRTC
        JNZ     IN75A
IH75B:  MOV     A,M
        ANI     VRTC
        JZ      IH75B

;THIS IS THE CRT IDLE LOOP. THE LINE/LOCAL SWITCH IS MONITORED,
;AND ANY KEY DEPRESSIONS FREOM THE PREVIOUS FRAME INTERRUPT ARE
;HANDLED CORRESPONDINGLY.
SETUP:  MVI     A,18H           ;SET MASK
        SIM                     ;LOAD MASK
        EI                      ;ENABLE INTERRUPTS
        ;
        ;READ THE USART
        ;
RXRDY:  LDA     PORTC           ;TEST LINE/LOCAL SWITCH.
        ANI     LCL
        JNZ     KEYINP          ;LEAVE IF IN LOCAL
        LDA     SERCMD          ;READ 8251 FLAGS
        ANI     02H             ;LOOK AT RXRDY
        JNZ     0K7             ;IF HAVE CHARACTER GO TO WORK
KEYINP: LDA     KEYDWN          ;GET KEYBOARD CHARACTER
        ANI     80H             ;IS IT THERE
        JNZ     KEYS            ;IF KEY IS PUSHED LEAVE
        MVI     A,00H           ;ZERO A
        STA     KEYOK           ;CLEAR KEYOK
        JMP     RXRDY           ;LOOP AGAIN

;AUTO-REPEAT FUNCTION.
;NOT IMPLEMENTED YET.
REPEAT: JMP     RXRDY

;PROGRAM REACHES THIS POINT IF KEY DEPRESSION WAS SENSES
;DURING LAST KEYBOARD SCAN.
KEYS:   LDA     KEYOK           ;WAS KEY DOWN
        MOV     C,A             ;SAVE A IN C
        LDA     KBCHR           ;GET KEYBOARD CHARACTER
        CMP     C               ;IS IT THE SAME AS KEYOK
        JZ      REPEAT          ;CHECK FOR KEY REPEAT.
        STA     KEYOK           ;IF NOT SAVE IT
        STA     USCHR           ;SAVE IT
        LDA     PORTC           ;TEST LINE/LOCAL SWITCH.
        ANI     LCL
        JNZ     CHREC           ;JMP IF IN LOCAL MODE.
TRANS:  LDA     SERCMD          ;GET USART FLAGS
        ANI     01H             ;READY TO TRANSMIT?
        JZ      TRANS           ;LOOP IF NOT READY
        LDA     USCHR           ;GET CHARACTER
        STA     SERDAT          ;PUT IN USART
        JMP     SETUP           ;LEAVE
OK7:    LDA     SERDAT          ;READ USART
        ANI     07FH            ;STRIP MSB
        STA     USCHR           ;PUT IT IN MEMORY

        ;THIS ROUTINE CHECKS FOR ESCAPE CHARACTERS, LF, CR,
        ;FF, AND BACK SPACE
        ;
CHREC:  LDA     ESCP            ;ESCAPE SET?
        CPI     80H             ;SEE IF IT IS
        JZ      ESSQ            ;LEAVE IF IT IS
        LDA     USCHR           ;GET CHARACTER
        CPI     0AH             ;LINE FEED
        JZ      LNFD            ;GO TO LINE FEED
        CPI     0CH             ;FORM FEED
        JZ      FMFD            ;GO TO FORM FEED
        CPI     0DH             ;CR
        JZ      CORT            ;DO A CR
        CPI     08H             ;BACK SPACE
        JZ      LEFT            ;DO A BACK SPACE
        CPI     1BH             ;ESCAPE
        JZ      ESKAP           ;DO AN ESCAPE
        ORA     A               ;CLEAR CARRY
        ADI     0E0H            ;SEE IF CHARACTER IS PRINTABLE
        JC      CHRPUT          ;IF PRINTABLE DO IT
        JMP     SETUP           ;GO BACK AND READ USART AGAIN

;THIS ROUTINE IS USED TO SCAN THE KEYBOARD DURIN THE VERTICAL
;RETRACE INTERVAL. IF A KEY DEPRESSION IS SENSED, THEN 'SCNLIN'
;IS SET TO THE VALUE OF THE SCAN LINES IN WHICH THE KEY IS SENSED,
;AND 'RETLIN' IS SET TO THE VALUE OF THE .RETURN LINES, AND
;'KEYDOWN' IS SET TO 4OH. THIS INFORMATION IS USED BY THE IDLE LOOP
;TO PERFORM KEY DEBOUNCE AND VALIDATION.
RDKB:   LXI     H,SHCON         ;INIT FOR KEYBOARD  SCAN.
        LDA     PORTC           ;SAVE CONTROL AND SHIFT KEYS.
        MOV     M,A
        MVI     A, NOT  1
LOOPK:  STA     PORTA           ;SET SCAN LINES
        MOV     B,A
        LDA     PORTB           ;READ RETURN LINES
        INR     A               ;CHECK ANY KEYS DOWN.
        JNZ     SAVKEY          ;JMP IF KEY DEPRESSED.
        MOV     A,B             ;CALCULATE NEXT SCAN VALUE.
        RLC
        JC      LOOPK           ;JMP IF MORE SCAN LINES.
        XRA     A               ;OTHERWISE, INDICATE ND KEYS DOWN.
        STA     KEYDWN
        RET
SAVKEY: INX     H               ;POINT AT 'RETLIN'.
        DCR     A               ;ADJUST RETURN LINES.
        MOV     M,A             ;SAVE RETURN LINE IN MEMORY
        INX     H               ;POINT H AT SCAM LINE
        MOV     M,B             ;SAVE SCAN LINE IN MEMORY '
        MVI     A,40H           ;SET A
        STA     KEYDWN          ;SAVE KEY DOWN
        RET                     ;LEAVE

;THIS ROUTINE IS CALLED FROM THE FRAME ’INTERRUPT WHEN A KEY DEPRESSION
;WAS SENSED DURING THE LAST VERTICAL RETRACE INTERVAL.
KYDOWN: LXI     H, SCNLIN       ;GET SCAN LINE
        MOV     A,M             ;PUT SCAN LINE IN A
        STA     PORTA           ;OUTPUT SCAN LINE TO PORT A
        DCX     H               ;POINT AT RETURN LINE
        LDA     PORTB           ;GET-RETURN LINES
        ORA     M               ;ARCTHEY THE SAME?
        CMA                     ;INVERT A
        ORA     A               ;SET.FLAGS
        JZ      KYCHNG          ;IF DIFFERENT KEY HAS CHANGED
        LDA     KEYDWN          ;GET KEY DOWN
        ANI     01H             ;HAS, THIS BEEN DONE BEFORE?
        JNZ     EFRAME          ;LEAVE IF IT HAS
        LDA     PORTB           ;GET RETURN LINE
        MVI     B,0FFH          ;GET READY TO ZERO B
UP:     INR     B               ;ZERO B
        RRC                     ;ROTATE A
        JC      UP              ;DO IT AGAIN
        INX     H               ;POINT H AT SCAN LINES
        MOV     A,M             ;GET SCAN LINES
        MVI     C,0FFH          ;GET READY TO LOOP
UP1:    INR     C               ;START C COUNTING
        RRC                     ;ROTATE A
        JC      UP1             ;JUMP TO LOOP
        MOV     A,B             ;GET RETURN LINES
        RLC                     ;MOVE OVER ONCE
        RLC                     ;MOVE OVER TWICE
        RLC                     ;MOVE OVER THREE TIMES
        ORA     C               ;DR SCAN AND RETURN LINES
        MOV     B,A             ;SAVE A IN  B
        LDA     PORTC           ;GET SHIFT  CONTROL
        ANI     4OH             ;IS CONTROL SET
        MOV     C,A             ;SAVE A IN  C
        LDA     SHCON           ;GET SHIFT  CONTROL
        MOV     D,A             ;SAVE A IN D
        ANI     40H             ;STRIP CONTROL
        ORA     C               ;SET BIT
        JZ      CNTDWN          ;IF SET LEAVE
        LDA     PORTC           ;READ IT AGAIN
        ANI     20H             ;STRIP SHIFT
        MOV     C,A             ;SAVE A
        MOV     A,D             ; GET SHIFT CONTROL
        ANI     20H             ;STRIP CONTROL
        ORA     C               ;ARE THEY THE SAME?
        JZ      SHDWN           ;IF SET LEAVE
SCR:    MOV     E,B             ;PUT TARGET IN E
        MVI     D,00H           ;ZERO D
        LXI     H,KYLKUP        ;GET LOOKUP TABLE
        DAD     D               ;GET OFFSE T
        MOV     A,M             ;GET CHARACTER
        MOV     B,A             ;PUT CHARACTER IN B
        LDA     PORTC           ;GET PORTC
        ANI     10H             ;STRIP BIT
        JZ      CAPLOC          ;CAPS LOCK
        MOV     A,B             ;GET A BACK
STKEY:  STA     KBCHR           ;SAVE CHARACTER
        MVI     A,0C1H          ;SET A
        STA     KEYDWN          ;SAVE KEY DOWN
        JMP     EFRAME          ;LEAVE

KYCHNG: MVI     A,00H           ;ZERO 0
        STA     KEYDWN          ; RESET KEY DOWN
        JMP     EFRAME          ;LEAVE
        ;
        ;IF THE CAP LOCK BUTTON IS PUSHED THIS ROUTINE SEES IF
        ;THE CHARACTER IS BETWEEN ill! AND 7AH AND IF IT IS THIS
        ;ROUTINE ASSUMES THAT THE CHARACTER IS LOWER CASE ASCII
        ;AND SUBTRACTS 20H, WHICH CONVERTS THE CHARACTER TO
        ;UPPER CASE ASCII
        ;
CAPLOC: MOV     A,B             ;GET A BACK
        CPI     60H             ;HOW BIG IS IT?
        JC      STKEY           ;LEAVE IF IT'S TOO SMALL
        CPI     7BH             ;IS IT TOO BIG
        JNC     STKEY           ;LEAVE IF IGO BIG
        SUI     20H             ;ADJUST A
        JMP     STKEY           ;STORE THE KEY
        ;
        ;THE ROUTINES SHDWN AND CNTDWN SET BIT 6 AND 7 RESPECTIVLY
        ;IN THE. ACC.
        ;
CNTDWN: MVI     A,80H           ;SET BIT 7 IN A
        ORA     B               ;OR WITH CHARACTER
        ANI     0BFH            ;MAKE SURE SHIFT IS NOT SET
        MOV     B,A             ;PUT IT BACK IN B
        JMP     SCR             ;GO BACK
SHDWN:  MVI     A,40H           ;SET BIT 6 IN A
        ORA     B               ;OR WITH CHARACTER
        MOV     B,A             ;PUT IT BACK IN B
        JMP     SCR             ;GO BACK
        ;
        ;THIS ROUTINE RESETS THE ESCAPE LOCATION AND DECODES
        ;THE CHARACTERS FOLLOWING AN ESCAPE. THE COMMANDS ARE
        ;COMPATABLE WITH INTELS CREDIT TEXT EDITOR
        ;
ESSQ:   MVI     A,00H           ;ZERO A
        STA     ESCP            ;RESET ESCP
        LDA     USCHR           ;GET CHARACTER
        CPI     'B'             ;DOWN
        JZ      DOWN            ;MOVE CURSOR    DOWN
        CPI     'E'             ;CLEAR SCREEN CHARACTER
        JZ      CLEAR           ;CLEAR  THE SCREEN
        CPI     'J'             ;CLEAR  REST OF SCREEn
        JZ      CLRST           ;GO CLEAR THE REST OF THE SCREEN
        CPI     'K'             ;CLEAR LINE CHARACTER
        JZ      CLRLIN          ;GO CLEAR A LINE
        CPI     'A'             ;CURSOR UP CHARACTER
        JZ      UPCUR           ;MOVE CURSOR UP
        CPI     'C'             ;CURSOR RIGHT CHARACTER
        JZ      RIGHT           ;MOVE CURSOR TO THE RIGHT
        CPI     'D'             ;CURSOR LEFT CHARACTER
        JZ      LEFT            ;MOVE CURSOR TO THE LEFT
        CPI     'H'             ;HOME CURSOR CHARACTER
        JZ      HOME            ;HOME THE CURSOR
        JMP     SETUP           ;LEAVE
        ;
        ;THIS ROUTINE MOVES THE CURSOR DOWN ONE CHARACTER LINE
        ;
DOWN:   LDA     CURSY           ;PUT CURSOR Y IN A
        CPI     CURBOT          ;SEE IF ON BOTTOM OF SCREEN
        JZ      SETUP           ;LEAVE IF ON BOTTOM
        INR     A               ;INCrEMENT Y CURSOR
        STA     CURSY           ;SAVE NEW CURSOR
        CALL    LDCUR           ;LOAD THE CURSOR
        CALL    CALCU           ;CALCULATE ADDRESS
        MOV     A,M             ;GET FIRST LOCATION OF THE LINE
        CPI     0F0H            ;SEE IF CLEAR SCREEN CHARACTER
        JNZ     SETUP           ;Leave if it is not
        SHLD    L0C80           ;SAVE BEGINNING OF THE LINE
        CALL    CLLINE          ;CLEAR THE LINE
        JMP     SETUP           ;LEAVE
        ;
        ;THIS ROUTINE CLEARS THE SCREEN.
        ;
CLEAR:  CALL    CLSCR           ;GO CLEAR THE SCREEN
        JMP     SETUP           ;GO BACK
        ;
        ;THIS ROUTINE CLEARS ALL LINES BENEATH THE LOCATION
        ;OF THE CURSOR.
        ;
CLRST:  CALL    CALCU           ;CALCULATE ADDRESS
        CALL    ADX             ;ADD X POSITION
        MVI     B,LINSIZ        ;LOAD LARGEST X COORDINATE.
        MVI     C,' '
        LDA     CURSY           ;LOAD CURRENT Y COORDINATE.
        MOV     E,A
        LDA     CURSX           ;LOAD CURRENT X COORDINATE.
        ANA     A               ;SEE IF AT BEGINNING OF LINE.
        JZ      OVR1            ;JMP IF IT IS.
LLP:    MOV     M,C             ;CLEAR NEXT CHARACTER ON CURRENT LINE.
        INX     H
        INR     A               ;SEE IF MORE TO THE LINE.
        CMP     B
        JNZ     LLP             ;JMP IF MORE.
        INR     E               ;UPDATE LINE COUNT.
OVR1:   LXI     B,LINSIZ        ;LOAD OFFSET TO NEXT LIME.
OVR2:   MOV     A,E             ;SEE IF MORE LINES
        CPI     NUMLIN
        JZ      SETUP           ;EXIT IF DONE.
        MVI     M,EOR           ;BLANK ROW.
        INR     E               ;UPDATE LINE COUNTER.
        DAD     B               ;POINT TO NEXT  ROW.
        MOV     A,L             ;CHECK FOR DISPLAY WRAP-AROUND.
        CPI     LOW(LAST)
        JNZ     OVR2
        MOV     A,H
        CPI     HIGH(LAST)
        JNZ     OVR2
        LXI     H,TOPDIS        ;CORRECT FOR WRAP-AROUND.
        JMP     OVR2            ;CONTINUE BLANKING REST OF SCREEN.
        ;
        ;THIS ROUTINE CLEARS THE LINg THE CURSOR IS ON.
        ;
CLRLIN: CALL    CALCU           ;CALCULATE ADDRESS
        SHLD    L0C80           ;STORE H AND L TO CLEAR LINE
        CALL    CLLINE          ; CLEAL THE LINE
        JMP     SETUP           ; CO BACK
        ;
        ;THIS ROUTINE NOVES THE CURSOR UP ONE LINE.
        ;
UPCUR:  LDA     CURSY           ;GET Y CURSOR
        CPI     00H             ;IS IT ZERO
        JZ      SETUP           ;IF IT IS LEAVE
        DCR     A               ;MOVE CURSOR UP
        STA     CURSY           ;SAVE NEW CURSOR
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP           ;LEAVE
        ;
        ;THIS ROUTINE MOVES THE CURSOR ONE LOCATION TO THE RIGHT
        ;
RIGHT:  LDA     CURSX           ;GET X  CURSOR
        CPI     LINSIZ-1        ;IS IT  ALL THE WAY OVER?
        JNZ     NTOVER          ;IF NOT JUMP AROUND
        LDA     CURSY           ;GET Y CURSOR
        CPI     CURBOT          ;SEE IF ON BOTTOM
        JZ      GD18            ;IF WE ARE JUMP
        INR     A               ;INCREMENT Y CURSOR
        STA     CURSY           ;SAVE IT
GD18:   MVI     A,00H           ;ZERD A
        STA     CURSX           ;ZERO X CURSOR
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP           ;LEAVE
NTOVER: INR     A               ;INCREMENT X CURSOR
        STA     CURSX           ;SAVE IT
        CALL    LDCUR           ;LOAD THE   CURSOR
        JMP     SETUP           ;LEAVE
        ;
        ;THIS ROUTINE MOVES THE CURSOR LEFT ONE CHARACTER POSITION
        ;
LEFT:   LDA     CURSX           ;GET X CURSOR
        CPI     00H             ;IS IT ALL THE WAY OVER
        JNZ     NOVER           ;IF NOT JUMP AROUND
        LDA     CURSY           ;GET CURSOR Y
        CPI     00H             ;IS IT ZERO?    '
        JZ      SETUP           ;IF IT IS JUMP  '
        DCR     A               ;MOVE CURSOR Y UP   ’
        STA     CURSY           ;SAVE   IT
        MVI     A,LINSIZ-1      ;GET LAST X LOCATION
        STA     CURSX           ;SAVE IT
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP
NOVER:  DCR A                   ;ADJUST X CURSOR
        STA     CURSX           ;SAVE CURSOR X
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP           ;LEAVE
        ;
        ;THIS ROUTINE HOMES THE CURSOR.
        ;
HOME:   MVI     A,00H           ;ZERO A
        STA     CURSX           ;ZERO X CURSOR
        STA     CURSY           ;ZERO Y CURSOR
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP           ;LEAVE
        ;
        ; THIS ROUTINE SETS THE ESCAPE BIT
        ;
ESKAP:  MVI     A,80H           ;LOAD A WITH ESCAPE BIT
        STA     ESCP            ;SET ESCAPE LOCATION
        JMP     SETUP           ;CD BACK AND READ USART
        ;
        ;THIS ROUTINE DOES A CR
        ;
CORT:   MVI     A,00H           ;ZERO A
        STA     CURSX           ;ZERO CURSOR X
        CALL    LDCUR           ;LOAD CURSOR INTO 8275
        JMP     SETUP           ;POLL USART AGAIN
        ;
        ;THIS   ROUTINE LOADS THE CURSOR
        ;
LDCUR:  LXI     H,LD75+1
        LXI     D,CRTCMD
LDCUR1: MVI     M,80H           ;LOAD CURSOR COMMAND.
        LDAX    D
        DCX     D
        DCX     H
        LDA     CURSX
        MOV     M,A
        LDAX    D
        LDA     CURSY
        MOV     M,A
        LDAX    D
        RET
        ;
        ;THIS ROUTINE DOES A FORM FEED
        ;
FMFD:   CALL    CLSCR           ;CALL CLEAR SCREEN
        LXI     H,TOPDIS        ;PUT TOP DISPLAY IN I IL
        SHLD    L0C80           ;PUT IT IN LOCBO
        CALL    CLLINE          ;CLEAR TOP LINE
        MVI     A,00H           ;ZERO A
        STA     CURSX           ;ZERO CURSOR X
        STA     CURSY           ;ZERO CURSOR Y
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP           ;BACK TO USART
        ;
        ;THIS ROUTINE CLEARS THE SCREEN BY WRITING END OF ROW
        ;CHARACTERS INTO THE FIRST LOCATION OF ALL LINES ON
        ;THE SCREEN.
        ;
CLSCR:  MVI     A,0F0H          ;PUT EOR CHARACTER IN A
        MVI     B,NUMLIN
        LXI     H,TOPDIS        ;LOAD H AND L WITH TOP OF RAM
        LXI     D,LINSIZ        ;LOAD LINE SIZE.
LOADX: MOV      M,A             ;MOVE EOR INTO MEMORY
        DAD     D               ;CHANGE POINTER BY BOD
        DCR     B               ;COUNT THE LOOPS
        JNZ     LOADX           ;CONTINUE IF NOT ZERO
        RET                     ;GO BACK
        ;
        ;THIS ROUTINE DOES A LINE FEED
        ;
LNFD:   CALL    LNFD1           ;CALL ROUTINE
        JMP     SETUP           ;POLL FLAGS
        ;
        ;LINE FEED
        ;
LNFD1:  LDA     CURSY           ;GET Y LOCATION OF CURSOR
        CPI     CURBOT          ;SEE IF AT BOTTOM OF SCREEN
        JZ      ONBOT           ;IF WE ARE, LEAVE
        INR     A               ;INCREMENT A
        STA     CURSY           ;SAVE NEW CURSOR
        CALL    CALCU           ;CALCULATE ADDRESS
        SHLD    L0C80           ;SAVE TO CLEAR LINE
        CALL    CLLINE          ;CLEAR THE LINE
        CALL    LDCUR           ;LOAD THE CURSOR
        RET                     ;LEAVE
        ;
        ;THIS ROUTINE CLEARS THE LINE WHOSE FIRST ADDRESS
        ;IS IN LOCBO.  PUSH INSTRUCTIONS ARE USED TO RAPIDLY
        ;CLEAR THE LINE
        ;
CLLINE: DI                      ;NO INTERRUPTS HERE
        LHLD    L0C80           ;GET LOCBO
        LXI     D,LINSIZ        ;GET OFFSET
        DAD     D               ;ADD OFFSET
        XCHG                    ;PUT START IN DE
        LXI     H,0000H         ;ZERO HL
        DAD     SP              ;GET STACK
        XCHG                    ;PUT STACK IN DE
        SPHL                    ;PUT START IN SP
        LXI     H,' '           ;PUT SPACES IN HL
        ;
        ; NOW DO 40 PUSH INSTRUCTIONS TO CLEAR THE LINE
        ;
        REPT    (LINSIZ/2)
        PUSH    H
        ENDM
        XCHG                    ;PUT STACK IN HL
        SPHL                    ;PUT IT BACK IN SP
        EI                      ;ENABLE INTERRUPTS
        RET                     ;GO BACK
        ;
        ;IF CURSOR IS ON THE BOTTOM OF THE SCREEN THIS ROUTINE
        ;IS USED TO IMPLEMENT THE LINE FEED
        ;
ONBOT:  LHLD    TOPAD           ;GET TOP ADDRESS
        SHLD    L0C80           ;SAVE IT IN LOCB0
        LXI     D,LINSIZ        ;LINE LENGTH
        DAD     D               ;ADD HL + DE
        XCHG
        LXI     H,-(LAST)
        DAD     D
        XCHG
        JNC     ARND
        LXI     H,TOPDIS        ;LOAD HL WITH TOP OF DISPLAY
ARND:   SHLD    TOPAD           ;SAVE NEW TOP ADDRESS '
        CALL    CLLINE          ;CLEAR LINE
        CALL    LDCUR           ;LOAD THE CURSOR
        RET
        ;
        ;THIS ROUTINE PUTS A CHARACTER ON THE SCREEN AND
        ;INCREMENTS THE X CURSOR POSITION.
        ;AUTO CR/LF MODE IS USED.
        ;
CHRPUT: CALL    CALCU           ;CALCULATE SCREEN POSITION
        MOV     A,M             ;GET'FIRST CHARACTER
        CPI     0F0H            ;IS IT A CLEAR LINE
        SHLD    L0C80           ;SAVIS'LINE TO CLEAR
        CZ      CLLINE          ;CLEAR LINE
        LHLD    L0C80           ;GET LINE
        CALL    ADX             ;ADD CURSOR X
        LDA     USCHR           ;GET CHARACTER
        MOV     M,A             ;PUT IT ON SCREEN
        LDA     CURSX           ;GET CURSOR X
        INR     A               ;INCREMENT CURSOR X
        CPI     LINSIZ          ;HAS IT GONE TOD FAR?
        JNZ     OKI             ;IF NOT GOOD
        CALL    LNFD1           ;DO A LINE FEED
        JMP     CORT            ;DO A CR
OKI:    STA     CURSX           ;SAVE CURSOR
        CALL    LDCUR           ;LOAD THE CURSOR
        JMP     SETUP           ;LEAVE
        ;
        ;THIS ROUTINE TAKES THE TOP ADDRESS AND THE Y CURSOR
        ;LOCATION AND CALCULATES THE ADDRESS OF THE LINE
        ;THAT THE CURSOR IS ON. THE RESULT IS RETURNED IN H
        ;AND L AND ALL REGISTERS ARE USED.
        ;
CALCU:  LHLD    CURSY           ;CALCULATE START ADDRESS OF CURRENT LINE.
        MVI     H,0
        DAD     H
        LXI     D,LINTAB
        DAD     D
        MOV     E,M
        INX     H
        MOV     D,M
        LHLD    TOPAD           ;GET CURRENT SCREEN START ADDRESS.
        DAD     D               ;ADD CURSOR OFFSET TO CURRENT LINE.
        XCHG                    ;SAVE.
        LXI     H,-LAST         ;CHECK FOR CURSOR WRAP-AROUND.
        DAD     D
        XCHG
        RNC                     ;RETURN IF NO WRAP.
        LXI     D, TOPDIS-LAST  ;OTHERWISE, CORRECT FOR WRAP.
        DAD     D
        RET
        ;
        ;THIS ROUTINE ADDS THE X CURSOR LOCATION TO THE ADDRESS 
        ;THAT IS IN THE H AND L REGISTERS AND RETURNS THE RESULT
        ;IN H AND L
        ;
ADX:    LDA     CURSX           ;GET CURSOR
        MVI     B,00H           ;ZERO B
        MOV     C,A             ;PUT CURSOR X IN C
        DAD     B               ;ADD CURSOR X TO H AND L
        RET                     ;LEAVE

        ;THIS ROUTINE READS THE BAUD RATE SWITCHES FROM PORT C
        ;OF THE 8255 AND LOOKS UP THe NUMBERS NEEDED TO LOAD
        ;THE 8253 TO PROVIDE THE PROPER BAUD RATE.
        ;
SIBAUD: LDA     PORTC           ;READ BAUD RATE SWITCHES
        ANI     111B
        LXI     H,BAUD
STB1:   MOV     M,A
        RLC                     ;MOVE BITS OVER ONE PLACE
        LXI     H,BDLK          ;GET BAUD RATE LOOK UP TABLE
        MVI     D,00H           ;ZERO D
        MOV     E,A             ;PUT A IN E
        DAD     D               ;GET OFFSET
        LXI     D,CNTM          ;POINT DE TO 8253
        MVI     A,0B6H          ;GET CONTROL    WORD
        STAX    D               ;STORE IN 8253
        DCX     D               ;POINT AT #2 COUNTER
        MOV     A,M             ;GET LSB BAUD RATE
        STAX    D               ;PUT IT IN 8253
        INX     H               ;POINT AT MSB BAUD RATE
        MOV     A,M             ;GET MSB BAUD RATE
        STAX    D               ;PUT IT IN 8253
        RET                     ;GO BACK

        ;THIS TABLE CONTAINS. THE OFFSET ADDRESSES FOR EACH
        ;OF THE 25 DISPLAYED LINES.
        ;
LINTAB: LINNUM SET 0
        REPT   (NUMLIN+1)
        DW     (LINSIZ*LINNUM)
        LINNUM SET (LINNUM+1)
        ENDM
        ;
        ;KEYBOARD LOOKUP TABLE
        ;THIS TABLE CONTAINS ALL THE ASCII CHARACTERS
        ;THAT ARE TRANSMITTED BY THE TERMINAL
        ;THE CHARACTERS ARE ORGANIZED SO THAT BITS 0,1 AND 2
        ;ARE THE SCAN LINES, BITS 3,4 AND 5 ARE THE RETURN LINES
        ;BIT 6 IS SHIFT AND BIT 7 IS CONTROL
        ;
KYLKUP: DB      38H,39H         ;8 AND  9
        DB      30H,2DH         ;0 AND  -
        DB      3DH,5CH         ;= AND  \
        DB      08H,00H         ;BS AND BREAK
        DB      75H,69H         ;LOWER CASE U AND I
        DB      6FH,70H         ;LOWER CASE 0 AND P
        DB      5BH,5CH         ;[ AND  \
        DB      0AH,7FH         ;LF AND DELETE
        DB      6AH,6BH         ;LOWER CASE J AND K
        DB      6CH,3BH         ;LOWER CASE L AND /
        DB      27H,00H         ;' AND NOTHING
        DB      0DH,37H         ;CR AND 7
        DB      6DH,2CH         ;LOWER CASE M AND COMMA
        DB      2EH,2FH         ;PERIOD AND SLASH
        DB      00H,00H         ;BLANK AND NOTHING
        DB      00H,00H         ;NOTHING AND NOTHING
        DB      00H,61H         ;NOTHING AND LOWER CASE A
        DB      7AH,78H         ;LOWER CASE Z AND X
        DB      63H,76H         ;LOWER CASE C AND V
        DB      62H,6EH         ;LOWER CASE B AND N
        DB      79H,00H         ;LOWER CASE Y AND NOTHING
        DB      00H,20H         ;NOTHING AND SPACE
        DB      64H,66H         ;LOWER CASE D AND F
        DB      67H,68H         ;LOWER CASE G AND H
        DB      00H,71H         ;TAB AND LOWER CASE Q
        DB      77H,73H         ;LOWER CASE W AND S
        DB      65H,72H         ;LOWER CASE E AND R
        DB      74H,00H         ;LOWER CASE T AND NOTHING
        DB      1BH,31H         ;ESCAPE AND 1
        DB      32H,33H         ;2 AND 3
        DB      34H,35H         ;4 AND 5
        DB      3SH,00H         ;6 AND NOTHING
        DB      2AH,28H         ;* AND )
        DB      29H,5FH         ;( AND -
        DB      2BH,00H         ;+ AND NOTHING
        DB      08H,00H         ;BS AND BREAK
        DB      55H,49H         ;U AND I
        DB      4FH,50H         ;0 AND P
        DB      5DH,00H         ;J AND NO CHARACTER
        DB      0AH,7FH         ;LF AND DELETE
        DB      4AH,4BH         ;J AND K
        DB      4CH,3AH         ;L AND :
        DB      22H,00H         ;" AND NO CHARACTER
        DB      0DH,26H         ;CR AND &
        DB      4DH,3CH         ;M AND <
        DB      3EH,3FH         ;> AND ?
        DB      00H,00H         ;BLANK AND NOTHING
        DB      00H,00H         ;NOTHING AND NOTHING
        DB      00H,41H         ;NOTHING AND A
        DB      5AH,5BH         ;Z AND X
        DB      43H,56H         ;C AND V
        DB      42H,4EH         ;B AND N
        DB      59H,00H         ;Y AND NOTHING
        DB      00H,20H         ;NO CHARACTER AND SPACE
        DB      44H,46H         ;D AND F
        DB      47H,4BH         ;G AND H
        DB      00H,51H         ;TAB AND Q
        DB      57H,53H         ;W AND S
        DB      45H,52H         ;E AND R
        DB      54H,00H         ;T AND NO CONNECTION
        DB      1BH,21H         ;ESCAPE AND !
        DB      40H,23H         ;@ AND #
        DB      24H, 25H        ;$ AND 7.
        DB      5EH,00H         ;" AND NO CONNECTION
        ;
        ;THIS IS WHERE THE CONTROL CHARACTERS ARE LOOKED UP
        ;
        DB      00H,00H         ;NOTHING
        DB      00H,00H         ;NOTHING
        DB      00H,00H         ;NOTHING
        DB      00H,00H         ;NOTHING
        DB      15H,09H         ;CONTROL U AND I
        DB      0FH,10H         ;CONTROL 0 AND P
        DB      0BH,0CH         ;CONTROL I AND \
        DB      0AH,7FH         ;LF AND DELETE
        DB      0AH,0BH         ;CONTROL J AND K
        DB      0CH,00H         ;CONTROL L AND NOTHING
        DB      00H,00H         ;NOTHING
        DB      0DH,00H         ;CR AND NOTHING
        DB      0DH,00H         ;CONTROL M AND COMMA
        DB      00H,00H         ;NOTHING
        DB      00H,00H         ;NOTHING
        DB      00H,00H         ;NOTHING AND NOTHING
        DB      1AH,1BH         ;CONTROL Z AND X
        DB      0SH,16H         ;CONTROL C AND V
        DB      02H,0EH         ;CONTROL B AND N
        DB      19H,00H         ;CONTROL Y AND NOTHING
        DB      00H,20H         ;NOTHING AND SPACE
        DB      04H,0AH         ;CONTROL D AND F
        DB      07H,0BH         ;CONTROL G AND H
        DB      00H,11H         ;NOTHING AND CONTROL Q
        DB      17H,13H         ;CONTROL W AND S
        DB      0AH,12H         ;CONTROL E AND R
        DB      14H,00H         ;CONTROL W AND NOTHING
        DB      1BH,1DH         ;ESCAPE AND HOME(CREDIT)
        DB      1EH,1CH         ;CURSOR UP AND DOWN(CREDIT)
        DB      14H,1FH         ;CURSOR RIGHT AND LEFT(CREDIT)
        DB      00H,00H         ;NOTHING
        ;
        ;LOOK UP TABLE FOR B253 BAUD RATE GENERATOR
        ;
BD110   SET     1B5H            ;8253 COUNT FOR 110 BAUD.
BD9600  EQU     000AH           ;8253 COUNT FOR 9600 BAUD.

SETBD   MACRO   COUNT
        DB      LOW COUNT
        DB      HIGH COUNT
        ENDM
                                ;S2   SI   SO   BAUD

BDLK:   SETBD   BD110           ;ON   ON   ON    110
        SETBD   (BD9600*64)     ;ON   ON   OFF   150
        SETBD   (BD9600*32)     ;ON   OFF  ON    300
        SETBD   (BD9600*16)     ;ON   OFF  OFF   600
        SETBD   (BD9600*8)      ;OFF  ON   ON   1200
        SETBD   (BD9600*4)      ;OFF  ON   OFF  2400
        SETBD   (BD9600*2)      ;OFF  OFF  ON   4800
        SETBD   (BD9600)        ;OFF  OFF  OFF  9600

        END