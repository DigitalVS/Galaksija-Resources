;--------------------------------------------------------
;
;  Galaksija - ROM B
;
;--------------------------------------------------------

SPACE = 90
SHOMEM = $2A97
SHOFOR = $2BB2
OPTION = $2BB3
FIELD = #2BB6 + 34
INS1 = FIELD + 5
INS2 = INS1 + 1
INS3 = INS2 + 3
IXIY = INS3 + 3
CODE = IXIY + 1
ADDR = CODE + 5
TEXTBR = ADDR + 2
TEMP1 = TEXTBR + 1
TEMP2 = TEMP1 + 2
KRUG = $2AAA  ; ASMPASSNO
FLAG2 = $2AAB
FREE = TEMP2 + 3
IXPOS2 = FREE + 2
DISPL = IXPOS2 + 2
FLAG = $2BB5 ; PRINTERFLAG

PLUS = $B32
MINUS = $B1E
PUTA = $AE6
KROZ = $AF7
CPIXIX = $B10

  .org $1000

  ld    hl, ($2A6A)             ; Ako je (ENDMEM) = 0 onda (ENDMEM) = $FFFF
  ld    a, h
  or    l
  jr    nz, NOT56K              ; ENDMEM > 0
  dec   hl                      ; Korigovani ENDMEM
  ld    ($2A6A), hl
NOT56K:
  ld    a, $0C
  jr    GOINI

ZALINK:                         ; Prepoznavanje BASIC komandi
  ex    (sp), hl
  push  de
  ld    de, $75B                ; To je pozicija na koju bi skočio ako nije prepoznao reč u BASIC programu
  rst   $10
  jr    nz, DRUGIP
  ld    hl, TEXT1 - 1           ; Tablica novih reči
  pop   de
CASE1:
  pop   af
  jp    $39A                    ; Prepoznaj novu reč, ako ne postoji u tablici...
KAO75B:
  jp    $75B                    ; ... skače na $75B

GOINI:
  rst   $20
  ld    a, $0C                  ; Nova horizontalna pozicija
  ld    ($2BA8), a
  ld    hl, LINKS               ; U linkove ubacuje JP umesto RET
  ld    de, $2BA9
  ld    bc, 6
  ldir                          ; Inicijalizacija ROM-A
  ret

DRUGIP:
  ld    de, $48E                ; Drugi pokušaj, da li je upravo prepoznata
  rst   $10                     ; reč 'PRINT'? Ako jeste, da li sledi 'Z'
  jr    nz, TRECIP
  pop   de
  ex    (sp), hl
  pop   af
  rst   $18
  db    '%'
  db    KAO48E-$-1
  rst   $8
  ld    a, ' '                  ; Piši blank
  rst   $20
  call  HEX16B                  ; Piši broj u HEX obliku
  jp    $4AD
KAO48E:
  jp    $48E                    ; Nastavlja gde je krenuo ako ne sledi '%'

TRECIP:
  ld    de, $777
  rst   $10                     ; Treći pokušaj. Da li je pokušao da prepozna
  pop   de                      ; funkciju, pa nije uspeo ($777 je adresa
  ex    (sp), hl                ; na koju bi skočio u tom slučaju
  ret   nz
  ld    hl, TEXT3 - 1           ; Tablica novih funkcija
  jr    CASE1                   ; Kraj je isti kao kod prvog pokušaja
KAO777:
  jp    $777

LPRINT:
  ld    bc, $480                ; LPRINT entry point. Ret adresa na PRINT
  push  bc                      ; ide na stack
COPY:
  ld    a, $FF                  ; Postavlja LPRINT flag
  ld    (FLAG), a
  ret

LLIST:
  call  COPY                    ; LLIST entry point. Postavi flag
  call  $CD3                    ; dalje kao LLIST
  jp    $464

VIDEO:
  push  af                      ; Dodatak potprogramu koji upisuje znak u
  ld    hl, (FLAG)              ; video mem ($95B, ROM-A)
  inc   l                       ; Da li je flag za printer postavljen?
  jr    nz, NCOPY               ; Ako nije izađi
  ld    hl, $2AAB               ; Da li je postavljen flag da se ne menja
  bit   0, (hl)                 ; čćžš u cczs?
  jr    nz, STAND				        ; Ako jeste, preskoči izmenu karaktera
  ld    hl, TABCZS				      ; Ako nije, pointer na tablicu
  ld	  b, 4				            ; Ukupno 4 slova za komparaciju
TEST4:
  cp	  (hl)				            ; Da li je traženo slovo?
  inc   hl
  jr	  z, FOUND4		        		; Jeste, skoči
  inc	  hl
  djnz  TEST4					          ; Pokušaj sledeće
  db    $26						          ; Kao 'LD H, $7E' - da bi ekonomično
FOUND4:
  ld	  a, (hl)                 ; preskočio sledeće slovo
STAND:
  push  af                      ; Sačuvaj novo slovo
RDY:
  call  $2FF                    ; BREAK test
  in    a, (255)
  rla
  jr    c, RDY                  ; Skoči ako je printer zauzet
  pop   af
  out   (255), a                ; Printer je slobodan - dakle pošalji mu znak
NCOPY:
  pop   af
  ret

TABCZS:
  db    91, 'C', 92, 'C', 93, 'Z', 94, 'S' ; Č, Ć, Ž, Š

LINKS:
  db    $C3
  dw    ZALINK
  db    $C3
  dw    VIDEO

GOASS:
  ld    hl, ($2A9F)             ; ********* ASSEMBLER *********
  ld    a, h                    ; Da li je komandni način rada
  or    l
  jp    z, $65A                 ; Ako jeste
  ex    de, hl                  ; Glavni pointer biće HL
  ld    a, 1                    ; Postavi OPT 1
  ld    (OPTION), a
  call  START1                  ; Pozovi program za asembliranje
  ld    ix, $2AAC               ; Vrati korektnu vrednost IX registru
  dec   hl
  ex    de, hl                  ; Vrati pointer DE
  rst   $30                     ; Idi danje na BASIC

START1:
  xor   a
  ld    (KRUG), a               ; Prvi krug asembliranja
  ld    (INS1), a               ; Izbriši opcode token
  ex    de, hl                  ; Sačuvaj HL u DE
  rst   $28                     ; To je LD HL, 0
  ld    (DISPL), hl
  ld    (SHOMEM), hl            ; Za 'REG': pokazuje 0 bajta memorije
  ld    hl, ($2A6A)             ; = ENDMEM
  dec   hl
  ld    (hl), a                 ; 0 = terminator tablice za labele
  dec   hl
  ld    (hl), a
  ex    de, hl                  ; Vrati HL
  call  FINDCR                  ; Nađi kraj linije u kojoj je '<'
  push  hl                      ; Čuva pointer za drugi krug
  call  ASS                     ; Prvi krug asembliranja
  ld    hl, KRUG
  inc   (hl)                    ; Postavi drugi krug
  xor   a
  ld    (INS1), a               ; Izbriši opcode
  pop   hl                      ; Vrati pointer na početak i
ASS:
  xor   a                       ; kreni u drugi krug
  ld    (TEXTBR), a             ; 0 slova u text-u
  ld    (ADDR), a               ; Briše adresu labele u programu
  ld    (ADDR + 1), a
LOOP:                           ; Sledećiš 13 linija su glavna petlja
  ld    ($2A9F), hl             ; Pozicija tekuće linije (za slučaj greške)
  ld    de, ($2C38)             ; Kraj BASIC-a
  rst   $10
  ret   nc                      ; Vrati se ako je kraj a nema '>'
  ld    a, (INS1)
  cp    8
  ret   z                       ; Vrati se ako je '>'
  call  $2FF                    ; BREAK test
  call  PROG1                   ; Prvi deo: stavljanje tokena u tablicu
  push  hl
  call  PROG2                   ; Drugi deo: formiranje koda
  pop   hl
  jr    LOOP                    ; Nazad na glavnu petlju

PROG2:
  ld    hl, GOON                ; Ovo je ret adresa za kraj podprograma
  push  hl
  ld    hl, INS2
  ld    ix, FIELD + 3
  ld    a, (INS1)
  or    a
  ret   z                       ; Nema ništa u ovoj liniji - idi na GOON
  cp    9                       ; Da li je specijalna reč (token < 9)
  jp    nc, NCOMM               ; Nije - dakle reč za asembliranje
  dec   a
  jr    nz, NSTAT               ; Nije token 1
  ld    hl, BRKPT               ; Token 1: 'REG' (breakpoint)
  ld    (CODE + 1), hl          ; Breakpoint adresa
  ld    a, $CD                  ; Code za 'CALL'
  ld    (CODE), a
  ld    a, 3
  ld    (CODE + 4), a           ; 3 bajta kodirana dužina
  ld    hl, (INS2 + 1)          ; Ima li pokazivanja memorije?
  ld    a, h
  or    l
  ret   z                       ; Nema - idi na GOON
  call  IFNUM2                  ; Da li je numerička vrednost (ako nije - WHAT?)
  ld    (SHOMEM), hl            ; Pokaži HL memoriju
  ld    a, (INS3 + 1)           ; Koliko redova?
  or    a
  jr    nz, IMA                 ; Navedeno je koliko redova
  inc   a                       ; Nije navedeno - dakle 1 red
IMA:
  ld    (SHOFOR), a             ; = show format
  ret

NSTAT:
  dec   a
  jr    nz, NTEXT               ; Nije token 2
  ld    a, (hl)                 ; Token 2: 'TEXT'
  ld    (TEXTBR), a             ; Broj slova teksta
  ld    de, CODE
TEXTIT:
  ld    b, 3                    ; Po 3 bajta u jednom redu
TXT4:
  ld    a, (TEXTBR)             ; Koliko još slova je ostalo?
  or    a                       ; Ima li još slova?
  ret   z                       ; Nema - idi na GOON
  dec   (ix + 17)               ; Umanji brojač slova
  ld    hl, (INS2 + 1)          ; Adresa teksta u programu
  ld    a, (hl)                 ; Uzmi slovo ili znak
  inc   hl                      ; Uvećaj pointer
  ld    (INS2 + 1), hl          ; I vrati ga
  ld    (de), a                 ; Stavi znak u CODE
  inc   de                      ; Uvećaj CODE pointer
  inc   (ix + 14)               ; Uvećaj broj bajtova
  djnz  TXT4                    ; Sve to uradi 3 puta u svakom redu
  ret                           ; Idi na GOON
NTEXT:
  dec   a
  jr    nz, NWORD               ; Nije token 3
  inc   a                       ; Token 3: 'WORD'
  ld    (ix + 14), a            ; Brojač bajtova = 1 (na IXGOON će biti +1)
NWORD:
  dec   a
  jr    nz, NBYTE               ; Nije token 4 ili 3
  call  IFNUM1                  ; Token 4: 'BYTE'
  ld    hl, (INS2 + 1)          ; Uzmi CODE
  ld    (CODE), hl              ; Stavi ga na svoje mesto
  jp    IXGOON

NBYTE:
  dec   a
  jr    nz, NOPT                ; Nije token 5
  call  IFNUM2                  ; Token 5: 'OPT' (ako je >255, WHAT)
  ld    hl, (INS2 + 1)          ; Uzmi broj opcije
  ld    a, l                    ; U A reg
  and   4                       ; Ako je bit 2 postavljen (4-5-6-7)
  call  nz, COPY                ; Postavi flag za printer
  ld    a, l
  and   3
  ld    (OPTION), a             ; Maskiraj da bude manje od 4
  ld    a, (INS3)
  or    a                       ; Da li se traži relociranje pri upisu?
  ret   z                       ; Ne - idi na GOON
  cp    $40
  jp    nz, WHATHL              ; Nije numerik - greška
  ld    hl, (INS3 + 1)          ; Veličina relociranja
  ld    (DISPL), hl             ; na svoje mesto
  ret

NOPT:
  dec   a
  jr    nz, NORG                ; Nije token 6
  call  IFNUM1                  ; Token 6: 'ORG'
  ld    hl, (INS2 + 1)
  ld    (TEMP1), hl             ; Privremena adresa
SKR4:
  ld    (ADDR), hl              ; Glavni pointer adrese PC
  ret

NORG:
  dec   a
  ret   nz                      ; End = token 8 '>'
  call  IFNUM1                  ; Token 7: 'EQU'
  ld    bc, (INS2 + 1)
  ld    (TEMP1), bc             ; Adresa labele
  call  CREATE                  ; Formiraj labelu
  jp    z, WHATHL               ; Ako nije naveden - WHAT?
  pop   af                      ; Vrati stack - neće ići na GOON
  jp    GOON1                   ; Nego na GOON1

CREATE:
  ld    a, (KRUG)               ; ---- Formiranje labele ----
  or    a
  ret   nz                      ; Ne može da se formira u drugom krugu
  ld    hl, (FIELD + 2)
  ld    a, h
  or    l
  ret   z                       ; Vrati se ako ne postoji adresa labele
  call  LOCAT2                  ; Pogredaj da li je ista već formirana
  jp    z, HOWHL                ; Ako već postoji - ne može dvaput (HOW?)
TRANSF:
  push  hl
  ld    hl, ($2C38)             ; Kraj BASIC programa
  rst   $10
  pop   hl
  jp    nc, $153                ; SORRY - no memory
  ld    a, (hl)
  ld    (de), a                 ; Prenesi slovo po slovo u tablicu
  inc   hl
  dec   de
  call  NCSLBR                  ; Ako je slovo ili broj
  jr    nc, TRANSF              ; nastavi sa prenosom
NOTRAN:
  ex    de, hl
  inc   hl
  set   7, (hl)                 ; Terminator reči = bit 7 set
  dec   hl
  ld    (hl), b                 ; BC = vrednost labele
  dec   hl
  ld    (hl), c
  dec   hl
  ld    (hl), 0                 ; Terminator tablice
  ex    de, hl                  ; HL = pointer sada je iza imena
  xor   a                       ; Reset Z flag (znak da je svo OK)
  inc   a                       ; DE = nova pozicija u tabeli
  ret

LOCATE:
  ld    a, (KRUG)               ; ---- Lociraj labelu ----
  or    a
  jr    nz, LOCAT2              ; Samo u drugom krugu
  dec   hl                      ; A u 1. krugu samo preskoči ime
SRC20H:
  inc   hl
  call  NCSLBR
  jr    nc, SRC20H
  xor   a
  ld    b, a
  ld    c, a
  ret

LOCAT2:
  push  hl
  exx
  ld    hl, ($2A6A)             ; Kraj memorije (počinje komparaciju)
  dec   hl
  jr    IFFIR                   ; Počni
GOSRCH:
  pop   de                      ; Rekonstruiši pointer
  push  de
GOSRC2:
  ld    a, (de)                 ; Uzmi iz teksta programa
  cp    (hl)                    ; Pa ga uporedi sa spiskom labela
  jr    z, FOUNDV               ; Jedno slovo odgovara
  or    $80                     ; Set bit 7 (kao na poslednjem znaku)
  cp    (hl)                    ; P a opet uporedi (možda je kraj?)
  jr    z, BASFOU               ; Jest - uspelo poređenje
SRCHV:
  bit   7, (hl)                 ; Nije - nađi kraj tog imena u spisku
  dec   hl
  jr    z, SRCHV                ; Nije još kraj
  dec   hl                      ; Preskoči vrednost u spisku
  dec   hl                      ; Još jedan bajt
IFFIR:
  ld    a, (hl)                 ; Sledeće ime (prvi znak)
  or    a                       ; Možda je nula (terminator tablice)?
  jr    nz, GOSRCH              ; Nije - nastavi pređenje
  push  hl                      ; Prebaci HL u DE
  exx                           ; alternativnog seta
  pop   de                      ; DE = nova pozicija u tablici
  pop   hl                      ; Rekonstruiši HL
  inc   a                       ; A=1 (znak da nije dađeno ime)
  ret
FOUNDV:
  dec   hl                      ; Poređenje teče dobro
  inc   de                      ; Idemo na novi znak
  jr    GOSRC2                  ; Nastavi poređenje
BASFOU:
  inc   de                      ; Idi na novi znak u programu
  ex    de, hl
  call  NCSLBR                  ; Ako je slovo ili broj, reset C flag
  ex    de, hl
  jr    nc, SRCHV               ; Dakle reč je duža - nije uspelo poređenje
  dec   hl                      ; Potpuno je uspelo poređenje, idi na vrednost
  ld    b, (hl)                 ; Visoki bajt
  dec   hl
  ld    c, (hl)                 ; BC = vrednost
  ex    de, hl                  ; HL = pointer iza imena
  pop   de                      ; DE = stari pointer
  xor   a                       ; A = 0 (znak da je pronađeno ime u spisku)
  ret

GOON:
  ld    bc, (ADDR)              ; ---- Kraj obrade jednog reda ----
  call  CREATE                  ; Formiraj novu labelu ako postoji
GOON1:
  ld    de, IXIY                ; DE point na IXIY flag u RAM-u
  ld    a, (de)
  or    a                       ; Ima li tu nečega?
  jr    nz, IMAGA               ; Skoči ako se instrukcija odnosi na IX ili IY
  ld    hl, CODE                ; Ako ne - pomeri kod za jedno mesto naniže
  ld    bc, 4
  ldir
  ld    (de), a                 ; A u poslednji bajt smesti nulu
  jr    PRES1
IMAGA:
  cp    $ED                     ; Da li je to $ED?
  jr    z, PRES1                ; Ako jest - to onda nije ni IX ni IY
  ld    hl, FIELD + 17          ; HL point na broj bajta koda
  inc   (hl)                    ; Uvećaj ga
  ld    a, (IX + 3)
  cp    $86                     ; Da li je operand 1?
  jr    z, F1                   ; IX u zagradi?
  ld    a, (ix + 6)             ; Ako jeste - skoči
  cp    $86                     ; Ili možda operand 2?
F1:
  call  z, EXTRA                ; IX u zagradi?
PRES1:
  ld    b, (ix + 14)
  inc   b
  dec   b                       ; Pa ako je nula, preskoči
  jp    z, NEMABY
  ld    hl, (ADDR)              ; Uzmi programski brojač
  call  HEX16                   ; Napiši vrednost
  ld    a, ' '
  call  ZAPRIN
PRVIK1:
  ld    de, IXIY
PUTABY:
  ld    a, (KRUG)
  or    a                       ; Koji je ovo krug asembliranja?
  jr    z, PRVIK                ; Ako je prvi - preskoči
  push  bc
  ld    b, l                    ; B = niski bajt programskog brojača
  ld    c, 253                  ; Izlazna adresa za visoki bajt
  out   (c), h                  ; Visoki bajt ide u latch emulatora
  inc   c                       ; Nova izlazna adresa
  ld    a, (OPTION)
  and   2
  ld    a, (de)                 ; Uzmi bajt koda
  out   (c), a                  ; Napolje u emulator
  pop   bc
  jr    z, NOWR                 ; Ako je izabrana opcija ne traži upis u memoriju - preskoči
  push  hl
  push  de
  ld    de, (DISPL)             ; Ima li relokacije upisa?
  add   hl, de                  ; Dodaj relokacionu vrednost
  ld    (hl), a                 ; ***** Upis bajta u memoriju *****
  pop   de
  pop   hl
NOWR:
  call  HEX8                    ; Štampaj bajt na ekranu
  inc   de
PRVIK:
  inc   hl                      ; Uvećaj pointere
  djnz  PUTABY                  ; Vrati se onoliko puta koliko imaš bajta
  ld    (ADDR), hl              ; Nova adresa programskog brojača
  ld    a, (TEXTBR)             ; Ima li kodiranog teksta?
  or    a
  jr    z, NEMAB1               ; Ako nema - skoči
  ld    a, $0D                  ; Ima - novi red
  call  ZAPRIN
  ld    (ix + 14), 0            ; Broj bajta = 0
  ld    de, CODE - 1            ; Uzmi nova 3 bajta teksta
  call  TEXTIT
  jr    PRES1                   ; Nastavi ako se radi o tekstu
NEMAB1:
  ld    a, (KRUG)
  or    a
  ret   z                       ; Vrati se ako je prvi krug
  ld    a, (OPTION)
  rra
  ret   nc                      ; Vrati se ako se ne traži štampanje
GOBL:
  ld    a, ($2A68)              ; Pozicija kursora
  and   $1F                     ; Uzmi samo poziciju u redu
  cp    $0B                     ; Da li je manja od 11?
  jr    nc, VEC11               ; Nije - skoči
  ld    a, $20                  ; Blank
  rst   $20
  jr    GOBL                    ; Piši blankove dok ne dođeš do TAB(11)
VEC11:
  ld    de, ($2A9F)             ; Uzmi poziciju tekuće linije
  call  RELIX1                  ; Pripremi IX za aritmetiku
  ld    a, (OPTION)             ; Koja opcija?
  rra
  jr    nc, RELIX2              ; Ako nije print na ekran
  call  $8ED                    ; Piši broj programske linije
  ld    a, (FIELD + 3)          ; Da li postoji labela?
  or    a
  jr    nz, UVUCI               ; Postoji - ostavi kursor gde je
  ld    a, ' '
  rst   $20
  rst   $20
UVUCI:
  call  $934                    ; Napiši tekst programske linije
RELIX2:
  ld    ix, (IXPOS2)            ; Vrati stari IX
  ret
NEMABY:
  ld    hl, (TEMP1)             ; Samo programski brojač
  call  HEX16                   ; Napiši ga
  jr    NEMAB1                  ; I napiši broj i tekst linije

IFNUM1:
  call  TEST3                   ; ** Ako postoji drugi operand
IFNUM2:
  ld    a, (INS2)               ; ili prvi nije numerički
  cp    $40                     ; Onda WHAT?
  ret   z                       ; ** Ako prvi operand nije
ZASN:
  jp    WHATHL                  ; numerički - onda WHAT?

NCOMM:
  dec   a
  ld    c, a                    ; Vidi da li je prosta instrukcija
  cp    $2A                     ; (grupa 2) ili je ED+ (grupa 3)
  jp    nc, CBPLUS              ; Ako nije ni jedno ni drugo, idi dalje
  ld    b, 6                    ; Testiraj 6 bajta
  xor   a                       ; U grupi 'INS2' i 'INS3'
XX6:
  or    (hl)
  inc   hl
  djnz  XX6                     ; Ako postoji bolo koji operand
  jr    nz, ZASN                ; Onda idi na WHAT?
  ld    a, c
  cp    $15                     ; Da li je ED+
  jr    c, NOED                 ; Ako nije - skoči
  ld    (ix + 9), $ED           ; Smesti ED
  inc   (ix + 14)               ; I uvećaj broj bajta
NOED:
  ld    hl, TABY1 - 8           ; Nađi kodirani bajt u tablici
  add   hl, bc                  ; sabiranjem
  ld    a, (hl)                 ; Uzmi ga iz tablice
  ld    (ix + 10), a            ; I smesti na svoje mesto
IXGOON:
  inc   (ix + 14)               ; Uvećaj broj bajta
  ret

HEX16B:
  ld    a, '&'                  ; ***** Piši u hex obliku HL bezuslovno
  rst   $20                     ; Prvo piši znak '&' za hex broj
  ld    a, 1                    ; Postavi uslove štampanja
  ld    (OPTION), a
  ld    (KRUG), a
HEX16:
  ld    a, h                    ; ***** Piši u hex obliku HL uslovno
  call  HEX8                    ; Prvo visoki bajt
HEX8L:
  ld    a, l                    ; ***** Piši u hex obliku L uslovno
HEX8:
  ld    c, a                    ; ***** Piši u heh obliku A uslovno
  and   $F0                     ; Maskiraj gornja 4 bita
  call  RLC4                    ; Rotiranjem ih smesti na donja 4
  call  HCONV                   ; Konvertuj u hex cifru (0-9; A-F) i piši
  ld    a, c
  and   $0F                     ; Pa isto to sa donja 4 bita
HCONV:
  add   a, $30                  ; Podesi ASCII cifru
  cp    $3A                     ; Iznad 9?
  jr    c, ZAPRIN               ; Nije - skoči
  add   a, 7                    ; Ako jeste, dodaj 7 (za A-F)
ZAPRIN:
  push  af
  ld    a, (KRUG)               ; Testiraj prvi uslov
  or    a                       ; Koji je krug?
  jr    z, RETK1                ; Ako je prvi - ne radi dalje
  ld    a, (OPTION)             ; Testiraj drugi uslov
  rra                           ; Koja je opcija?
  jr    c, NORET1               ; Ako se traži štampanje - skoči
RETK1:
  pop   af
  ret
NORET1:
  pop   af
  rst   $20                     ; Napiši znak na ekranu
  ret                           ; Eventualno na štampaču

CBPLUS:
  call  IXIYHL                  ; Svedi IX ili IY slučaj na HL
  ld    a, c
  ld    b, 0
  cp    $34                     ; Da li je grupa 4 (CB+)?
  jp    nc, GRUPA5              ; Ako nije idi dalje
  ld    hl, TAB4 - $2A          ; Jeste - point na tablicu
  add   hl, bc                  ; Sračunaj poziciju
  ld    b, (hl)                 ; Uzmi kod
  ld    (ix + 10), $CB          ; Prvi bajt: CB
  ld    (ix + 11), b            ; Drugi bajt: iz tablice
  ld    (ix + 14), 2            ; Broj bajtova: 2
  ld    hl, INS3
  cp    $31                     ; Neke od CB+ instrukcija nemaju numeričko polje
  jr    c, NOBIT
  call  ZAINS2                  ; Uzmi numeričko polje uz sve testove
  cp    8                       ; Za bit/set/res, ako je bit > 7
  jp    nc, HOWHL               ; Onda je greška
  rlca                          ; Rotiraj broj bita u svoje polje
  rlca
  rlca
  or    (ix + 11)               ; I utisni ga u kod
  ld    (ix + 11), a
  jr    RHLIXY                  ; Vidi o kom registru se radi

NOBIT:
  ld    a, (hl)
  or    a                       ; Rekli smo da nema numeričkog polja
WHATNZ:
  jp    nz, WHATHL              ; a ovde ga ima, dakle greška
  ld    hl, INS2                ; Koji je registar (BCDEHL(HL)a)
RHLIXY:
  call  KOJR2
SKRLD:
  or    (ix + 11)               ; Utisni ga u kod
  ld    (ix + 11), a
  inc   hl
  ld    l, (hl)
  ld    a, (IXIY)
  or    a                       ; Da li je to svedeni IX/IY slučaj?
  ret   z                       ; Nije - vrati se
  ld    h, (ix + 11)            ; Jeste - onda 2-bajtni kod
ZAGOHL:
  ld    (CODE + 1), hl
  ret

GRUPA5:
  cp    $3C                     ; Da li je grupa 5 (aritmetička grupa)
  ld    (ix + 14), 1
  jp    nc, GRUPA6              ; Nije - idi dalje
  ld    hl, TAB5 - $34          ; Tablica grupe 5
  add   hl, bc                  ; Sračunaj poziciju koda u tablici
  ld    e, (hl)                 ; Uzmi kod u E registar
  ld    hl, INS2
  ld    a, (HL)
  cp    6                       ; Da li je to HL u zagradi?
  jr    z, HL16                 ; Jeste - onda posebna obrada
  ld    a, (INS3)
  or    a                       ; Da li postoji drugi operand?
  jr    z, PRESK3               ; Ne - preskoči njegovu obradu
  ld    a, (hl)                 ; Da - onda koji je prvi operand?
  cp    $0E                     ; Da li je 'A'?
  jr    nz, WHATNZ              ; Ako nije - greška
  ld    hl, INS3                ; Point na oper 3
PRESK3:
  ld    a, (hl)
  cp    $40                     ; Numerik bez zagrade?
  jr    z, NUMLOG               ; Da - posebna obrada
  call  KOJR2                   ; Koji registar?
  or    e                       ; Utisni u kod
ADJUST:
  inc   hl
ADJ1:
  ld    (ix + 10), a            ; Prvi bajt koda
  ld    a, (hl)
  ld    (ix + 11), a            ; Drugi bajt koda
  ret

SUB:
  inc   (ix + 14)               ; Uvećaj broj bajtova
  inc   hl
  inc   hl                      ; HL point a visoki bajt numerike
  ld    a, (KRUG)
  or    a                       ; Koji krug?
  jr    z, NEU1                 ; Prvi - onda ne testiraj da li je greška
  ld    a, (hl)
  or    a
  jp    nz, HOWHL               ; Veći od 255, dakle overflow
NEU1:
  dec   hl                      ; Point na niski bajt
  ret

NUMLOG:
  call  SUB                     ; Overflow test
  ld    a, e
  or    $46                     ; Preradi kod
  jr    ADJ1                    ; Smesti ga na mesto za kodove

PARREG:
  ld    e, 1                    ; ***** Testira koji je registar ili *****
  call  RTEST                   ; par registara i formira mikrokod
  jr    nc, RLC3                ; NC znači da je 8-bitni registar
  inc   e                       ; Ovde je 16-bitni par
KOJPAR:
  ld    a, (hl)
KOP1:
  cp    8                       ; Preko 7 su 8-bitni registri
  jr    nc, WHATNC              ; Pa je to greška
  sub   4                       ; Ispod 4 su IX/IY/AF
  jr    c, SKWHAT               ; A sa njima se ne rade aritmetičke operacije
RLC4:
  rlca
RLC3:
  rlca
  rlca
  rlca
  ret

HL16:
  ld    a, c                    ; 16-bitne operacije sa HL registrom
  cp    $37                     ; Da li je 'SUB' instrukcija?
WHATNC:
  jr    nc, SKWHAT              ; Da - ali takva ne može za 16-bitne reg.
  ld    hl, CODE
  cp    $34                     ; Da li je 'ADD' instrukcija?
  jr    z, ADDINS               ; Da - preskoči dodavanje jednog bajta
  ld    a, (IXIY)
  or    a                       ; Ima li IX/IY svođenja?
  jr    nz, SKWHAT              ; Da - nedozvoljeno
  ld    (hl), $ED               ; Dodaj ED+
  inc   hl
  inc   (ix + 14)               ; Uvećaj broj bajtova
ADDINS:
  push  hl
  ld    hl, INS3                ; U drugom operandu
  call  KOJPAR                  ; Koji registarski par
  ld    hl, TAB6 - $34
  add   hl, bc                  ; Sračunaj mikrokod
  or    (hl)                    ; I utisni ga u kod
  pop   hl
  ld    (hl), a                 ; Stavi na mesto za kodove
  ret

GRUPA6:
  cp    $3E                     ; Da li je grupa 6 (INC/DEC)
  jr    nc, GRUPA7              ; Ne - idi dalje
  call  IF3SN                   ; Ako ima oper. 2 onda WHAT?
  call  PARREG                  ; Koji registar ili par registara?
  ld    d, a
  ld    a, c
  dec   e                       ; E = broj bita/8, E = 2 za 16-bitne
  jr    z, BYTE1                ; Bilo je E = 1, dakle 8-bitni
  cp    $3C                     ; $3C = 'INC'
  jr    z, INCJE1               ; Preskoči 'DEC' obradu
  ld    a, $0B                  ; 'DEC' mikrokod
  db    $21                     ; LD HL,NN, preskače dva bajta
INCJE1:
  ld    a, 3                    ; 3 = 'DEC'
  or    d                       ; Utiskuje u mikrokod
CODRET:
  ld    (CODE), a
  ret

BYTE1:
  cp    $3C                     ; $3C = 'INC' token
  jr    z, INCJE                ; Preskoči 'DEC' obradu
  ld    a, 5                    ; 5 = 'DEC' mikrokod
  db    $21                     ; LD HL, NN, preskače dva bajta
INCJE:
  ld    a, 4                    ; 4 = 'INC' mikrokod
  or    d
  ld    hl, INS2
  jp    ADJUST                  ; Stavi na mesto za kodove

IF3SN:
  ld    hl, INS2
TEST3:
  ld    a, (INS3)               ; Ako postoji drugi operand
  or    a
  ret   z
SKWHAT:
  jp    WHATHL                  ; Onda idi na WHAT?

GRUPA7:
  cp    $3F                     ; Grupa 7 (LD/EX)
  jp    z, EXJE                 ; Ako je $3F (EX) skoči
  jp    nc, GRUPA8              ; Ako je >$3F idi dalje
  ld    b, 11                   ; 11 slučajeva za testiranje
  ld    hl, TESTAB              ; 'LD' tablica
  call  TEST                    ; Nađi koincidentni slučaj
  jr    nz, NFOU1               ; Nije specijalni slučaj - skoči
  cp    3                       ; Da li je LD A, (NN) ili LD (NN), A ?
  jr    nc, NOTNN               ; Ni jedno, ni drugo - skoči
  ld    hl, INS2 + 1            ; Uzmi OPER1
  dec   a
  jr    z, NNA                  ; Ostaje OPER1 jer je LD (NN)
  ld    hl, INS3 + 1            ; OPER2
NNA:
  ld    (ix + 14), 3            ; 3 bajta dužina instrukcije
  ld    a, (hl)
  ld    (CODE + 1), a           ; Niski bajt numeričkog polja NN
  inc   hl
  ld    a, (hl)
  ld    (CODE + 2), a           ; Visoki bajt
CODEB:
  ld    (ix + 10), b            ; $32 ili $3A (LD (NN), A ili LD A, (NN))
  ret

NOTNN:
  cp    8                       ; Da li je LD A,I/I,A/A,R/R,A
  ld    hl, CODE
  jr    c, SIMPLE               ; Nije nijedna
  ld    (hl), $ED               ; Prvi bajt koda je $ED
  inc   hl
  inc   (ix + 14)               ; Broj bajtova = 1
SIMPLE:
  ld    (hl), b                 ; kid
  ret

NFOU1:
  ld    hl, INS2                ; LOAD R,R/R,N/RR,NN
  call  RTEST                   ; Prvi registar
  jr    c, BYTE2                ; 16-bitni
  rlca                          ; 8-bitni
  rlca
  rlca
  ld    e, a                    ; Mikrokod u E registar
  ld    hl, INS3
  ld    a, (hl)
  cp    $40
  jr    z, NUMLD                ; Numerički 8-bitni load
  call  KOJR2                   ; Drugi registar
  or    e
  cp    $36                     ; Ako je LD (HL),(HL) to je greška
  jr    z, SKWHAT
  or    $40                     ; Set bit 6
  ld    (CODE), a
  ld    a, (INS3 + 1)
  or    (ix + 4)
  ld    (CODE + 1), a
  ret

NUMLD:
  ld    a, e
  or    6                       ; Set bit 5 i bit 6 mikrokoda
  ld    (CODE), a
  call  SUB                     ; Uvećaj broj bajtova i WHAT test
  ld    a, (hl)
  ld    hl, INS2
  jp    SKRLD                   ; Uradi kodove

BYTE2:
  ld    (ix + 14), 3            ; 16-bitni load, to su 3 bajta
  ld    de, INS3
  ld    a, (de)
  cp    $40                     ; Numerički load bez zagrade?
  jr    z, DDNN                 ; Da - skoči
  ld    b, 8                    ; Mikrokod
  cp    $C0                     ; Da li se odnosi na HL?
  jr    z, OSTAJE               ; Da - ostaju 3 bajta
  ld    a, (hl)                 ; Da li je drugi operand HL?
  cp    $C0
  jr    z, OSTAJ2               ; Da - ostaju 3 bajta
  cp    7                       ; Da li se odnosi na SP?
  jr    nz, WHL2                ; Ne - onda je greška
  ld    a, (de)                 ; Da li je LD SP
  cp    6
WHL2:
  jr    nz, NZWHAT              ; WHAT?
OSTAJ2:
  ex    de, hl
  ld    b, 0                    ; Mikrokod = 0
OSTAJE:
  call  KOJPAR                  ; Pronađi par registara
  or    2                       ; Formiraj kod
  or    b
  ld    b, a
  and   $30
  cp    $20
  ld    a, b
  jr    z, IPAKHL               ; Uzmi 3-bajtni slučaj
  ld    (ix + 9), $ED           ; Prvi bajt je $ED
  inc   (ix + 14)               ; 4-bajtna instrukcija
  or    $41                     ; Preuredi kod
IPAKHL:
  ld    (CODE), a
  ex    de, hl
  inc   hl
  ld    e, (hl)                 ; Niski bajt koda
  inc   hl
  ld    d, (hl)                 ; Visoki bajt koda
  ex    de, hl
  jp    ZAGOHL                  ; Smesti 2 bajta koda na mesto

DDNN:
  call  KOJPAR                  ; Slučaj LD DD
  inc   a                       ; Numerički 16-bitni load
  jr    IPAKHL

EXJE:
  ld    a, (INS2)               ; 'EX' grupa
  call  IFIXIY
  ld    hl, TEST2               ; Nema exchange kod IX i IY
  ld    b, 3                    ; 'EX' tablica od 3 člana
  call  TEST
NZWHAT:
  jp    nz, WHATHL
  jp    CODEB                   ; Nije nađeno - greška

TEST:
  ld    a, (INS2)               ; Uzmi operand 1
  cp    (hl)                    ; Uporedi sa tablicom
  inc   hl
  jr    nz, FAIL1               ; Nije nađena koincidencija
  ld    a, (INS3)               ; Možda oper 2?
  cp    (hl)
  jr    z, MATCH                ; Nađena koincidencija
FAIL1:
  inc   hl
  inc   hl
  djnz  TEST                    ; Pokušaj B puta
  ret
MATCH:
  inc   hl
  ld    a, b                    ; Uzmi broj (N-broj pokušaja)
  ld    b, (hl)                 ; Uzmi mikrokod
  ret

GRUPA8:
  ld    hl, INS2
  ld    de, INS3
  ld    bc, WHATHL
  push  bc                      ; Ubuduće 'RET' znači 'idi na WHAT?'
  ld    bc, 1                   ; Da li je 'OUT' token?
  cp    $41
  jr    z, OUTJE                ; Da - skoči
  jr    nc, GRUPA9              ; Ako je >$41, idi dalje
  ex    de, hl
  ld    bc, $800
OUTJE:
  bit   7, (hl)
  ret   z                       ; Ako nije u zagradi
  bit   6, (hl)
  jr    z, NIJENN               ; Nije numerički 'IN'
  inc   hl
  inc   hl
  ld    a, (hl)
  or    a
  ret   nz                      ; Ako postoji numerik na mestu OPER2
  dec   hl
  ld    a, (hl)
  ld    (CODE + 1), a           ; Numerička vrednost na mesto 2. bajta
  ld    a, (de)
  cp    $0E                     ; Da li je A registar?
  ret   nz                      ; Nije - greška
  ld    a, $D3                  ; Mikrokod za A registar
  or    b
  jr    CONTNN
NIJENN:
  ld    a, (hl)                 ; Da li je registar u zagradi C?
  cp    $89
  ret   nz                      ; Nije - greška
  ld    (ix + 9), $ED           ; Prvi bajt koda
  ex    de, hl
  call  KOJR2                   ; Na koji registar se odnosi IN/OUT (C)
  cp    6                       ; na (HL)?
  ret   z                       ; To nije u redu
  rlca
  rlca
  rlca
  or    $40                     ; Dodaj bit 5 na mikrokod
  or    c                       ; Formiraj kod
CONTNN:
  ld    (CODE), a
  pop   af
  jp    IXGOON

IFIXIY:
  cp    5
  ret   nz
  ld    a, (IXIY)               ; Ima li išta u (IXIY)?
  or    a
  jr    RETIFZ                  ; Vrati se ako nema, inače greška

GRUPA9:
  ld    c, a                    ; 'JP'/'CALL'/'RET'
  cp    $44
  jr    nz, NOJPHL              ; Ako nije JP (HL)/(IX)/(IY) - skoči
  ld    a, (hl)
  cp    $86
  ld    a, c
  jr    nz, NOJPHL              ; Ako nije HL u zagradi - skoči
  ld    a, $E9                  ; Kod za JP (HL)
SVEOK:
  pop   de
  jr    ZAOV7                   ; Smesti kod na mesto
NOJPHL:
  cp    $46
  jr    z, RETJE                ; Skoči ako je 'RET' token
  jr    nc, GRUP10              ; Ako je token veći
  sub   $42
  rlca
  ld    e, a
  call  CC                      ; Vidi da li postoji uslovni JP/RET
  ld    a, e
  jr    nc, NOTCC               ; Skoči ako je bezuslovni
  inc   a
  dec   a
  ret   z                       ; Ako je DJNZ uslovni - WHAT?
  dec   a
  dec   a
  jr    nz, NOTCC               ; Ako nije JR
  bit   5, b                    ; Ako je JR PO/PE/P/M
  ret   nz                      ; onda je to greška

NOTCC:
  push  hl
  ld    d, 0
  ld    hl, TABJP
  adc   hl, de                  ; Sračunaj poziciju u tabeli
  ld    a, (hl)                 ; Prvi element mikrokoda
  or    b                       ; Drugi element mikrokoda
  ld    (CODE), a
  pop   hl
  ld    a, 3                    ; 3-bajtni JP/CAll
  ld    (ix + 14), a
  ld    a, (hl)
  cp    $40
  ret   nz                      ; Ako nije numerik - greška
  pop   af
  inc   hl
  ld    e, (hl)                 ; Niski bajt numerika
  inc   hl
  ld    d, (hl)                 ; Visoki bajt numerika
  ld    (CODE + 1), de          ; idu u 2. i 3. bajt instrukcije
  ld    a, c
  cp    $44
  ret   nc                      ; Vrati se ako je JP/CALL/RET
  dec   (ix + 14)               ; Samo 2 bajta, a ne 3
  ld    hl, (ADDR)
  inc   hl
  inc   hl                      ; Podesi 2 bajta JR/DJNZ polja
  ex    de, hl
  or    a
  sbc   hl, de                  ; Sračunaj relativni skok
  ld    (ix + 11), l            ; Relativni skok
  ld    (ix + 12), 0            ; Visoki bajt = 0
ADJOV:
  bit   7, l
  jr    nz, NEGATL              ; Skok unazad (negativan)
  dec   h
NEGATL:
  inc   h
RETIFZ:
  ret   z                       ; Vrati se ako je skok pozitivan i H=0
IFOV:
  ld    de, (KRUG)
  dec   e
  ret   nz                      ; Vrati se ako je prvi krug
HOWHL:
  ld    de, ($2A9F)             ; Idi na 'HOW?' pošto postaviš znak pitanja na početak reda
  inc   de
  inc   de
  jp    $65A                    ; HOW?

RETJE:
  call  CC                      ; Uslovni povratak
  inc   (hl)
  dec   (hl)
  ret   nz                      ; Greška ako postoji OPER2
  ld    a, $C9                  ; RET kod = $C9
  pop   de                      ; Skini 'WHAT?' entry point sa stack-a
  jr    nc, ZAOV7               ; Bezuslovni RET
  ld    a, $C0                  ; Uslovni RET, mikrokod i gotov kod
  or    b
ZAOV7:
  jp    CODRET

GRUP10:
  SUB   $49                     ; Grupa 10, RST i IM
  jr    nc, PSHPOP              ; Ako je >$49
  ld    c, a
  call  IFNUM1                  ; Ako nije OPER1 numerik ili ako postoji OPER2
  inc   hl
  inc   hl                      ; Onda WHAT?
  ld    a, (hl)
  or    a
  call  nz, IFOV                ; Ako je >255 i ako je 2. krug - greška
  dec   hl
  inc   c
  jr    nz, RSTP                ; Idi na 'RESTART' obradu
  inc   (ix + 14)               ; Ovde je 'IM', 2 bajta
  ld    (ix + 9), $ED           ; Prvi bajt
  ld    a, (hl)
  ld    b, a
  cp    3
  call  nc, IFOV                ; Najveći im je 2, preko toga je greška
  ld    a, $56                  ; Kod za IM 1
  dec   b
  jr    z, SVEOK1
  ld    a, $5E                  ; Kod za IM 2
  dec   b
  jr    z, SVEOK1
  ld    a, $46                  ; Kod za IM 3
SVEOK1:
  jp    SVEOK

RSTP:
  ld    a, (hl)                 ; 'RESTART' obrada
  and   $C7                     ; Samo ako je od  do $38 step 8
  call  nz, IFOV                ; Inače je greška
  ld    a, (hl)
  or    $C7                     ; Mikrokod
  jr    SVEOK1

PSHPOP:
  rlca                          ; PUSH/POP obrada
  rlca
  ld    c, a
  ld    a, (de)
  or    a
  ret   nz                      ; Ako postoji OPER2 - greška
  ld    a, (hl)
  cp    7
  ret   z                       ; Ako je PUSH/POP SP
  cp    3
  jr    nz, NOTAF
  ld    a, 7                    ; Za AF je poseban kod
NOTAF:
  call  KOP1                    ; Formiraj mikrokod
  or    $C1
  or    c                       ; To je gotov kod
  jr    SVEOK1

CC:
  ld    b, 0                    ; Mikrokod uslovne radnje
  ld    a, (hl)
  cp    9
  jr    nz, NREGC
  ld    a, $14                  ; Spec. slučaj, nije C flag
  ld    (hl), a                 ; Nego je registar C
NREGC:
  sub   $11
  ccf
  ret   nc                      ; NC ako je token<$11 (registri)
  cp    8
  ret   nc
  rlca
  rlca
  rlca
  inc   hl
  inc   hl
  inc   hl
  ld    b, a                    ; U B je mikrokod
  scf                           ; C set = uslov OK
  ret

ZAINS2:
  ld    a, (ix + 3)             ; Ako je numerik manji od 256
  sub   $40                     ; vrati se
  or    (ix + 5)
  jr    nz, ZAWH1               ; Inače WHAT?
  ld    a, (ix + 4)
  ret

KOJREG:
  ld    e, 1                    ; e = 1, to je znak da je 8-bitni reg.
KOJR2:
  call  RTEST                   ; Uzmi token registra
  ret   nc
ZAWH1:
  jp    WHATHL                  ; Ako uopšte nije registar
RTEST:
  ld    a, (hl)
  or    a
  jr    z, ZAWH1                ; Ako je uz to još i numerička vrednost
  cp    $86                     ; Ako je (HL) indirektno
  ld    a, 6                    ; Onda je mikrokod = 6
  ret   z                       ; Gotov slučaj (HL) indirektno
  ld    a, (hl)
  cp    $0F
  ccf
  ret   c
  sub   8
  ret   c
  cp    6
  jr    nz, ZARET1              ; Vrati se sa mikrokodom ako je <6
  inc   a                       ; Podesi na 7 ako je A reg.
ZARET1:
  or    a                       ; Set flags
  ret

IXIYHL:                         ; Svođenje IX/IY na slučaj HL
  call  ZAM                     ; Svedi slučaj za OPER1
  ld    hl, INS3
  jr    nz, ZAM                 ; Svedi slučaj za OPER2
  ld    d, b
  call  ZAM
  ret   nz
  ld    a, b
  cp    d
  ret   z
  jr    ZAWH1                   ; 'IY' prvi bajt (ostalo je kao HL)

ZAM:
  ld    b, $FE
  ld    a, (hl)
  and   $3F
  cp    6
  ret   z
  dec   b
  dec   a
  jr    nz, NOIX
  ld    b, $DD                  ; 'IX' prvi bajt (ostalo je kao HL)
  db    $3E
NOIX:
  dec   a
  ret   nz
  ld    (ix + 9), b             ; Smesti prvi bajt na spec. IXIY mesto
  ld    a, (hl)
  and   $C0
  or    6
  ld    (hl), a
  xor   a
  ret

PROG1:                          ; Formiranje tokena i stavljanje u tablicu
  ld    de, FIELD + 18
  ld    b, 18
  xor   a
CLFLD:
  dec   de
  ld    (de), a                 ; Brisanje cele tablice
  djnz  CLFLD
  push  de
  pop   ix                      ; IX zauzima prvu poziciju (za OPER1)
  inc   hl
  inc   hl
  push  hl
  ld    hl, (ADDR)
  ld    (TEMP1), hl
  pop   hl
  push  hl
  ld    a, (hl)
  cp    '!'                     ; '!' je primedba
  call  nz, RELOAD              ; Pozovi tokenizovanje ako nije primedba
  pop   hl
FINDCR:
  ld    a, $0D                  ; Nađi kraj reda
SRCHCR:
  cp    (hl)
  inc   hl                      ; Nije još $0D - traži dalje
  ret   z
  jr    SRCHCR

RELOAD:
  push  hl                      ; *** Generisanje tokena ***
  call  SUB1A                   ; Prepoznaj opkod ili operand
  jr    nz, NOLAB               ; Ako je prepoznata reč - skoči, ako nije - znači labela
  pop   hl
  ld    (FIELD + 2), hl         ; Smesti adresu labele u programu
SRCH20:
  inc   hl                      ; Traži kraj labele (blank ili CR)
  ld    a, (hl)
  cp    $0D
  jr    z, BLANK                ; Ako je CR - izađi
  cp    ' '
  jp    nz, SRCH20              ; Ako nije blank - traži dalje
  inc   hl                      ; Prvo mesto iza blanka
BLANK:
  call  IF0                     ; Vidi da li je kraj ili REM
  call  SUB1                    ; Prepoznaj opkod
  jr    z, NEAR                 ; Ako ne prepoznaš - WHAT?
  push  af
NOLAB:
  pop   af
  ld    a, c                    ; Uzmi token opkoda
  and   $7F                     ; Maskiraj sve osim bita 7
  ld    (ix + 5), a             ; Smesti O opkod
  call  IFTXT0                  ; Vidi da li je 'TEXT' token
  call  TRANS1                  ; Obradi slučaj za OPER1
  ld    ix, FIELD + 3           ; Postavi IX za OPER2
  call  IF0                     ; Vidi da li je kraj ili REM
  call  SKIP2                   ; Preskoči eventualne blankove
  cp    ','
  jr    nz, NEAR                ; Ako nije zarez
  call  TRANS2                  ; Obradi slučaj za OPER2
  call  IF0                     ; Vidi da li je kraj ili REM
NEAR:
  jp    WHSK                    ; Ako nije - greška

TRANS1:
  dec   hl
TRANS2:
  call  SKIPBL                  ; Preskoči eventualne blankove
  cp    '('
  jr    nz, NEZAG               ; Nije '(' - skoči
  inc   hl                      ; Preskoči '(' ako jeste
  set   7, (ix + 6)             ; Zabeleži bit da je otv. zagrada
NEZAG:
  ld    de, TABEL2 - 1          ; Tabela 2, operandi
  push  hl
  call  PREPOZ                  ; Pronađi koji je
  inc   c
  res   7, c
  ex    de, hl
  or    a
  jr    z, NEPREP               ; Nije prepoznao, možda je izraz?
  call  SKIPBL                  ; Preskoči eventualne blankove
  pop   af
  ld    a, (ix + 6)
  or    c                       ; Smesti u polje operanda token
  ld    (ix + 6), a
  ld    a, c
  cp    3
  jr    nc, ZATZAG              ; Ako nije IX ili IY
  call  SKIP2                   ; Preskoči eventualne blankove
  cp    ')'
  jr    z, ZATZ2                ; To je kao (IX + 0) ili (IY + 0)
  cp    '-'
  jr    z, ZNAK
  cp    '+'
  jr    nz, ZATZ3
ZNAK:
  call  IZRAZ                   ; Stavi vrednost izraza u HL
  push  hl
  ex    de, hl
  call  ADJOV                   ; Testiraj -128<DE<127
  ld    e, l                    ; E = niži bajt
  pop   hl
  jr    SKR1                    ; Nađi zatvorenu zagradu

ZATZAG:
  call  SKIP2                   ; Preskoči blankove
  cp    ')'
  jr    nz, ZATZ3               ; Ako nije zat. zagrada
ZATZ2:
  cpl
  inc   hl
NOTZZ:
  xor   (ix + 6)                ; XOR sa starim stanjem zagrade
  ret   p                       ; Vrati se ako je parni broj zagrada
WHSK:
  jp    WHATHL                  ; Ako nije - greška
ZATZ3:
  xor   a
  jr    NOTZZ

NEPREP:
  set   6, (ix + 6)             ; Bit 6 znači da je numerička vrednost
  pop   hl
  call  IZRAZ                   ; Sledi numerički izraz
  ld    (ix + 8), d             ; Stavi ga u numeričko polje operanda
SKR1:
  ld    (ix + 7), e
  jr    ZATZAG

SUB1A:
  push  hl
  ld    de, TABEL2 - 1          ; Tabela operanda
  call  PREPOZ                  ; Prepoznaj reč u tabeli
  pop   hl                      ; Ako je prepoznao, znači da je
WHSK2:
  jr    nz, WHSK                ; operand na mestu opkoda - greška
SUB1:
  ld    de, TABEL1 - 1          ; Tabela opkoda
  call  PREPOZ                  ; Prepoznaj reč u tabeli
  inc   c
  ex    de, hl
  inc   hl
  or    a                       ; Ako je NZ
  ret                           ; Znači da je uspelo prepoznavanje

IFTXT0:
  sub   2                       ; 2 = 'TEXT' token
  jr    nz, IF0                 ; Ako nije - skoči
  call  SKIPBL                  ; Preskoči eventualne blankove
  cp    '"'
  jr    nz, WHSK                ; Ako nije znak navoda
  inc   hl                      ; onda je greška
  ld    (INS2 + 1), hl          ; Početak teksta u registar teksta
  ld    c, 0
FINDZN:
  ld    a, (hl)
  cp    '"'                     ; Kraj teksta?
  inc   hl
  jr    z, IF0T                 ; Jeste - izađi
  cp    $0D
  jr    z, WHSK                 ; Kraj reda, a nema znaka navoda - WHAT?
  inc   c
  jr    FINDZN                  ; Dalje traži znak navoda
IF0T:
  ld    a, c
  ld    (INS2), a               ; Broj slova teksta
IF0:
  call  SKIP2                   ; Preskoči eventualne blankove
IF01:
  cp    '!'
  jr    z, REMJE                ; Ako je REM - skoči
  cp    $0D
  ret   nz                      ; Vrati se ako nije CR
  pop   af                      ; Ako jeste CR - skini poslednju RET adresu sa steka pa se vrati na jedno mesto ranije
  ret

REMJE:
  inc   hl
  ld    a, (hl)                 ; Ako je '!' - to je REM, nađi kraj reda
  cp    $0D
  jr    nz, REMJE               ; Još nije kraj reda
  pop   af                      ; Vrati se jedno mesto ranije (kao posle IF01)
  ret

NCSLBR:
  ld    a, (hl)
  call  $173                    ; Ako je 0-9, dakle cifra
  dec   de                      ; Onda reset C flega i vrati se
  ret   nc
  inc   de
LETNCA:
  cp    $41                     ; Ako je A-Š, dakle slovo, reset C fleg
  ret   c
  cp    $5F
  ccf
  ret

JEDANX:
  call  JEDAN                   ; Sračunaj jedan član izraza i vrednost u HL
  ld    bc, (TEMP2)             ; Uzmi prethodnu vrednost u BC
  ret

IZRAZ:
  ex    de, hl
  rst   $28                     ; To je LD HL
  rst   $18                     ; Testiraj da li je sledeći znak plus
  db    '+'
  db    0                       ; i preskoči samo njega ako jeste
  cp    '-'                     ; Ili ako je minus
  call  nz, JEDAN               ; Smesti član u HL
STORE:
  ld    (TEMP2), hl             ; odatle u registar prethodne vrednosti
  call  CLAN                    ; Sračunaj jedan član
  jp    c, HOWHL                ; Ako je overflow
  jr    STORE                   ; Nastavi glavnu petlju računanja izraza

CLAN:
  rst   $18                     ; Sračunaj jedan član izraza i vrednost u HL
  db    '+'                     ; Da li je plus?
  db    CL1-$-1                 ; Ako nije skoči na CL1
  call  JEDANX                  ; Sračunaj član
  add   hl, bc                  ; Saberi ga sa prethodnom vrednošću
  ret
CL1:
  rst   $18
  db    '-'                     ; Da li je minus?
  db    CL2-$-1                 ; Ako nije idi na CL2
  call  JEDAN
  or    a
  ld    b, h
  ld    c, l
  ld    hl, (TEMP2)
  sbc   hl, bc                  ; Oduzmi od prethodne vrednosti
  or    a
  ret
CL2:
  rst   $18
  db    '<'                     ; Da li je pomeranje nalevo?
  db    CL3-$-1                 ; Ako nije idi na CL3
  call  JEDAN
  ld    b, l                    ; B = broj pomeranja
  ld    hl, (TEMP2)
ROTHL1:
  add   hl, hl                  ; ADD je pomeranje nalevo
  djnz  ROTHL1                  ; To uradi B puta
  or    a                       ; Clear C (nema overflow)
  ret
CL3:
  rst   $18
  db    '>'                     ; Da li je pomeranje nadesno?
  db    CL4-$-1                 ; Ako nije idi na CL4
  call  JEDAN
  ld    b, l
  ld    hl, (TEMP2)
ROTHL2:
  srl   h                       ; Pomeraj nadesno B puta
  rr    l
  djnz  ROTHL2
  or    a
  ret
CL4:
  rst   $18
  db    '#'                     ; Da li je '#' (znači AND)
  db    CL5-$-1                 ; Nije - idi na CL5
  call  JEDANX
  ld    a, h
  and   b                       ; AND visoki bajt
  ld    h, a
  ld    a, l
  and   c                       ; AND niski bajt
  ld    l, a
  ret
CL5:
  cp    ')'                     ; Terminatori izraza, zatvorena zagrada
  jr    z, TERMIN
  cp    $0D                     ; Kraj reda
  jr    z, TERMIN
  cp    '!'                     ; REM
  jr    z, TERMIN
  cp    ','                     ; Zarez
  jr    nz, WHATHL
TERMIN:
  pop   af
  ld    hl, (TEMP2)
  ex    de, hl                  ; Uzmi u DE rešenje izraza
  ret

JEDAN:                          ; *** Jedan član izraza sračunava u HL ***
  call  $105                    ; Preskoči eventualne blankove
  call  $173                    ; Ako nije cifra 0-9
  jr    c, NEDEC                ; onda skoči
  dec   de
  call  RELIX1                  ; Pripremi IX za aritmetiku
  call  $CD3                    ; Sračunaj decimalni broj
  jp    RELIX2                  ; Vrati IX
NEDEC:
  cp    '&'                     ; Da li je znak za hex broj?
  jr    nz, NEHEX               ; Ne - skoči
  inc   de
  call  $165                    ; Pročitaj hex cifru
  jp    c, HOWHL                ; Nije hex cifra - HOW?
  dec   de
  rst   $28                     ; To je LD HL, 0
GOCONV:
  call  $165                    ; Pročitaj hex cifru
  ret   c                       ; Nije hex cifra? Kraj posla
  call  RLC4                    ; Rotiraj 4 mesta ulevo (*16)
  ld    bc, GOCONV              ; Pripremi RET adresu
  jp    $DF2                    ; Nastavi konvrziju TODO adresa 3570 ili 357!?!
NEHEX:
  ex    de, hl
  call  LETNCA                  ; Ako je slovo A-Š
  jr    c, NLABEL               ; Nije - znači nije labela
  call  LOCATE                  ; Lociraj labelu
  jr    nz, WHATHL              ; Nema je - WHAT?
  ld    a, (INS1)
  cp    6                       ; Ako je opkod = org, onda WHAT?
  jr    z, WHATHL               ; (ne sme da se poziva na labelu)
  ld    d, b
  ld    e, c
  ex    de, hl
  ret
NLABEL:
  ex    de, hl
  rst   $18
  db    '"'
  db    NIZAGR-$-1              ; Nije ASCII - idi dalje
ASCX:
  ld    a, (de)                 ; Uzmi ASCII znak
  inc   de
  ld    l, a
  ld    h, 0                    ; Smesti ga u HL
  rst   $18
  db    '"'                     ; Zatvoren znak navoda - tako i treba
  db    WHATHL-$-1              ; Ako slučajno nije - greška
  ret
NIZAGR:
  rst   $18
  db    '$'                     ; Da li je PC lokacija?
  db    WHATHL-$-1              ; Ne - onda nije ništa, greška
  ld    hl, (ADDR)              ; Da - uzmi je iz PC registra
  ret
WHATHL:
  ld    de, ($2A9F)             ; WHAT ulazna tačka
  inc   de
  inc   de
  jp    $78F                    ; Pa pravo na WHAT u ROM-u A

PREPOZ:                         ; Prepoznavanje reči
  ld    b, $7F
  ld    a, (hl)
Z1C0C:
  ld    c, (hl)
  ex    de, hl
Z1C0E:
  inc   hl                      ; Nađi početak reči u tablici (bit 7 = 1)
  or    (hl)
  jp    p, Z1C0E                ; Traži početak
  inc   b
  ld    a, (hl)                 ; Ako je (HL) = $80
  and   $7F                     ; Onda je to kraj tablice
  ret   z                       ; Pa se vrati sa A=0 (znak da nije prepoznao)
  cp    c
  jr    nz, Z1C0E               ; Ovaj znak nije isti - pokušaj novu reč
  ex    de, hl                  ; Znak je isti - zasad ide dobro
  push  hl
Z1C1D:
  inc   de
  ld    a, (de)                 ; Uzmi novi znak iz tablice
  or    a
  jp    m, Z1C39                ; To je onda početak sledeće reči
  ld    c, a
Z1C2B:
  inc   hl
  ld    a, (hl)                 ; Uzmi novi znak iz prog. linije
  cp    c
  jr    z, Z1C1D                ; Ako je isti
PHL:
  pop   hl
  jr    Z1C0C                   ; Nije isti, probaj novu reč
Z1C39:
  inc   hl                      ; Uspelo poređenje, prepoznata reč
  call  NCSLBR                  ; Da li je kraj reči u programu?
  dec   hl
  jr    c, X1C39                ; Jeste, zadnji test uspeo
  dec   de                      ; Nije kraj - dakle poređenje neuspešno
  jr    PHL                     ; Probaj neku drugu reč iz tablice
X1C39:
  ld    c, b                    ; C = B = token
  pop   af                      ; U A će doći H, to je >0, znak da je...
  ex    de, hl
  or    a                       ; ... prepoznao reč
  ret

SKIPBL:
  inc   hl                      ; Preskoči blankove od sledećeg mesta
SKIP2:
  ex    de, hl                  ; Preskoči blankove od ovog mesta
  call  $105                    ; Preskoči eventualne blankove
  ex    de, hl
  ret

RELIX1:
  ld    (IXPOS2), ix            ; Sačuvaj staro IX
  ld    ix, $2AAC               ; i pripremi IX za aritmetiku u ROM-u A
  ret

BRKPT:                          ; Breakpoint (REG)
  ld    (FIELD + SPACE - 1), sp ; Sačuvaj SP za povratak
  ld    sp, FIELD + SPACE - 1   ; Uzmi novi SP
  push  af                      ; Smešta redom sve registre u memoriju
  push  bc
  push  de
  push  hl
  push  ix
  ld    hl, (FIELD + SPACE - 1)
  inc   hl
  inc   hl
  push  hl                      ; HL je ovde SP + 2 (SP pre nego što je došao na REG)
  ld    e, (hl)
  inc   hl
  ld    d, (hl)                 ; DE = zadnja stvar na stack-u
  exx
  ex    af, af'
  push  af                      ; Stavlja alternativne registre u memoriju
  push  bc
  push  de
  push  hl
  push  iy
  exx
  push  de                      ; Stavlja zadnju stvar sa stack-a u memoriju
  call  $2ED                    ; Idi na novi red (ako nije već početak)
  ld    de, NASLOV
  call  $937                    ; Piši: AF BC DE HL IXIY SP()
  ld    de, FIELD + SPACE - 2
  ld    b, 2                    ; Dva reda za ispisivanje
RED:
  push  bc
  ld    b, 6                    ; Šest članova za ispisivanje
SABL:
  ld    a, ' '                  ; Prvo blank
  rst   $20
  ld    a, (de)                 ; Uzima iz memorije u grupama od po dva bajta
  dec   de
  ld    h, a
  ld    a, (de)
  dec   de
  ld    l, a                    ; HL = dvo-bajtna vrednost para registara
  call  HEX16                   ; Napiši HL
  djnz  SABL                    ; Uradi to 6 puta
  ld    a, $0D                  ; Pa idi na novi red
  rst   $20
  pop   bc
  djnz  RED                     ; Pa još jednom sve isto (za alt. registre)
  ld    hl, (SHOMEM)
  ld    a, h
  or    l                       ; Treba li da se pokazuje memorija?
  ld    a, (SHOFOR)
  call  nz, PMEM                ; Ako treba
  call  $CF5                    ; Sačekaj da se pritisne bilo koji taster
  pop   af                      ; Vraća sve registre iz memorije u registre
  pop   af
  pop   hl
  pop   de
  pop   bc
  pop   af
  ex    af, af'
  exx
  pop   af
  pop   af
  pop   hl
  pop   de
  pop   bc
  pop   af
  ld    sp, (FIELD + SPACE - 1)
  ret                           ; Na kraju je uzeo i stack pointer

PMEM:
  ld    d, a                    ; Štampa hex mem od HL ukupno A redova
PMEM2:
  call  HEX16B                  ; Prvo adresu memorije
  ld    a, ':'                  ; Pa onda dve tačke
  rst   $20
  ld    b, 8                    ; 8 bajta po redu
RED8:
  ld    a, ' '                  ; Prvo blank
  rst   $20
  ld    a, (hl)
  call  HEX8                    ; Pa bajt
  inc   hl
  djnz  RED8                    ; I tako osam puta
  call  $2FF                    ; Test 'BRK' ili 'DEL' tastera
  ld    a, $0D
  rst   $20                     ; Novi red
  dec   d
  jr    nz, PMEM2               ; I tako D redova
  ret

DEL:
  ld    a, 3
  push  af
  rst   $8                      ; Sračunaj prvi član ('od' liniju)
  push  de
  call  $7F2                    ; Da li postoji ta linija?
  jr    nz, SKRHOW              ; Ne postoji - HOW?
  pop   hl
  push  de
  push  de
  ex    de, hl
  call  5                       ; Testiraj zarez i sračunaj 'od' liniju
  call  $7F2                    ; Postoji li ta linija?
  jr    nz, SKRHOW              ; Ne - greška
  ex    (sp), hl
  rst   $10                     ; Uporedi da li je druga veća od prve
  ex    (sp), hl
  jp    c, $359                 ; Ako jeste, izbaci sve od prve do druge
SKRHOW:
  jp    $65B                    ; Ako nije - HOW?

NAME:
  rst   $8                      ; *** REN *** Ograničeno renumerisanje
  ld    a, h
  or    a                       ; Ako je korak veći od 255
  push  de
  jr    nz, SKRHOW              ; Onda - HOW?
  or    l                       ; Ako je korak = 0
  jr    z, SKRHOW               ; Onda - HOW?
  ld    b, h
  ld    c, l
  rst   $28                     ; HL = 0
  push  hl
  ld    de, ($2C36)             ; Početak BASIC programa
THRU:
  ld    hl, ($2C38)             ; Kraj BASIC programa
  ex    de, hl
  rst   $10                     ; Uporedi trenutni pointer (DE) i kraj
  ex    de, hl
  pop   hl
  jr    nc, NAMED               ; Ako su isti ili je trenutni veći - gotovo
  add   hl, bc                  ; Saberi sa korakom
  bit   7, h
  jr    nz, SKRHOW              ; Ako je overflow (>$7fff) HOW?
  push  hl
  ex    de, hl
  ld    (hl), e                 ; Novi broj linije - niski bajt
  inc   hl
  ld    (hl), d                 ; Novi broj linije - visoki bajt
  ex    de, hl
F0D:
  inc   de                      ; Nađi kraj linije
  ld    a, (de)
  cp    $0D
  jr    nz, F0D                 ; Nije još kraj - traži ga
  inc   de
  jr    THRU                    ; Idi na sledeću liniju
NAMED:
  pop   de
KAO48:
  rst   $30                     ; Nastavi BASIC

FIND:                           ; Nalaženje niza znakova u programu
  push  de
  ld    hl, ($2C36)             ; Početak BASIC-a
  dec   hl
TRAZI:
  inc   hl
TRAZI9:
  ld    de, ($2C38)             ; Kraj BASIC-a
  rst   $10
  jr    nc, IZLAZF              ; Ako su jednaki - gotovo
  call  $2FF                    ; 'BRK' - 'DEl' test
  ld    b, h
  ld    c, l
  inc   hl
  push  hl
NISTO:
  pop   hl
  inc   hl
  ld    a, (hl)
  cp    $0D                     ; Kraj reda?
  jr    z, TRAZI                ; Da - traži sledeći
  pop   de
  push  de
  push  hl
TRAZI2:
  ld    a, (de)                 ; Uzmi sledeći znak
  cp    (hl)                    ; Uporedi sa znakom u programu
  jr    nz, NISTO               ; Nije isto - počni ponovo
  inc   de
  ld    a, (de)                 ; Uzmi sledeći znak
  cp    $0D                     ; Kraj reda?
  jr    z, TOTAL                ; Da - komparacija uspela
  inc   hl
  jr    TRAZI2                  ; Nije uspela - traži dalje
TOTAL:
  pop   af
  push  de
  push  bc
  push  bc
  pop   de
  call  $931                    ; Štampaj liniju na ekranu
  pop   hl
  pop   de
  inc   hl
FEND:
  inc   hl                      ; Nađi kraj reda
  ld    a, (hl)
  cp    $0D
  jr    nz, FEND                ; Nije još CR
  jr    TRAZI                   ; Traži u sledećoj liniji
IZLAZF:
  pop   de
FEND2:
  inc   de                      ; Nađi kraj reda
  ld    a, (de)
  cp    $0D
  jr    nz, FEND2               ; Nije još CR
  rst   $30                     ; Nastavi BASIC

LDUMP:                          ; LDUMP - Line printer flag
  call  COPY
DUMP:                           ; DUMP - Štampaj sadržaj memorije
  rst   $8                      ; Od koje adrese?
  push  hl                      ; Adresa je u HL
  call  5                       ; Test zarez i do koje adrese?
  ld    a, l
  or    a                       ; Ako jeviše od 0 redova
  pop   hl
  push  de
  call  nz, PMEM                ; Pozovi štampanje memorije
  pop   de
  rst   $30                     ; Nastavi BASIC

; Floating point konstante
C2      dw $04F5                ; 0.707107
        dw $0035
C3      dw $56AE                ; 0.598979
        dw $0019
C4      dw $22F3                ; 0.961471
        dw $0076
C5      dw $AA3D                ; 2.88539
        dw $0138
CPI     dw $0FD6                ; 3.1415926
        dw $0149
PIPOLA  dw $0FD6                ; PI / 2
        dw $00C9
PI2     dw $0FD6                ; 2 * PI
        dw $01C9
X1EM3   dw $126D                ; 1E-3
        dw $7B83

CS1     dw $0000                ; -6
        dw $81C0
CS2     dw $0000                ; 120
        dw $03F0
CS3     dw $8000                ; -5040
        dw $869D
CS4     dw $3000                ; 362880
        dw $09B1

CX2     dw $7213                ; 0.693147
        dw $0031

CE1     dw $F84F                ; 2.71828182
        dw $012D
CE2     dw $0B5C                ; 1.3888889E-3
        dw $7BB6
CE3     dw $8885                ; 8.33333E-3
        dw $7D08
CE4     dw $AAA8                ; 0.04166667
        dw $7E2A
CE5     dw $AAA9                ; 0.1666667
        dw $7F2A
C1      dw 0                    ; 0.5
        dw 0
C7      dw 0                    ; 1
        dw $80
CE8     dw 0                    ; 1
        dw $80

CT1     dw $D758                ; 2.86623E-3
        dw $7C3B
CT2     dw $6DEC                ; -1.61657E-2
        dw $FD84
CT3     dw $C1F6                ; 4.29096E-2
        dw $7E2F
CT4     dw $311C                ; -7.5289E-2
        dw $FE9A
CT5     dw $3DB1                ; 0.106563
        dw $7EDA
CT6     dw $7FC6                ; -0.142089
        dw $FF11
CT7     dw $BC03                ; 0.199936
        dw $7F4C
CT8     dw $AA7C                ; -0.333332
        dw $FFAA

RADDEG  dw $2EDE                ; 57.29578
        dw $0365

PI:
  ld    hl, CPI                 ; 'PI' konstanta
  jp    $A45

DUBL2:
  call  DUBLIX                  ; Dupliraj IX u arith. stack-u dvaput
DUBLIX:
  ld    b, 5                    ; Dupliraj IX u arith. stack-u jedanput
MOVE5:
  ld    a, (ix - 5)
  ld    (ix), a
  inc   ix
  djnz  MOVE5                   ; Premesti 5 bajtova
  ret

CP0:
  call  DUBLIX                  ; Uporedi (IX) sa nulom
  rst   $28                     ; To je LD HL
  call  $ABC                    ; Premesti HL u (IX)
  jr    COMP                    ; Uporedi (IX - 5) sa (IX)

CP1:
  ld    hl, C7                  ; Uporedi (IX) sa jedinicom
CPHL:
  push  hl
  call  DUBLIX                  ; Dupliraj (IX)
  pop   hl
CPHL1:
  call  $A45                    ; Smesti (HL) u (IX)
COMP:
  jp    $B10                    ; Uporedi (IX -5) sa (IX)

IXM10:
  ld    bc, $FFFF - 9           ; IX = IX - 10
  jr    SKRBC
IX5:
  ld    bc, 5                   ; IX = IX + 5
SKRBC:
  add   ix, bc
  ret

ISPOD2:
  ld    hl, $FFFF - 9           ; Skini dva broja sa arith. stack-a, ali sačuvaj poslednji
  jr    SKRISP
ISPOD3:
  ld    hl, $FFFF - 14          ; Skini tri broja sa arith. stack-a, ali sačuvaj poslednji
SKRISP:
  push  de
  push  ix                      ; Skini HL/5 brojeva sa arith. stacka-a, ali sačuvaj poslednji
  pop   de
  add   hl, de
  ld    bc, 5
  ldir
  push  de
  pop   ix
  pop   de
  ret

LOG equ $                       ; Prirodni logaritam
LOGIT:
  call  $781
LOGIT2:
  call  CP0
  jp    c, $65A
  jp    z, $65A
  ld    (ix + 15), 0
CONT1:
  call  CP1
  jr    c, OVER1
  ld    hl, C1
  call  PUTAHL
  inc   (ix + 15)
  jr    CONT1
OVER1:
  ld    hl, C1
  call  CPHL
  jr    nc, OVER2
  ld    hl, C1
  call  KROZHL
  dec   (ix + 15)
  jr    OVER1
OVER2:
  call  DUBLIX
  ld    hl, C2
  call  MINHL
  call  ISPOD2
  ld    hl, C2
  call  PLUSHL
  call  KROZ
  call  MOVE0
  call  DUBL2
  call  PUTA
  ld    hl, C3
  call  PUTAHL
  ld    hl, C4
  call  PLUSHL
  call  ISPOD2
  call  DUBLIX
  call  PUTA
  call  PUTA
  ld    hl, C5
  call  PLUSHL
  call  PUTA
  ld    l, (ix + 15)
  ld    h, 0
  bit   7, l
  jr    z, POZL
  dec   h
POZL:
  call  $ABC
  call  PLUS
  ld    hl, C1
  call  MINHL
  ld    hl, CX2
PUTAHL:
  call  $A45
  jp    PUTA

ABSF:
  call  $781                    ; Apsolutna vrednost
ABSA:
  ld    a, (ix - 1)
ABS2:
  res   7, (ix - 1)
  ret

TAN:                            ; Tangens
  push  de
  call  SIN
  pop   de
  call  COS
ZAKROZ:
  jp    KROZ

ABSDEG:
  ld    bc, ABSA                ; Uzima apsolutnu vrednost izraza i deli je sa konstantom 57.29578
  push  bc                      ; ako sledi slovo D (DEGREE)
  rst   $18
  db    'D'
  db    NODEGR-$-1
  call  $781
  ld    hl, RADDEG
KROZHL:
  call  $A45
  jr    ZAKROZ

NODEGR:
  jp    $781
COS:
  call  ABSDEG                  ; Kosinus
  ld    hl, PIPOLA
  call  PLUSHL
  xor   a
  jr    KAOSIN

SIN:
  call  ABSDEG                  ; Sinus
  rlca
KAOSIN:
  ld    (ix + 20), a            ; Kosinus se nastavlja kao sinus
  ld    hl, PI2
  push  hl
  call  CPHL
  pop   hl
  jr    c, LTH2PI
  push  hl
  call  KROZHL
  call  DUBLIX
  call  $A6D
  call  $ABC
  call  MINUS
  pop   hl
  call  PUTAHL
LTH2PI:
  ld    hl, CPI
  push  hl
  call  CPHL
  pop   hl
  jr    c, LTHPI
  call  MINHL
  inc   (ix + 20)
LTHPI:
  ld    hl, PIPOLA
  call  CPHL
  jr    c, LTH90
  call  DUBLIX
  call  IXM10
  call  PI
  call  IX5
  call  MINUS
LTH90:
  ld    hl, X1EM3
  call  CPHL
  ret   c
  call  DUBL2
  ld    hl, CS1 - 4
  ld    b, 4
DO4:
  push  bc
  push  hl
  call  ISPOD3
  call  ISPOD3
  call  PUTA
  call  ISPOD3
  call  PUTA
  push  ix
  ld    bc, $FFFF - 19
  add   ix, bc
  ld    hl, 15
  call  SKRISP
  pop   ix
  pop   hl
  inc   hl
  inc   hl
  inc   hl
  inc   hl
  push  hl
  call  KROZHL
  call  PLUS
  pop   hl
  pop   bc
  djnz  DO4

  bit   0, (ix + 10)
  jr    z, MOVE02
  set   7, (ix - 1)
MOVE02:
  call  MOVE0
MOVE0:
  call  IXM10
MOVE:
  rst   $28
  call  $ABC
  call  IX5
  jr    ZAPLUS
PLUSHL:
  call  $A45
ZAPLUS:
  jp    PLUS

POW:                            ; Stepenovanje
  rst   $18
  db    '('
  db    WH-$-1
  call  $AB2
  call  LOGIT2
  rst   $18
  db    ','
  db    WH-$-1
  call  $AB2
  rst   $18
  db    ')'
  db    WH-$-1
FORSQR:
  call  PUTA
  jr    EXP2

OUTP:                           ; Out
  rst   $8
  push  hl
  call  5
  pop   bc
  out   (c), l
  rst   $30

INP:                            ; In
  ld    c, l
  ld    b, h
  in    l, (c)
  jr    FORDBD

ASCII:                          ; ASCII znak u numeričkom izrazu
  call  ASCX
FORDBD:
  jp    $DBD

SQR:                            ; Kvadratni koren
  call  $781
  call  CP0
  ret   z
  call  LOGIT2
  ld    hl, C1
  call  $A45
  jr    FORSQR

EXP:                            ; E na eksponent X
  call  $781
EXP2:
  call  ABSA
  rla
  push  af
  call  DUBLIX
  call  $A6D
  push  hl
  call  $ABC
  call  MINUS
  rst   $28
  inc   hl
  call  $ABC
  pop   hl
  ld    a, h
  or    a
WH:
  jp    nz, $65A
  or    l
  jr    z, NOLOOP
DOHL:
  push  hl
  ld    hl, CE1
  call  PUTAHL
  pop   hl
  dec   l
  jr    nz, DOHL
NOLOOP:
  ld    hl, CE2
  push  hl
  call  $A45
  pop   hl
  ld    b, 6
EXP6:
  push  bc
  inc   hl
  inc   hl
  inc   hl
  inc   hl
  push  hl
  call  ISPOD3
  call  PUTA
  pop   hl
  push  hl
  call  PLUSHL
  pop   hl
  pop   bc
  djnz  EXP6
  call  PUTA
  pop   af
  jp    nc, MOVE0
  call  IXM10
  ld    hl, C7
  call  $A45
  call  IX5
  jp    KROZ

MINHL:
  call  $A45
  jp    MINUS

ATN:                            ; Arkus tangens
  call  ABSF
  rla
  push  af
  call  CP0
  jp    z, NCOPY
  call  CP1
  push  af
  jr    c, NEKROZ
  call  DUBLIX
  call  IXM10
  ld    hl, C7
  call  $A45
  call  IX5
  call  KROZ
NEKROZ:
  call  DUBL2
  call  PUTA
  rst   $28
  call  $ABC
  ld    hl, CT1
  ld    b, 8
TAYL8:
  push  bc
  push  hl
  call  PLUSHL
  call  ISPOD2
  call  PUTA
  pop   hl
  inc   hl
  inc   hl
  inc   hl
  inc   hl
  pop   bc
  djnz  TAYL8
  ld    hl, C7
  call  PLUSHL
  call  ISPOD3
  call  PUTA
  pop   af
  jr    c, XLTH1
  call  DUBLIX
  call  IXM10
  ld    hl, PIPOLA
  call  $A45
  call  IX5
  call  MINUS
XLTH1:
  pop   af
  jr    nc, XGTH0
  set   7, (ix - 1)
XGTH0:
  jp    MOVE02

TEXT1:                          ; Tablica novih reči za BASIC
  dm  'LPRINT'
  db  (LPRINT>>8 & $00FF) + $80
  db  LPRINT & $FF
  dm  'LLIST'
  db  (LLIST>>8 & $00FF) + $80
  db  LLIST & $FF
  dm  'OUT'
  db  (OUTP>>8 & $00FF) + $80
  db  OUTP & $FF
  dm  '<'
  db  (GOASS>>8 & $00FF) + $80
  db  GOASS & $FF
  dm  '/'
  db  (FIND>>8 & $00FF) + $80
  db  FIND & $FF
  dm  'REN'
  db  (NAME>>8 & $00FF) + $80
  db  NAME & $FF
  dm  'LDUMP'
  db  (LDUMP>>8 & $00FF) + $80
  db  LDUMP & $FF
  dm  'DUMP'
  db  (DUMP>>8 & $00FF) + $80
  db  DUMP & $FF
  dm  'DEL'
  db  (DEL>>8 & $00FF) + $80
  db  DEL & $FF
  db  (KAO75B>>8 & $00FF) + $80
  db  KAO75B & $FF

TEXT3:                          ; Tablica novih funkcija za BASIC
  dm  'SQR'
  db  (SQR>>8 & $00FF) + $80
  db  SQR & $FF
  dm  'LN'
  db  (LOG>>8 & $00FF) + $80
  db  LOG & $FF
  dm  'ABS'
  db  (ABSF>>8 & $00FF) + $80
  db  ABSF & $FF
  dm  'SIN'
  db  (SIN>>8 & $00FF) + $80
  db  SIN & $FF
  dm  'COS'
  db  (COS>>8 & $00FF) + $80
  db  COS & $FF
  dm  'TG'
  db  (TAN>>8 & $00FF) + $80
  db  TAN & $FF
  dm  'ARCTG'
  db  (ATN>>8 & $00FF) + $80
  db  ATN & $FF
  dm  'PI'
  db  (PI>>8 & $00FF) + $80
  db  PI & $FF
  dm  'EXP'
  db  (EXP>>8 & $00FF) + $80
  db  EXP & $FF
  dm  'POW'
  db  (POW>>8 & $00FF) + $80
  db  POW & $FF
  dm  'INP'
  db  (INP>>8 & $00FF) + $80 + $40
  db  INP & $FF
  dm  '"'
  db  (ASCII>>8 & $00FF) + $80
  db  ASCII & $FF
  db  (KAO777>>8 & $00FF) + $80
  db  KAO777 & $FF

TAB4:
  dw  $1000 ; RLC RL (CB+ instrukcije)
  dw  $1808 ; RRC RR
  dw  $2820 ; SLA SRA
  dw  $4038 ; SRL BIT
  dw  $80C0 ; SET RES
  db  0     ; Terminator tablice

TAB5:
  dw  $8880 ; ADD ADC (8-bitna aritmetika)
  dw  $9098 ; SBC SUB
  dw  $B0A0 ; AND OR
  dw  $B8A8 ; XOR CP
  db  0

TAB6:
  dw  $4A09 ; ADD ADC (16-bitna aritmetika)
  db  $42   ; SBC

TABJP:
  dw  $0010 ; DJNZ (uslovni i bezuslovni skokovi)
  dw  $2018 ; JR
  dw  $C2C3 ; JP
  dw  $C4CD ; CAll

TABY1:
  dw  $2F00 ; Proste instrukcije
  dw  $373F
  dw  $F376
  dw  $D9FB
  dw  $1707
  dw  $1F0F
  db  $27
  dw  $A0B0 ; ED+ instrukcije
  dw  $A8B8
  dw  $A1B1
  dw  $A9B9
  dw  $A2B2
  dw  $AABA
  dw  $A3B3
  dw  $ABBB
  dw  $4D44
  dw  $6F45
  db  $67
  db  $0

TESTAB:
  dw  $0F0E ; A, I (load)
  db  $57
  dw  $0E0F ; I, A
  db  $47
  dw  $100E ; A, R
  db  $5F
  dw  $0E10 ; R, A
  db  $4F
  dw  $840E ; A, (BC)
  db  $0A
  dw  $850E ; A, (DE)
  db  $1A
  dw  $0E84 ; (BC), A
  db  $02
  dw  $0E85 ; (DE), A
  db  $12
  dw  $0607 ; SP, HL
  db  $F9
  dw  $C00E ; A, (NN)
  db  $3A
  dw  $0EC0 ; (NN), A
  db  $32

TEST2:
  dw  $687  ; (SP), HL  (exchange)
  db  $E3
  dw  $303  ; AF, AF'
  db  $08
  dw  $605  ; DE, HL
  db  $EB

TABEL1:
  db  'R' + $80 ; Grupa 1: komande
  dm  'EG'

  db  'T' + $80
  dm  'EXT'

  db  'W' + $80
  dm  'ORD'

  db  'B' + $80
  dm  'YTE'

  db  'O' + $80
  dm  'PT'

  db  'O' + $80
  dm  'RG'

  db  'E' + $80
  dm  'QU'

  db  '>' + $80
  db  'N' + $80 ; Grupa 2: proste instrukcije
  dm  'OP'

  db  'C' + $80
  dm  'PL'

  db  'C' + $80
  dm  'CF'

  db  'S' + $80
  dm  'CF'

  db  'H' + $80
  dm  'ALT'

  db  'D' + $80
  dm  'I'

  db  'E' + $80
  dm  'I'

  db  'E' + $80
  dm  'XX'

  db  'R' + $80
  dm  'LCA'

  db  'R' + $80
  dm  'LA'

  db  'R' + $80
  dm  'RCA'

  db  'R' + $80
  dm  'RA'

  db  'D' + $80
  dm  'AA'

  db  'L' + $80 ; Grupa 3: ED+
  dm  'DIR'

  db  'L' + $80
  dm  'DI'

  db  'L' + $80
  dm  'DDR'

  db  'L' + $80
  dm  'DD'

  db  'C' + $80
  dm  'PIR'

  db  'C' + $80
  dm  'PI'

  db  'C' + $80
  dm  'PDR'

  db  'C' + $80
  dm  'PD'

  db  'I' + $80
  dm  'NIR'

  db  'I' + $80
  dm  'NI'

  db  'I' + $80
  dm  'NDR'

  db  'I' + $80
  dm  'ND'

  db  'O' + $80
  dm  'TIR'

  db  'O' + $80
  dm  'UTI'

  db  'O' + $80
  dm  'TDR'

  db  'O' + $80
  dm  'UTD'

  db  'N' + $80
  dm  'EG'

  db  'R' + $80
  dm  'ETI'

  db  'R' + $80
  dm  'ETN'

  db  'R' + $80
  dm  'LD'

  db  'R' + $80
  dm  'RD'

  db  'R' + $80 ; Grupa 4: rotiranje i bit manipulacija
  dm  'LC'

  db  'R' + $80
  dm  'L'

  db  'R' + $80
  dm  'RC'

  db  'R' + $80
  dm  'R'

  db  'S' + $80
  dm  'LA'

  db  'S' + $80
  dm  'RA'

  db  'S' + $80
  dm  'RL'

  db  'B' + $80
  dm  'IT'

  db  'S' + $80
  dm  'ET'

  db  'R' + $80
  dm  'ES'

  db  'A' + $80 ; Grupa 5: aritmentika i logika
  dm  'DD'

  db  'A' + $80
  dm  'DC'

  db  'S' + $80
  dm  'BC'

  db  'S' + $80
  dm  'UB'

  db  'A' + $80
  dm  'ND'

  db  'O' + $80
  dm  'R'

  db  'X' + $80
  dm  'OR'

  db  'C' + $80
  dm  'P'

  db  'I' + $80 ; Grupa 6: INC/DEC
  dm  'NC'

  db  'D' + $80
  dm  'EC'

  db  'L' + $80 ; Grupa 7: Load i exchange
  dm  'D'

  db  'E' + $80
  dm  'X'

  db  'I' + $80 ; Grupa 8: IN/OUT
  dm  'N'

  db  'O' + $80
  dm  'UT'

  db  'D' + $80 ; Grupa 9: Skokovi
  dm  'JNZ'

  db  'J' + $80
  dm  'R'

  db  'J' + $80
  dm  'P'

  db  'C' + $80
  dm  'ALL'

  db  'R' + $80
  dm  'ET'

  db  'R' + $80 ; Grupa 10: RST/IM
  dm  'ST'

  db  'I' + $80
  dm  'M'

  db  'P' + $80 ; Grupa 11: PUSH/POP
  dm  'OP'

  db  'P' + $80
  dm  'USH'

  db  $80

TABEL2:                         ; Operandi
  db  'I' + $80
  dm  'X'
  db  'I' + $80
  dm  'Y'
  db  'A' + $80
  dm  'F'
  db  'B' + $80
  dm  'C'
  db  'D' + $80
  dm  'E'
  db  'H' + $80
  dm  'L'
  db  'S' + $80
  dm  'P'
  db  'B' + $80
  db  'C' + $80
  db  'D' + $80
  db  'E' + $80
  db  'H' + $80
  db  'L' + $80
  db  'A' + $80
  db  'I' + $80
  db  'R' + $80
  db  'N' + $80
  dm  'Z'
  db  'Z' + $80
  db  'N' + $80
  dm  'C'
  db  'C' + $80
  db  'P' + $80
  dm  'O'
  db  'P' + $80
  dm  'E'
  db  'P' + $80
  db  'M' + $80
  db  $80

NASLOV:
  dm '  AF   BC   DE   HL  IXIY SP()'
  db $0d

EXTRA:
  ld    a, (INS1)
  cp    $45                     ; Da li je OPER1 JP?
  ret   z                       ; Vrati se ako jeste
  inc   (hl)
  ret                           ; A ako nije, uvećaj broj bajtova

  .org $1FFF

  db  5                         ; Verzija

  .end
