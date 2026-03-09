; ============================================================================
; gfx/asciitable.asm — ASCII-to-Tile Lookup Table
;
; Must stay in bank 0 since it's accessed with absolute indexed addressing
; (.w,X / .w,Y) which uses the data bank register (DB=0).
;
; 96 entries for ASCII 32 ($20) through 127 ($7F).
; Maps each ASCII code to the corresponding keyboard font tile index.
; Characters without a tile glyph map to 0 (blank).
; Lowercase letters (97-122) map to same tiles as uppercase (1-26).
; ============================================================================

ascii_to_tile:
;       sp   !    "    #    $    %    &    '    (    )    *    +    ,    -    .    /
.db      0, 46,  55,  58,  59,   0,   0,  56,  53,  54,   0,  49,  42,  48,  43,  41
;        0    1    2    3    4    5    6    7    8    9    :    ;    <    =    >    ?
.db     27,  28,  29,  30,  31,  32,  33,  34,  35,  36,  52,  51,   0,  50,   0,  47
;        @    A    B    C    D    E    F    G    H    I    J    K    L    M    N    O
.db     57,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15
;        P    Q    R    S    T    U    V    W    X    Y    Z    [    \    ]    ^    _
.db     16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,   0,   0,   0,   0,  44
;        `    a    b    c    d    e    f    g    h    i    j    k    l    m    n    o
.db      0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15
;        p    q    r    s    t    u    v    w    x    y    z    {    |    }    ~   DEL
.db     16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,   0,   0,   0,   0,   0
