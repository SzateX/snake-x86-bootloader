[BITS 16]
[ORG 0x7C00]

struc MemoryMap
    .VideoBuffer resw 2000;
    .GameMap resb 2000; ;0xFA0 = B8FA0
    .GameState resb 1; ;B9770
    .Direction resb 1;
    .Seed resw 1;
    .VectorSize resw 1;
    .SnakeData resw 2000; lower = x, high = y;  B977A
endstruc

KEY_UP equ 72;
KEY_DOWN equ 80;
KEY_LEFT equ 75;
KEY_RIGHT equ 77;  
ESCAPE equ 16;

EMPTY equ 0;
FOOD equ 1;
SNAKE equ 2;

init:
    mov ax, 0xb800 ; wpisywanie wartości 0xb800 do rejestru AX
    mov ds, ax ; kopiowanie wartości z AX do rejestru segmentowego DS
    mov bx, MemoryMap_size ; wpisywanie do BX wielkości naszej mapy pamięci
    cli ; wyłączenie przerwań sprzętowych

zero_memory:
	dec bx ; zdekrementuj bx
	mov byte [bx], 0 ; wstaw 0 do pamięci pod adresem DS:BX
	jnz zero_memory ; jeżeli dekrementacja nie dała zera skocz na początek pętli

    mov ah, 0 ; wybranie funkcji 0, przerawnia 0x1A, która pozwala na pobranie wartości zegara
	int 0x1A ; wywołanie przerwania programowego
	mov [MemoryMap.Seed], dx ; pobranie do miejsca przeznaczonego na seed młodszej części 32-bitowej wartości.

    mov word [MemoryMap.GameState], 0x4d01
    ;inc byte [MemoryMap.GameState]
    ;mov byte [MemoryMap.Direction], KEY_RIGHT
    mov byte [MemoryMap.VectorSize], 2
    ;mov word [MemoryMap.SnakeData], 0xc28 ;start position at x=40, y=12
    ;mov word [MemoryMap.SnakeData + 2], 0xc27 ;start position at x= 40, y=12
    mov dword [MemoryMap.SnakeData], 0xc270c28
    ;mov dword [MemoryMap.VideoBuffer + 2 *(12 * 80 + 39)], 0x66206620
    ;mov word [MemoryMap.GameMap + 12 * 80 + 39], 0x0202
    call generateFood
    mov [cs:0x08*4], word timer_handler ; wstawienie wskaźnika do funkcji obsługi przerwania PIT
	mov [cs:0x08*4+2], cs
    mov [cs:0x09*4], word keyboard_handler ; wstawienie wskaźnika do funkcji obsługi przerwania klawiatury
	mov [cs:0x09*4+2], cs
    sti ; włączenie przerwań sprzętowych
	
main:
    hlt ; zaczekanie na nadejście przerwania sprzętowego
    cmp byte [MemoryMap.GameState], 2 ; sprawdzenie czy czasem nie chcemy zresetować gry
    je init ; jeżeli tak to inicjujemy od początku grę
    jmp main ; jeżeli nie to znów czekamy


keyboard_handler:
    pusha ; zabezpiczenie wartości rejestrów ogólnego przeznaczenia
    in al, 0x60 ; odczyt scan code
    cmp al, ESCAPE ; sprawdzenie czy przypadekiem nie chcemy zresetować gry
    jne snake_direction
    mov byte [MemoryMap.GameState], 2
    jmp endOfInterrupt
    
snake_direction:    
    mov bx, cs ; w rejestrze segmentowym ES chcemy mieć wartość segmentu CS
			   ; który wskazuje na ten kod, dzięki temu będzie można dostać się do tablicy z scan code
    mov es, bx
    mov di, keyboard_directions
    mov cx, 4
    repne scasb ; przeskanowanie tablicy
    jne endOfInterrupt ; skok do końca przerwania
    mov bl, al ; weryfikacja próby pójścia snake w przeciwną stronę
    xor bl, [MemoryMap.Direction]
    and bl, 1
    jz endOfInterrupt
	
assign:
    mov [MemoryMap.Direction],  al ; przypisanie wartości

endOfInterrupt:
    mov al, 0x20 ; wysłanie sygnału do kontrolera przerwań, że może zacząć przyjmować kolejne
    out 0x20, al    
    popa ; przywórcenie stanu rejestrów
    iret ; wyjście z funkcji obsługi przerwań

timer_handler:
    int 0x70 ; zachowanie kompatybilności z oryginalnym przerwaniem
    inc word [cs:0x46c]
	
    cmp byte [MemoryMap.GameState], 1 ; sprawdzenie stanu gry
    jne eoi ; jeżeli nie jesteśmy w trybie grania odpuszczamy wykonywanie reszty kodu i wychodzimy z przerwania

    mov bx, [MemoryMap.SnakeData] ; ładowanie współrzędnych głowy
    mov al, [MemoryMap.Direction] ; ładowanie kierunku
    cmp byte al, KEY_UP ; idziemy w górę
    jne $+4
    dec bh
    cmp byte al, KEY_DOWN ; idziemy w dół
    jne $+4
    inc bh
    cmp byte al, KEY_LEFT ; idziemy w lewo
    jne $+4
    dec bl
    cmp byte al, KEY_RIGHT ; idziemy w prawo
    jne $+4
    inc bl

    ; sprawdzenie granic planszy
    cmp bl, 80
    jae lose
    cmp bh, 25
    jae lose

    ; Sprawdzenie planszy
    mov al, 80
    mov cx, bx
    mul ch
    xor ch, ch
    add ax, cx
    mov si, ax
    
    cmp byte [si + MemoryMap.GameMap], SNAKE ; jeżeli natrafiliśmy na fragment węża, to przegrywamy
    je lose
    
    cmp byte [si + MemoryMap.GameMap], FOOD ; jeżeli natrafiliśmy na jedzenie to nie potrzebujemy "skracać węża"
    je eatfood

	; wylicznie odpowiedniego bajtu zawietającego ogon węża.
    mov di, [MemoryMap.VectorSize]
    shl di, 1 ; krótszy sposób na pomnośzenie liczby razy 2 - przesuń bitowo liczbę w lewą stronę.
    mov cx, [MemoryMap.SnakeData + di - 2]
    mov al, 80 ; Offset = 80 * współrzędna y + współrzędna x
    mul ch
    xor ch, ch
    add ax, cx
    mov di, ax ; w DI znajduje się teraz odpowiedni offset w mapie gry.

    mov byte [di + MemoryMap.GameMap], EMPTY
    dec word [MemoryMap.VectorSize] ; usunięcie ostatniej wartości z wektora to w naszym przypadku zapomnienie o tej wartości.
	                                ; dzięki temu zabiegowi będzie można dodać bezpiecznie do początku wektora nową wartość głowy.
    jmp grow_snake

eatfood:
    call generateFood


grow_snake:
    mov cx, [MemoryMap.VectorSize]
    mov di, cx
    shl di, 1
; przesuwanie wartości w wektorze o pozycję dalej
copy_loop:    
    cmp cx, 0
    je insert
    mov ax, word [MemoryMap.SnakeData + di - 2]
    mov [MemoryMap.SnakeData + di], ax
    sub di, 2
    loop copy_loop

; wstawianie nowej głowy
insert:    
    mov [MemoryMap.SnakeData], bx
    inc word [MemoryMap.VectorSize]
    mov byte [MemoryMap.GameMap + si], SNAKE

; przygotowanie odpowiednich wartości
    mov cx, 80*25 ; licznik mówiący o liczbie komórek
    mov si, MemoryMap.GameState - 1 ; wskaźnik na ostatni element z mapy gry
    mov di, MemoryMap.GameMap - 2 ; wskaźnik na ostatni element bufora karty graficznej

    xor bx, bx ; wyzerowanie rejestru bx
    mov dx, 0x0020 ; przygotowanie znaku spacji
draw:
    mov bl, [si] ; pobranie z aktualnego miejsca mapy gry stanu komórki
    mov dh, [cs:bx+sprites] ; znalezienie odpowiedniego koloru duszka
    mov word [di], dx ; rysujemy na buforze odpowiedni znak
    dec si ; przesuwamy wskaźniki o indeks niżej
    sub di, 2

    loop draw
	
eoi:  
    iret

lose:
    mov byte [MemoryMap.GameState], 0 ; ustawienie odpowiedniego stanu
    xor ax, ax ; przygotowanie wartości potrzebnych dla funkcji BIOS
    mov es, ax ; wskazanie na napis
    mov bp, lost_string
    mov ax, 0x1300 ; wskazanie, że wykonujemy funkcję 0x12h (wypisz napis) oraz tryb zapisu
    mov bx, 0xc ; zapis na pierwszej stronie (BH) oraz użyczie czerwonego koloru z czarnym tle (BL)
    mov cx, 8 ; długośc napisu
    mov dx, 0 ; wypisz w pierwszej kolumnie i pierwszym wierszu
    int 10h ; wywołaj przerwanie programowe
    iret ; wyjdź z przerwania zegara

random:
    push dx ; wrzucenie wartości rejestrów na stos (zabezpieczenie ich wartości)
    push cx
    mov ax, [MemoryMap.Seed] ; pobranie seeda do rejestru AX
	mov dx, 7993 ; wpisanie do rejestrów DX i CX wybranych arbitralnie liczb pierwszych
	mov cx, 9781
	mul dx ; mnożenie AX przez DX - wynik wylądował w rejestrach DX (starsze 2 bajty) i AX (młodsze 2 bajty)
	add ax, cx ; nie potrzebna jest nam wartość DX, dlatego dodałem do rejestru AX rejestr CX 
	mov [MemoryMap.Seed], ax ; zapisanie nowego seeda
    pop cx ; przywrócenie wartości rejestrów z stosu
    pop dx
    ret ; wyjście z funkcji

generateFood:
    pusha ; zabezpiczenie wszystkich rejestrów ogólnego przeznaczenia
generation_loop: 
    call random ; zawołanie funkcji losującej
    xor dx, dx ; wyzerowanie rejestru DX
    mov cx, 80 ; wykonanie operacji: rejestr BL = wylosowana wartość % szerokość ekranu 
    div cx ; w tym przypadku div weźmie połączenie rejestrów DX z AX i podzieli przez rejestr CX
    mov bl, dl ; reszta z dzielenia znajduje się w rejestrze DX ale my wiemy, że 80 mieści się w jednym bajcie, to możemy pobrać tylko młodszą część.
			   ; stanowi to pozycję x na ekranie.
    call random ; zawołanie ponownie funkcji losującej 
    xor dx, dx ; wykonanie operacji: rejestr DL = wylosowana wartosc % wysokosc
    mov cx, 25
    div cx ; wynik wylądował w rejestrze DL - jest to pozycja y
    mov al, 80 ; teraz potrzebujemy policzyć, który bajt odpowiada w nasze mapie gry odpowiada za wylosowane współrzędne
    mul dl ; rejestr AX = al * dl - czyli 80 * pozycja y
    xor bh, bh ; wyzeruj rejestr BH jeżeli znalazłyby się tam jakieś śmieci.
    add ax, bx ; dodaj wartość pozycji x do rejestru ax
    mov di, ax; przekopiuj wynik do rejestru di - jest to offset w naszej mapie gry
    cmp byte [di + MemoryMap.GameMap], SNAKE; sprawdź czy wąż znajduje się na tej pozycji
    je generation_loop ; jeżeli tak to powtórz generowanie
    mov byte [di + MemoryMap.GameMap], FOOD ; jeżeli nie to wstaw tam jedzenie
    popa ; przywróć rejestry
    ret ; wyjdź z funkcji

lost_string:
db 'You lose'
keyboard_directions:
db KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN
sprites:
db 0, 0x22, 0x66

;times 510-($-$$) db 0
;dw 0AA55h