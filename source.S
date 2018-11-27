.text
.global main

.intel_syntax noprefix

.equ true, 1
.equ false, 0



#define mat0  xmm0,  xmm1, xmm2, xmm3
#define mat4  xmm4,  xmm5, xmm6, xmm7
#define mat8  xmm8,  xmm9, xmm10, xmm11
#define mat12 xmm12, xmm13, xmm14, xmm15




.macro matload a, b, c, d, src # load from src to a b c d
	movaps \a, [\src]
	movaps \b, [\src+0x10]
	movaps \c, [\src+0x20]
	movaps \d, [\src+0x30]
.endm

.macro matstor dst, a, b, c, d # store a b c d in dst 
	movaps [\dst], \a
	movaps [\dst+0x10], \b
	movaps [\dst+0x20], \c
	movaps [\dst+0x30], \d
.endm

.macro matload_ups a, b, c, d, src # load from src to a b c d
	movups \a, [\src]
	movups \b, [\src+0x10]
	movups \c, [\src+0x20]
	movups \d, [\src+0x30]
.endm

.macro matstor_ups dst, a, b, c, d # store a b c d in dst 
	movups [\dst], \a
	movups [\dst+0x10], \b
	movups [\dst+0x20], \c
	movups [\dst+0x30], \d
.endm

.macro matcopy da, db, dc, dd, sa, sb, sc, sd
	movaps \da, \sa
	movaps \db, \sb
	movaps \dc, \sc
	movaps \dd, \sd
.endm

.macro matadd da, db, dc, dd, sa, sb, sc, sd
	addps \da, \sa
	addps \db, \sb
	addps \dc, \sc
	addps \dd, \sd
.endm

.macro matsub da, db, dc, dd, sa, sb, sc, sd
	subps \da, \sa
	subps \db, \sb
	subps \dc, \sc
	subps \dd, \sd
.endm

.macro ident   da, db, dc, dd
	movups \da, ident0
	movups \db, ident1
	movups \dc, ident2
	movups \dd, ident3
.endm

.macro scalmat da, db, dc, dd, sx, sy, sz
	movss    \da, \sx
	insertps \db, \sy, 0x1E
	insertps \dc, \sz, 0x2D
	movups \dd, ident3
.endm

#get sin of single element of xmm register
.macro sin dst, src
	fst \src
	fsin
	fstp \dst
.endm

#get cos of single element of xmm register
.macro cos dst, src
	fst \src
	fcos
	fstp \dst
.endm

#sum all components in an xmm
.macro sumxmm   dst, src, tmp
    movshdup    \tmp, \src
    addps       \dst, \tmp
    movhlps     \tmp, \dst
    addss       \dst, \tmp
.endm


# get dot product of 2 xmm registers
.macro dot dst, src
	dpps dst, src, 0xFF
.endm

.macro veclen dst, src
	dot \dst, \src
	sqrtss \dst, \dst 
.endm

# normalize an xmm register
.macro normalize dst, src, tmp
	movaps  \tmp, \src
	movaps  \dst, \src
	dot     \tmp, \tmp
	rsqrtps \tmp, \tmp
	mulps   \dst, \tmp
.endm

#http://fastcpp.blogspot.com/2011/04/vector-cross-product-using-sse-code.html
#_mm_sub_ps(
#    _mm_mul_ps(_mm_shuffle_ps(a, a, _MM_SHUFFLE(3, 0, 2, 1)), _mm_shuffle_ps(b, b, _MM_SHUFFLE(3, 1, 0, 2))), 
#    _mm_mul_ps(_mm_shuffle_ps(a, a, _MM_SHUFFLE(3, 1, 0, 2)), _mm_shuffle_ps(b, b, _MM_SHUFFLE(3, 0, 2, 1)))
.macro cross dst, src, tmp
	movaps \src, \tmp
	
.endm

.macro rotmatX da, db, dc, dd, theta
	movups \da, ident0
	insertps \db, \sy, 0x1E
	insertps \db, \sz, 0x2D
	movups \dd, ident3
.endm

.macro transmat da, db, dc, dd, transv
	ident \da, \db, \dc, \dd 
	movaps \transv
.endm

# switches matrices from column major (opengl) to row major (directx) and back
.macro matTranspose a, b, c, d, temp1, temp2, temp3, temp4
	movaps   \temp1, \a
	movaps   \temp2, \c
	movaps   \temp3, \a
	movaps   \temp4, \c
	unpcklps \temp1, \b
	unpcklps \temp2, \d
	unpckhps \temp3, \b
	unpckhps \temp4, \d
	
	movaps   \a, \temp1
	movaps   \b, \temp1
	movaps   \c, \temp3
	movaps   \d, \temp3
	movhlps  \b, \temp2
	movlhps  \a, \temp2
	movlhps  \c, \temp4
	movhlps  \d, \temp4
.endm

# assumes the 4x4 is already transposed
# can be simplified with a multiply-add instruction
# see here: https://www.felixcloutier.com/x86/VFMADD132PS:VFMADD213PS:VFMADD231PS.html
# testing sequential vs parallel instructions...
.macro matmul_4x4_4x1 dst, a, b, c, d, vec, temp1, temp2, temp3, temp4
	movaps \dst,   \vec
	movaps \temp1, \vec
	movaps \temp2, \vec
	movaps \temp3, \vec
	mulps  \dst,   \a
	mulps  \temp1, \b
	mulps  \temp2, \c
	mulps  \temp3, \d
	addps  \dst,   \temp1
	addps  \temp2, \temp3
	addps  \dst,   \temp2
.endm

# args are row-major
# mat0 *= mat4
matmul_4x4_4x4:
	sub rsp, 0x48
	matstor rsp, mat4
	sub rsp, 0x40
	matstor rsp, mat8
	sub rsp, 0x40
	matstor rsp, mat12
	
	#matload 
	# matTranspose              mat0,  mat8
	# mat8 = mat0 * mat4
	matmul_4x4_4x1 xmm8,  mat0, xmm4, mat12
	matmul_4x4_4x1 xmm9,  mat0, xmm5, mat12
	matmul_4x4_4x1 xmm10, mat0, xmm6, mat12
	matmul_4x4_4x1 xmm11, mat0, xmm7, mat12
	# mat0 = mat8
	matcopy mat0, mat8
	
	matload mat12, rsp
	add rsp, 0x40
	matload mat8,  rsp
	add rsp, 0x40
	matload mat4, rsp
	add rsp, 0x48
	
    ret
	
	




printstr:
	sub rsp, 0x8

	mov rdi, rax
	call puts 

	add rsp, 0x8
	ret
	
printint:
	sub rsp, 0x8

	mov rdi, OFFSET intformat
	mov rsi, rax
	mov rax, 0x0
	call printf

	add rsp, 0x8
	ret

printxmm0int:
	sub rsp, 0x18
	movups [rsp], xmm0
	mov rdi, OFFSET xmm0formatint
	xor rsi, rsi
	mov esi, [rsp]
	xor rdx, rdx
	mov edx, [rsp+4]
	xor rcx, rcx
	mov ecx, [rsp+8]
	xor r8, r8
	mov r8d, [rsp+12]

	mov rax, 0x0
	call printf

	add rsp, 0x18
	ret

.macro pushall
	push rax
	push rbx
	push rcx
	push rdx
	push rsp
	push rsi
	push rbp
	push rdi
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
.endm

.macro popall
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdi
	pop rbp
	pop rsi
	pop rsp
	pop rdx
	pop rcx
	pop rbx
	pop rax
.endm

printxmm0flt:
	sub rsp, 0x300
	pushall
	sub rsp, 0x338

	fxsave [rsp+0x30]


	movups [rsp+0x10], xmm0
	movss xmm0, [rsp+0x10]
	movss xmm1, [rsp+0x14]
	movss xmm2, [rsp+0x18]
	movss xmm3, [rsp+0x1C]
	
	mov rdi, OFFSET xmm0formatflt
	cvtss2sd xmm0, xmm0
	cvtss2sd xmm1, xmm1
	cvtss2sd xmm2, xmm2
	cvtss2sd xmm3, xmm3

	mov rax, 0x4
	call printf

	fxrstor [rsp+0x30]

	add rsp, 0x338
	popall
	add rsp, 0x300
	ret

#pass arg as 4 floats in xmm0, answer in eax
xmm2packed8888:
	sub rsp, 0x528
	movups xmm1, normMul
	mulps xmm0, xmm1
	cvtps2dq xmm0, xmm0

	movups [rsp], xmm0
    
	xor rax, rax

	mov al, [rsp]
	shl rax, 8
	mov al, [rsp+4]
	shl rax, 8
	mov al, [rsp+8]
	shl rax, 8
	mov al, [rsp+12]
	
	add rsp, 0x528
	ret

#dst, xmm, xmm, xmm
#uses xmm7
#call shufps arg3, arg3, 0x00 to have it be just one value that's mixed  
.macro mixxmm a, b, c, d
	movups xmm7, fltOnes

	subps  xmm7, \d
	movaps \a,   \c
	mulps  \a,   xmm7
	
	movaps xmm7, \b
	mulps  xmm7, \d
	addps  \a,   xmm7
.endm

#3 is the temp
.macro swapxmm a, b, c
	movaps \c, \a
	movaps \a, \b
	movaps \b, \c
.endm

.macro swapxmm_mem a, b, c, d
	movaps \c, \a
	movaps \d, \b
	movaps \b, \c
	movaps \a, \d
.endm

.macro fabs a, temp
	movups \temp, fltAbsMask
	andps \a, \temp
.endm	

# rdi: bool topdown
# xmm0: pos1 (should be [ (0,0,X,1), (width,height,X,1) ]
# xmm1: pos2
# xmm2: pos3
# push pos3  [rbp+0x90]
# push pos2  [rbp+0x80]
# push pos1  [rbp+0x70]
# push norm3 [rbp+0x60]
# push norm2 [rbp+0x50]
# push norm1 [rbp+0x40]
# push col3  [rbp+0x30]
# push col2  [rbp+0x20]
# push col1  [rbp+0x10]
raster:
	push rbp
	mov rbp, rsp

	sub rsp, 0x120
	pushall

	movaps [rbp+0x90], xmm2
	movaps [rbp+0x80], xmm1
	movaps [rbp+0x70], xmm0
	
raster_do2ndswap:
	#set dy, and prepare for a swap
	cmp rdi, 1
	je raster_topdown
		#bottom up
		mov r9, 1

		movss xmm3, [rbp+0x84] # b.y
		movss xmm4, [rbp+0x94] # c.y

		movss xmm5, [rbp+0x74] # a.y
		movss xmm6, [rbp+0x74] # a.y
		
	jmp raster_extopdown
	raster_topdown:
		mov r9, -1    # dy

		movss xmm3, [rbp+0x74] # a.y
		movss xmm4, [rbp+0x74] # a.y

		movss xmm5, [rbp+0x84] # b.y
		movss xmm6, [rbp+0x94] # c.y

	raster_extopdown:
	
	comiss xmm3, xmm5
	jnc raster_noswap1
		swapxmm  xmm0, xmm1, xmm3
	
		movaps [rbp+0x90], xmm2
		movaps [rbp+0x80], xmm1
		movaps [rbp+0x70], xmm0

		#swapxmm_mem [rbp+0x40], [rbp+0x50], xmm10, xmm11
		#swapxmm_mem [rbp+0x10], [rbp+0x20], xmm10, xmm11

		jmp raster_do2ndswap
	raster_noswap1:

	comiss xmm4, xmm6
	jnc raster_noswap2
		swapxmm  xmm0, xmm2, xmm3
	
		movaps [rbp+0x90], xmm2
		movaps [rbp+0x80], xmm1
		movaps [rbp+0x70], xmm0

		#swapxmm_mem [rbp+0x40], [rbp+0x60], xmm10, xmm11
		#swapxmm_mem [rbp+0x10], [rbp+0x30], xmm10, xmm11

		jmp raster_do2ndswap
	raster_noswap2:
	
	movaps [rbp+0x90], xmm2
	movaps [rbp+0x80], xmm1
	movaps [rbp+0x70], xmm0


	movaps   xmm3, xmm1
	subps    xmm3, xmm0
	movaps   xmm4, xmm2
	subps    xmm4, xmm0
	movaps   xmm6, xmm3
	unpcklps xmm3, xmm4
	unpckhps xmm6, xmm4
	movhlps  xmm4, xmm3
	divps    xmm3, xmm4
	divps    xmm6, xmm4
	movlhps  xmm3, xmm6 # move higher bits of xmm6 to xmm3
	 
	cvtsi2ss xmm5, r9d	# convert r9d to a float
	shufps  xmm5, xmm5, 0x00   # put it in all 4 positions
	movaps  [rbp-0x10], xmm5 # throw this on the stack for future use
	
	mulps  xmm3, xmm5      
	movaps [rbp-0x20], xmm3 # mb, mc, mdb, mdc

	movss  xmm4, [rbp-0x20]
	movss  xmm5, [rbp-0x1C]
	comiss xmm4, xmm5
	jc rasternoswap_mbc     # make sure mb < mc (b should be the left point, c will be the right) 

		swapxmm  xmm1, xmm2, xmm3

		#swapxmm_mem [rbp+0x50], [rbp+0x60], xmm10, xmm11
		#swapxmm_mem [rbp+0x20], [rbp+0x30], xmm10, xmm11

		movaps   xmm6, [rbp-0x20]
		shufps   xmm6, xmm6, 0xB1
		movaps   [rbp-0x20], xmm6

	rasternoswap_mbc:
	
	movaps [rbp+0x90], xmm2
	movaps [rbp+0x80], xmm1
	
	
	# todo: add ceils here if time permits
	cmp rdi, 1
	je raster_topdown2
		#bottom up
		#compute y_start
		movss    xmm7, fltZeros
		maxss    xmm7, [rbp+0x74]
		cvtss2si eax, xmm7
		mov      [rbp-0x30], eax # y_start

		#compute y_end
		movss    xmm7, winHeight2
		minss    xmm7, [rbp+0x84]
		minss    xmm7, [rbp+0x94]
		cvtss2si eax, xmm7
		mov      [rbp-0x2C], eax # y_end
	jmp raster_extopdown2
	raster_topdown2:
		#top down
		#compute y_start
		movss    xmm7, winHeight2
		minss    xmm7, [rbp+0x74]
		cvtss2si eax, xmm7
		mov      [rbp-0x30], eax  # y_start

		#compute y_end
		movss    xmm7, fltZeros
		maxss    xmm7, [rbp+0x84]
		maxss    xmm7, [rbp+0x94]
		cvtss2si eax, xmm7
		mov      [rbp-0x2C], eax  # y_end
	raster_extopdown2:
	
	# # compute mid_dist
	# movss xmm6, [rbp-0x74] # xmm6 =  [0].y
	# subss xmm6, [rbp-0x34] # xmm6 -= y_end
	# fabs  xmm6, xmm7       # xmm6 = |xmm6|

	#		float mcfalph = 1.f / glm::abs(a.y - b.y);
	#		float mcfbeta = 1.f / glm::abs(a.y - c.y);
	movss xmm3, [rbp+0x74]
	movss xmm6, xmm3	
	movss xmm4, [rbp+0x84]
	movss xmm5, [rbp+0x94]

	subss xmm3, xmm4
	subss xmm6, xmm5
	
	fabs  xmm3, xmm7
	fabs  xmm6, xmm7
	
	rcpss xmm3, xmm3
	rcpss xmm6, xmm6

	movss [rbp-0x40], xmm3 # mcfalph
	movd  eax, xmm6
	mov [rbp-0x3C], eax # mcfbeta

	# compute ayDist
	mov       eax, [rbp-0x30] # y_start
	cvtsi2ss  xmm4, eax
	subss     xmm4, [rbp+0x74] # - a.y
	mulss     xmm4, [rbp-0x10] # * dy
	maxss     xmm4, fltZeros
	shufps    xmm4, xmm4, 0x00
	movaps    [rbp-0x100], xmm4 # ayDist

	# compute starting bx cx bz cz
	movaps xmm3, xmm0
	shufps xmm3, xmm3, 0xA0
	mulps  xmm4, [rbp-0x20]   # aydist * mb mc mdb mdc
	addps  xmm4, xmm3         # + ax ax az az
	movaps [rbp-0x50], xmm4  # bx cx bz cz

	movaps xmm4, [rbp-0x100]
	# compute starting alpha, beta
	mulps  xmm4, [rbp-0x40]
	movups xmm5, fltOnes
	subps  xmm5, xmm4
	movaps [rbp-0x60], xmm5 # alpha, beta
	
	xor    r8,  r8
	mov    r8d, [rbp-0x30]  # y, the counter

	raster_yloop:
		#	// This is here so we can draw the middle line properly

		xor rsi, rsi		

		#todo: round, don't floor
		movss    xmm3, [rbp-0x50]
		movss    xmm4, [rbp-0x4C]
		maxss    xmm3, fltZeros    # xstart (float)   
		minss    xmm4, winWidth2   
		cvtss2si esi, xmm3         # xstart (int)
		cvtss2si r11d, xmm4         # xend   (int) 

		movss    xmm6, [rbp-0x4C]
		subss    xmm6, [rbp-0x50]  
		rcpss    xmm6, xmm6        # gamma step

		movss    xmm7, [rbp-0x44]
		subss    xmm7, [rbp-0x48]
		mulss    xmm7, xmm6        # z step

		movss    xmm8, xmm3
		subss    xmm8, [rbp-0x50]  # bxDist
		
		movss    xmm9, xmm8
		mulss    xmm9, xmm6
		addss    xmm9, [rbp-0x48]  # starting z

		mulss    xmm8,  xmm6
		movss    xmm10, fltOnes
		subss    xmm10, xmm8
		movss    xmm8,  xmm10      # starting gamma (overwrites bxDist)

		movss    xmm10, [rbp-0x60] # alpha
		movss    xmm11, [rbp-0x5C] # beta
		movss    xmm12, xmm10
		subss    xmm12, xmm11      # alpha-beta
		movss    xmm13, fltOnes
		subss    xmm13, xmm10      # 1-alpha
		movss    xmm14, fltOnes
		subss    xmm14, xmm11      # 1-beta

		mov      r10d,  winWidth
		xor      rdx,   rdx
		mov      edx,   esi        # x = xstart
		xor  rax, rax

		mov  rbx, globalPixelBufPtr

		raster_xloop:
			
			
			mov  eax, r8d						

			
			movss xmm3, xmm8
			movss xmm4, xmm8
			movss xmm5, fltOnes

			mulss xmm3, xmm12
			mulss xmm4, xmm13
			subss xmm5, xmm8

			addss xmm3, xmm11
			mulss xmm5, xmm14

			mulss xmm4, normMul
			mulss xmm3, normMul
			mulss xmm5, normMul
			cvtss2si r12d, xmm3
			cvtss2si r13d, xmm4
			cvtss2si r14d, xmm5
			mov r15d, 255

			movaps xmm0, [rbp+0x20]

			
			push rax
			call xmm2packed8888
			mov r15d, eax
			pop rax	
			mov r15b, 255
	
			#mov  [rbx+rax*4], r15d
			
			#mov cl, r15b
			#shl ecx, 8
			#or cl, r14b
			#shl ecx, 8
			#or cl, r13b
			#shl ecx, 8
			#or cl, r12b
			#shl ecx, 8

			imul eax, r10d
			add  eax, edx

			cmp r8d, 0
			jle raster_skipy

			cmp r8d, winHeight
			jge raster_skipy
			

			mov  [rbx+rax*4], r15d

			subss xmm8, xmm6
			addss xmm9, xmm7

			inc edx			
			cmp edx, r11d
			jle raster_xloop
		
		raster_skipy:		

		movaps   xmm3, [rbp-0x50]
		addps    xmm3, [rbp-0x20]
		movaps   [rbp-0x50], xmm3

		movaps   xmm3, [rbp-0x60]
		subps    xmm3, [rbp-0x40]
		movaps   [rbp-0x60], xmm3

		
		add      r8d,  r9d         # y += dy

		cmp rdi, 1
		je raster_topdown3
			cmp r8d, [rbp-0x2C]   # y <= y_end
			jle raster_yloop
			jmp raster_exityloop
		raster_topdown3:
			cmp r8d, [rbp-0x2C]   # y >= y_end
			jge raster_yloop
			jmp raster_exityloop
			
	
raster_exityloop:

	popall

	mov rsp, rbp
	pop rbp

	





	ret









#screw the stack up ~~a little~~ quite a bit, don't reference stack variables relative to rsp
align:
	mov rax, [rsp]
	and rsp, 0xFFFFFFFFFFFFFFF0
	jmp rax


inittexture:
	sub rsp, 0x8

	mov rdi, globalRendererPtr
	mov rsi, 373694468         # SDL_PIXELFORMAT_RGBA8888
	mov rdx, 1                 # SDL_TEXTUREACCESS_STREAMING
	mov rcx, winWidth
	mov r8, winHeight
	call SDL_CreateTexture
	mov globalTexturePtr, rax

	call SDL_GetError
	call printstr

	mov rcx, winHeight
	mov rdi, winWidth
	imul rdi, rcx  
	lea rdi, [rdi*4]
	mov pixelBufSize, rdi
	call malloc
	mov globalPixelBufPtr, rax
	
	add rsp, 0x8
	ret

#rdi is clear color
clearwindow:
	mov rax, pixelBufSize
	
	mov rbx, globalPixelBufPtr 
	lea rcx, [rbx+rax]
clearwindow_while:
	mov [rbx], rdi
	add rbx, 4
	cmp rbx, rcx
	jl clearwindow_while
	
	ret

# [x + y * width] = color
# [rdi + rsi * winWidth] = rdx
drawpixel:
	imul rsi, winWidth
	add rdi, rsi
	mov rax, globalPixelBufPtr
	mov [rax+rdi*4], rdx
	ret
		
# SDL_UpdateTexture(framebuffer , NULL, pixels, width * sizeof (uint32_t));
#
# SDL_RenderClear(renderer);
# SDL_RenderCopy(renderer, framebuffer , NULL, NULL);
# SDL_RenderPresent(renderer);
switchbuffers:
	sub rsp, 0x8

	mov rdi, globalTexturePtr
	mov rsi, 0
	mov rdx, globalPixelBufPtr
	mov rcx, winWidth
	lea rcx, [rcx*4]
	call SDL_UpdateTexture

	mov rdi, globalRendererPtr
	call SDL_RenderClear
	
	mov rdi, globalRendererPtr
	mov rsi, globalTexturePtr
	mov rdx, 0
	mov rcx, 0
	call SDL_RenderCopy

	mov rdi, globalRendererPtr
	call SDL_RenderPresent	

	add rsp, 0x8
	ret

main:
	mov rbp, rsp
	call align
	mov rdi, 0x20 # SDL_INIT_VIDEO
	call SDL_Init

	mov rax, winWidth
	call printint
	mov rax, winHeight
	call printint

	mov rdi, winWidth
	mov rsi, winHeight
	mov rdx, 0x0
	mov rcx, OFFSET globalWindowPtr
	mov r8, OFFSET globalRendererPtr
	call SDL_CreateWindowAndRenderer

	call inittexture




	#mov rdi, OFFSET winTitle # Title
	#mov rsi, 0x2FFF0000      # SDL_WINDOWPOS_CENTERED
	#mov rdx, 0x2FFF0000      # SDL_WINDOWPOS_CENTERED
	#mov rcx, winWidth        # Width
	#mov r8,  winHeight       # Height
	#mov r9,  0x0             # Flags
	#call SDL_CreateWindow

	#mov window, rax

	call SDL_GetError
	call printstr
	

mainLoop:
	
	mov rdi, 0xFF00FFFF
	call clearwindow

	mov rdi, 100
	mov rsi, 100
	mov rdx, 0xFF0000FF
	call drawpixel

	lea rax, vertexbuffer
	lea rcx, objects
	mov rdi, 0
	mov rbx, curobject
	add rcx, 8
	looptillobjectfound:
		add rdi, 1
		cmp rdi, rbx
		jge exitlooptillobjectfound

		mov rsi, [rcx]
		imul rsi, 72
		add rax, rsi
		add rcx, 8
		jmp looptillobjectfound
	exitlooptillobjectfound:

	lea rcx, objects
	lea rcx, [rcx+rbx*8+8]

	mov rsi, 0
	mov r8, [rcx]

	renderobject:
		push [rax+0x8]
		push [rax]
		push [rax+0x18]
		push [rax+0x10]
		push [rax+0x28]
		push [rax+0x20]
		push [rax+0x38]
		push [rax+0x30]
		push [rax+0x48]
		push [rax+0x40]
		push [rax+0x58]
		push [rax+0x50]
		push [rax+0x68]
		push [rax+0x60]
		push [rax+0x78]
		push [rax+0x70]
		push [rax+0x88]
		push [rax+0x80]
		movups xmm8, [rax]
		movups xmm9, [rax+24]
		movups xmm10, [rax+48]
		matload_ups mat4 _scalemat
		matmul_4x4_4x1 xmm0, mat4, xmm8, mat12
		matmul_4x4_4x1 xmm1, mat4, xmm9, mat12
		matmul_4x4_4x1 xmm2, mat4, xmm10, mat12
		#call printxmm0flt

		movups xmm11, fltZeros	
		movups xmm12, fltOnes	

		movups xmm8, [rax+12]
		fabs xmm8, xmm15
		minps xmm8, xmm12
		maxps xmm8, xmm11
		movups xmm9, [rax+36]
		fabs xmm9, xmm15
		minps xmm9, xmm12
		maxps xmm9, xmm11
		movups xmm10, [rax+60]
		fabs xmm10, xmm15
		minps xmm10, xmm12
		maxps xmm10, xmm11

		movups [rsp], xmm8
		movups [rsp-0x10], xmm9
		movups [rsp-0x20], xmm10

		mov rdi, 1
		call raster

		movups xmm8, [rax]
		movups xmm9, [rax+24]
		movups xmm10, [rax+48]
		matload_ups mat4 _scalemat
		matmul_4x4_4x1 xmm0, mat4, xmm8, mat12
		matmul_4x4_4x1 xmm1, mat4, xmm9, mat12
		matmul_4x4_4x1 xmm2, mat4, xmm10, mat12
		mov rdi, 0
		call raster
		add rsp, 0x90
		add rax, 72

		inc rsi
		cmp rsi, r8
		jl renderobject
	# rdi: bool topdown
	# xmm0: pos1 (should be [ (0,0,X,1), (width,height,X,1) ]
	# xmm1: pos2
	# xmm2: pos3
	# push pos3  [rbp+0x90]
	# push pos2  [rbp+0x80]
	# push pos1  [rbp+0x70]
	# push col3  [rbp+0x60]
	# push col2  [rbp+0x50]
	# push col1  [rbp+0x40]
	# push norm3 [rbp+0x30]
	# push norm2 [rbp+0x20]
	# push norm1 [rbp+0x10]




















eventLoop:
	
	
	mov rdi, OFFSET eventToProcess
	call SDL_PollEvent
	
	cmp al, false
	je endEventLoop
	

	mov eax, eventToProcess
	cmp eax, 0x100               # SDL_QUIT
	
	jne eventswitch_keyEvent	
		mov ebx, 0
		mov running, ebx
		jmp eventLoop

	eventswitch_keyEvent:

	cmp eax, 0x300              # SDL_KeyEvent	
	jne eventswitch_default
		mov ebx, eventToProcess+16
		mov eax, ebx
		call printint
		cmp ebx, 41  # SDL_SCANCODE_ESCAPE		
		jne keypress_default
			mov ebx, 0
			mov running, ebx
			jmp eventLoop
		keypress_default:
		

			jmp eventLoop
	
	eventswitch_default:

	

endEventLoop:
	
	


	call switchbuffers

	


	mov eax, running
	cmp eax, false
	jne mainLoop

	# DESTROY HER
	mov rdi, globalTexturePtr
	call SDL_DestroyTexture
	mov rdi, globalRendererPtr
	call SDL_DestroyRenderer
	mov rdi, globalWindowPtr 
	call SDL_DestroyWindow 

	call SDL_Quit

	jmp quit

quit:
	mov rax, 60
	mov rdi, 0
	syscall

.data
	hardcodedtri: .float 100,130,1,0, 150,300,3,0, 260,120,2,0,  0,0,-1,0, 0,0,-1,0, 0,0,-1,0,  1,0,0,1, 0,1,0,1, 0,0,1,1 

	objects: .quad 2, 12, 20
	curobject: .quad 1
	vertexbuffer: .float -0.500, -0.500, -0.500,  0.000,  0.000, -1.000,-0.500,  0.500, -0.500,  0.000,  0.000, -1.000, 0.500,  0.500, -0.500,  0.000,  0.000, -1.000, 0.500,  0.500, -0.500,  0.000, -0.000, -1.000, 0.500, -0.500, -0.500,  0.000, -0.000, -1.000,-0.500, -0.500, -0.500,  0.000, -0.000, -1.000,-0.500, -0.500, -0.500,  0.000, -1.000,  0.000, 0.500, -0.500, -0.500,  0.000, -1.000,  0.000, 0.500, -0.500,  0.500,  0.000, -1.000,  0.000, 0.500, -0.500,  0.500, -0.000, -1.000,  0.000,-0.500, -0.500,  0.500, -0.000, -1.000, 0.000,-0.500, -0.500,-0.500, -0.000, -1.000,  0.000,-0.500, -0.500, -0.500, -1.000,  0.000,  0.000,-0.500, -0.500,  0.500, -1.000,  0.000,  0.000,-0.500,  0.500,  0.500, -1.000,  0.000,  0.000,-0.500,  0.500,  0.500, -1.000,  0.000, -0.000,-0.500,  0.500, -0.500, -1.000,  0.000, -0.000,-0.500, -0.500, -0.500, -1.000,  0.000, -0.000,-0.500,  0.500, -0.500,  0.000,  1.000,  0.000,-0.500,  0.500,  0.500,  0.000,  1.000,  0.000, 0.500,  0.500,  0.500,  0.000,  1.000,  0.000, 0.500,  0.500,  0.500,  0.000,  1.000,  0.000, 0.500,  0.500, -0.500,  0.000,  1.000,  0.000,-0.500,  0.500, -0.500,  0.000,  1.000,  0.000, 0.500,  0.500, -0.500,  1.000,  0.000, -0.000, 0.500,  0.500,  0.500,  1.000,  0.000, -0.000, 0.500, -0.500,  0.500,  1.000,  0.000, -0.000, 0.500, -0.500,  0.500,  1.000,  0.000,  0.000, 0.500, -0.500, -0.500,  1.000,  0.000,  0.000, 0.500,  0.500, -0.500,  1.000,  0.000,  0.000,-0.500, -0.500,  0.500,  0.000,  0.000,  1.000, 0.500, -0.500,  0.500,  0.000,  0.000,  1.000, 0.500,  0.500,  0.500,  0.000,  0.000,  1.000, 0.500,  0.500,  0.500,  0.000,  0.000,  1.000,-0.500,  0.500,  0.500,  0.000,  0.000,  1.000,-0.500, -0.500,  0.500,  0.000,  0.000,  1.000,  0.524,  0.000,  0.847,  0.000, -0.356,  0.934,-0.524,  0.000,  0.847,  0.000, -0.356,  0.934, 0.000, -0.847,  0.524,  0.000, -0.356,  0.934, 0.524,  0.000,  0.847,  0.000,  0.356,  0.934, 0.000,  0.847,  0.524,  0.000,  0.356,  0.934,-0.524,  0.000,  0.847,  0.000,  0.356,  0.934, 0.524,  0.000,  0.847,  0.577, -0.577,  0.577, 0.000, -0.847,  0.524,  0.577, -0.577,  0.577, 0.847, -0.524,  0.000,  0.577, -0.577,  0.577, 0.524,  0.000,  0.847,  0.934,  0.000,  0.356, 0.847, -0.524,  0.000,  0.934,  0.000,  0.356, 0.847,  0.524,  0.000,  0.934,  0.000,  0.356, 0.524,  0.000,  0.847,  0.577,  0.577,  0.577, 0.847,  0.524,  0.000,  0.577,  0.577,  0.577, 0.000,  0.847,  0.524,  0.577,  0.577,  0.577, 0.847, -0.524,  0.000,  0.934,  0.000, -0.356, 0.524,  0.000, -0.847,  0.934,  0.000, -0.356, 0.847,  0.524,  0.000,  0.934,  0.000, -0.356, 0.847,  0.524,  0.000,  0.577,  0.577, -0.577, 0.524,  0.000, -0.847,  0.577,  0.577, -0.577, 0.000,  0.847, -0.524,  0.577,  0.577, -0.577, 0.847,  0.524,  0.000,  0.356,  0.934,  0.000, 0.000,  0.847, -0.524,  0.356,  0.934,  0.000, 0.000,  0.847,  0.524,  0.356,  0.934,  0.000, 0.000,  0.847,  0.524, -0.356,  0.934,  0.000, 0.000,  0.847, -0.524, -0.356,  0.934,  0.000,-0.847,  0.524,  0.000, -0.356,  0.934,  0.000, 0.000,  0.847,  0.524, -0.577,  0.577,  0.577,-0.847,  0.524,  0.000, -0.577,  0.577,  0.577, -0.524,  0.000,  0.847, -0.577,  0.577,  0.577,-0.524,  0.000,  0.847, -0.934,  0.000,  0.356,-0.847,  0.524,  0.000, -0.934,  0.000,  0.356,-0.847, -0.524,  0.000, -0.934,  0.000,  0.356,-0.524,  0.000,  0.847, -0.577, -0.577,  0.577,-0.847, -0.524,  0.000, -0.577, -0.577,  0.577, 0.000, -0.847,  0.524, -0.577, -0.577,  0.577, 0.000, -0.847,  0.524, -0.356, -0.934, -0.000,-0.847, -0.524,  0.000, -0.356, -0.934, -0.000, 0.000, -0.847, -0.524, -0.356, -0.934, -0.000, 0.000, -0.847,  0.524,  0.356, -0.934,  0.000, 0.000, -0.847, -0.524,  0.356, -0.934,  0.000, 0.847, -0.524,  0.000,  0.356, -0.934,  0.000, 0.847, -0.524,  0.000,  0.577, -0.577, -0.577, 0.000, -0.847, -0.524,  0.577, -0.577, -0.577, 0.524,  0.000, -0.847,  0.577, -0.577, -0.577,-0.524,  0.000, -0.847,  0.000, -0.356, -0.934, 0.524,  0.000, -0.847,  0.000, -0.356, -0.934, 0.000, -0.847, -0.524,  0.000, -0.356, -0.934,-0.524,  0.000, -0.847,  0.000,  0.356, -0.934, 0.000,  0.847, -0.524,  0.000,  0.356, -0.934, 0.524,  0.000, -0.847,  0.000,  0.356, -0.934,-0.524,  0.000, -0.847, -0.577,  0.577, -0.577,-0.847,  0.524,  0.000, -0.577,  0.577, -0.577, 0.000,  0.847, -0.524, -0.577,  0.577, -0.577,-0.524,  0.000, -0.847, -0.934,  0.000, -0.356,-0.847, -0.524,  0.000, -0.934,  0.000, -0.356,-0.847,  0.524,  0.000, -0.934,  0.000, -0.356,-0.524,  0.000, -0.847, -0.577, -0.577, -0.577, 0.000, -0.847, -0.524, -0.577, -0.577, -0.577,-0.847, -0.524,  0.000, -0.577, -0.577, -0.577

	modelmatrix: .float 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1
	_scalemat: .float 200, 0, 0, 0, 0, 200, 0, 0, 0, 0, 200, 0, 0, 0, 0, 1
	_transmat: .float 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0, 300, 200, 300, 0
	rotationmatrix1: .float 0.9666981, -0.2471007,  0.0666038, 0,  0.2471007,  0.8334905, -0.4942013, 0,   0.0666038,  0.4942013,  0.8667924, 0,     0, 0, 0, 1
	rotationmatrix2: .float 0.9996954, -0.0171434,  0.0177525, 0,   0.0177525,  0.9992386, -0.0347437, 0,   -0.0171434,  0.0350482,  0.9992386, 0,    0, 0, 0, 1





	fltThrees: .float 3, 3, 3, 3
	fltAbsMask: .int 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF
	fltTest: .float 0.1, 1, 0.2, 0.8
	normMul: .float 255, 255, 255, 255

	ident1: .float 1, 0, 0, 0
	ident2: .float 0, 1, 0, 0
	ident3: .float 0, 0, 1, 0
	ident4: .float 0, 0, 0, 1

	fltOnes:  .float 1, 1, 1, 1
	fltZeros: .float 0, 0, 0, 0

	eventToProcess:	   .space 56
	globalWindowPtr:   .space 8
	pixelBufSize:      .quad 0
	globalPixelBufPtr: .space 8
	globalDepthBuf:    .space 8	
	globalTexturePtr:  .space 8
	globalRendererPtr: .space 8


	running: .int 1

	winWidth:   .quad  600
	winWidth2:  .float 599
	winHeight:  .quad  400
	winHeight2: .float 399
	winTitle:   .asciz ""
	intformat: .asciz "here is an int: %i\n"
	xmm0formatint: .asciz "xmm0 (int): %i, %i, %i, %i\n"
	xmm0formatflt: .asciz "xmm0 (flt): %f, %f, %f, %f\n"
