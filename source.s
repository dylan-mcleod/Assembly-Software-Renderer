.text
.global main

.intel_syntax noprefix

.equ true, 1
.equ false, 0

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

printxmm0flt:
	sub rsp, 0x228

	mov [rsp+0x18], rax
	mov [rsp+0x10], rdi

	fxsave [rsp+0x20]


	movups [rsp], xmm0
	movss xmm0, [rsp]
	movss xmm1, [rsp+4]
	movss xmm2, [rsp+8]
	movss xmm3, [rsp+12]
	
	mov rdi, OFFSET xmm0formatflt
	cvtss2sd xmm0, xmm0
	cvtss2sd xmm1, xmm1
	cvtss2sd xmm2, xmm2
	cvtss2sd xmm3, xmm3

	mov rax, 0x4
	call printf

	fxrstor [rsp+0x20]

	mov rax,[rsp+0x18]
	mov rdi,[rsp+0x10]

	add rsp, 0x228
	ret

#pass arg as 4 floats in xmm0, answer in eax
xmm2packed8888:
	sub rsp, 0x18
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
	
	add rsp, 0x18
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

		#<swap colors, normals>

		jmp raster_do2ndswap
	raster_noswap1:

	comiss xmm4, xmm6
	jnc raster_noswap2
		swapxmm  xmm0, xmm2, xmm3
	
		movaps [rbp+0x90], xmm2
		movaps [rbp+0x80], xmm1
		movaps [rbp+0x70], xmm0

		#<swap colors, normals>

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
		#<swap colors, normals>
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
		#if (mb < 0) { if (bx < b.x) bx = b.x, bz = b.z, alpha = 0; }
		#else        { if (bx > b.x) bx = b.x, bz = b.z, alpha = 0; }
		#if (mc < 0) { if (cx < c.x) cx = c.x, cz = c.z, beta  = 0; }
		#else        { if (cx > c.x) cx = c.x, cz = c.z, beta  = 0; }

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

		movss    xmm8, xmm5
		subss    xmm8, [rbp-0x50]  # bxDist
		
		movss    xmm9, xmm8
		mulss    xmm9, xmm6
		addss    xmm9, [rbp-0x48]  # starting z

		mulss    xmm8,  xmm6
		movss    xmm10, fltOnes
		subss    xmm10, xmm8
		movss    xmm8,  xmm10      # starting gamma (overwrites bxDist)

		movss    xmm10, [rsp-0x60] # alpha
		movss    xmm11, [rsp-0x5C] # beta
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
		raster_xloop:
			
			
			mov  eax, r8d
			mov  rcx, 0xFFFF00FF

			imul eax, r10d
			add  eax, edx

			mov  rbx, globalPixelBufPtr
			mov  [rbx+rax*4], rcx

			subss xmm8, xmm6
			addss xmm9, xmm7

			inc edx			
			cmp edx, r11d
			jle raster_xloop
		
		

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




	lea rax, hardcodedtri
	push [rax]
	push [rax+0x8]
	push [rax+0x10]
	push [rax+0x18]
	push [rax+0x20]
	push [rax+0x28]
	push [rax+0x30]
	push [rax+0x38]
	push [rax+0x40]
	push [rax+0x48]
	push [rax+0x50]
	push [rax+0x58]
	push [rax+0x60]
	push [rax+0x68]
	push [rax+0x70]
	push [rax+0x78]
	push [rax+0x80]
	push [rax+0x88]
	push [rax+0x90]
	push [rax+0x98]
	movups xmm0, [rax]
	movups xmm1, [rax+0x10]
	movups xmm2, [rax+0x20]
	mov rdi, 1
	call raster
	lea rax, hardcodedtri
	movups xmm0, [rax]
	movups xmm1, [rax+0x10]
	movups xmm2, [rax+0x20]
	mov rdi, 0
	call raster
	add rsp, 0xA0
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


	fltAbsMask: .int 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF
	fltTest: .float 0.1, 1, 0.2, 0.8
	normMul: .float 255, 255, 255, 255

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

	myobjects_spec: .long  1,1,0
	myobjects_mem:  .float 0,0,0,0,0,1,1,1,1, 0,1,0,0,0,1,1,1,1, 1,0,0,0,0,1,1,1,1
	winWidth:   .quad  600
	winWidth2:  .float 599
	winHeight:  .quad  400
	winHeight2: .float 399
	winTitle:   .asciz ""
	intformat: .asciz "here is an int: %i\n"
	xmm0formatint: .asciz "xmm0 (int): %i, %i, %i, %i\n"
	xmm0formatflt: .asciz "xmm0 (flt): %f, %f, %f, %f\n"
