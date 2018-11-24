NASM=nasm -w+orphan-labels -w+macro-params -w+number-overflow -f elf32
STRIP=strip -R .note -R .comment
LD=ld -m elf_i386 -s
RM=rm -f

.PHONY: all clean

all: fb fb-vt

fb: fb.n
	${NASM} -o fb.o fb.n
	${LD} -e fb_start -o fb fb.o
	${STRIP} fb

fb-vt: fb.n
	${NASM} -o fb-vt.o -i ../vt/ -DUSE_VT fb.n
	${LD} -e fb_start -o fb-vt fb-vt.o
	${STRIP} fb-vt

clean:
	${RM} *.bak *~ fb fb.o fb-vt fb-vt.o core
