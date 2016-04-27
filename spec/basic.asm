J       0x80000000
JAL     0x80000000

JALR    r0, r0

JR      r0

BREAK
SYSCALL

SYNC

LB      r0, 0(r0)
LBU     r0, 0(r0)
LD      r0, 0(r0)
LDL     r0, 0(r0)
LDR     r0, 0(r0)
LH      r0, 0(r0)
LHU     r0, 0(r0)
LL      r0, 0(r0)
LLD     r0, 0(r0)
LW      r0, 0(r0)
LWL     r0, 0(r0)
LWR     r0, 0(r0)
LWU     r0, 0(r0)
SB      r0, 0(r0)
SC      r0, 0(r0)
SCD     r0, 0(r0)
SD      r0, 0(r0)
SDL     r0, 0(r0)
SDR     r0, 0(r0)
SH      r0, 0(r0)
SW      r0, 0(r0)
SWL     r0, 0(r0)
SWR     r0, 0(r0)

LUI     r0, 0

MFHI    r0
MFLO    r0

MTHI    r0
MTLO    r0

ADDI    r0, r0, 0
ADDIU   r0, r0, 0
ANDI    r0, r0, 0
DADDI   r0, r0, 0
DADDIU  r0, r0, 0
ORI     r0, r0, 0
SLTI    r0, r0, 0
SLTIU   r0, r0, 0
XORI    r0, r0, 0

ADD     r0, r0, r0
ADDU    r0, r0, r0
AND     r0, r0, r0
DADD    r0, r0, r0
DADDU   r0, r0, r0
DSLLV   r0, r0, r0
DSUB    r0, r0, r0
DSUBU   r0, r0, r0
NOR     r0, r0, r0
OR      r0, r0, r0
SLLV    r0, r0, r0
SLT     r0, r0, r0
SLTU    r0, r0, r0
SRAV    r0, r0, r0
SRLV    r0, r0, r0
SUB     r0, r0, r0
SUBU    r0, r0, r0
XOR     r0, r0, r0

DDIV    r0, r0
DDIVU   r0, r0
DIV     r0, r0
DIVU    r0, r0
DMULT   r0, r0
DMULTU  r0, r0
MULT    r0, r0
MULTU   r0, r0

DSLL    r0, r0, 0
DSLL32  r0, r0, 0
DSRA    r0, r0, 0
DSRA32  r0, r0, 0
DSRAV   r0, r0, r0
DSRL    r0, r0, 0
DSRL32  r0, r0, 0
DSRLV   r0, r0, r0
SLL     r0, r0, 0
SRA     r0, r0, 0
SRL     r0, r0, 0

BEQ     r0, r0, 0x80000000
BEQL    r0, r0, 0x80000000
BNE     r0, r0, 0x80000000
BNEL    r0, r0, 0x80000000

BGEZ    r0, 0x80000000
BGEZAL  r0, 0x80000000
BGEZALL r0, 0x80000000
BGEZL   r0, 0x80000000
BGTZ    r0, 0x80000000
BGTZL   r0, 0x80000000
BLEZ    r0, 0x80000000
BLEZL   r0, 0x80000000
BLTZ    r0, 0x80000000
BLTZAL  r0, 0x80000000
BLTZALL r0, 0x80000000
BLTZL   r0, 0x80000000

TEQ     r0, r0
TGE     r0, r0
TGEU    r0, r0
TLT     r0, r0
TLTU    r0, r0
TNE     r0, r0

TEQI    r0, 0
TGEI    r0, 0
TGEIU   r0, 0
TLTI    r0, 0
TLTIU   r0, 0
TNEI    r0, 0

CFC1    r0, f0
CTC1    r0, f0
DMFC1   r0, f0
DMTC1   r0, f0
MFC0    r0, Index
MFC1    r0, f0
MTC0    r0, Index
MTC1    r0, f0

LDC1    f0, 0(r0)
LWC1    f0, 0(r0)
SDC1    f0, 0(r0)
SWC1    f0, 0(r0)

CACHE   0, 0(r0)

ERET
TLBP
TLBR
TLBWI
TLBWR

BC1F    0x80000000
BC1FL   0x80000000
BC1T    0x80000000
BC1TL   0x80000000

ADD.D   f0, f0, f0
ADD.S   f0, f0, f0
DIV.D   f0, f0, f0
DIV.S   f0, f0, f0
MUL.D   f0, f0, f0
MUL.S   f0, f0, f0
SUB.D   f0, f0, f0
SUB.S   f0, f0, f0

C.EQ.D  f0, f0
C.EQ.S  f0, f0
C.F.D   f0, f0
C.F.S   f0, f0
C.LE.D  f0, f0
C.LE.S  f0, f0
C.LT.D  f0, f0
C.LT.S  f0, f0
C.NGE.D f0, f0
C.NGE.S f0, f0
C.NGL.D f0, f0
C.NGL.S f0, f0
C.NGLE.D    f0, f0
C.NGLE.S    f0, f0
C.NGT.D f0, f0
C.NGT.S f0, f0
C.OLE.D f0, f0
C.OLE.S f0, f0
C.OLT.D f0, f0
C.OLT.S f0, f0
C.SEQ.D f0, f0
C.SEQ.S f0, f0
C.SF.D  f0, f0
C.SF.S  f0, f0
C.UEQ.D f0, f0
C.UEQ.S f0, f0
C.ULE.D f0, f0
C.ULE.S f0, f0
C.ULT.D f0, f0
C.ULT.S f0, f0
C.UN.D  f0, f0
C.UN.S  f0, f0

CVT.D.L f0, f0
CVT.D.S f0, f0
CVT.D.W f0, f0
CVT.L.D f0, f0
CVT.L.S f0, f0
CVT.S.D f0, f0
CVT.S.L f0, f0
CVT.S.W f0, f0
CVT.W.D f0, f0
CVT.W.S f0, f0

ABS.D       f0, f0
ABS.S       f0, f0
CEIL.L.D    f0, f0
CEIL.L.S    f0, f0
CEIL.W.D    f0, f0
CEIL.W.S    f0, f0
FLOOR.L.D   f0, f0
FLOOR.L.S   f0, f0
FLOOR.W.D   f0, f0
FLOOR.W.S   f0, f0
MOV.D       f0, f0
MOV.S       f0, f0
NEG.D       f0, f0
NEG.S       f0, f0
ROUND.L.D   f0, f0
ROUND.L.S   f0, f0
ROUND.W.D   f0, f0
ROUND.W.S   f0, f0
SQRT.D      f0, f0
SQRT.S      f0, f0
TRUNC.L.D   f0, f0
TRUNC.L.S   f0, f0
TRUNC.W.D   f0, f0
TRUNC.W.S   f0, f0
