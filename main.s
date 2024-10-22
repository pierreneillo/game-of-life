	.section .rodata
one:
	.string "#"

zero:
	.string "."

lf:
	.string "\n"

timespec:
	# Temps de sommeil (en s + ns)
	.quad 0 # s
	.quad 200000000 # ns

screen_clear:
	.string "\033[2J\033[H"
	.data
	# Pour stocker les adresses respectives des tableaux tab et buffer_tab
tab:
	.quad 0

buffer_tab:
	.quad 0
N:
	.byte 32 # Cannot exceed 64, or be 0
Nm1:
	.byte 31 # Cannot exceed 63, must be N - 1


	.text
	.globl main

print_char:
	# Print the char in %rbx
	mov %rbx, %rsi # Parameter (char*)
	mov $1, %rdx # Length
	mov $1, %rax # Print
	mov $1, %rdi # fd
	syscall
	ret

sleep:
	mov $35, %rax
    lea timespec(%rip), %rdi 
    xor %rsi, %rsi
    syscall
	ret

display:
	# Displays the game state on the terminal: # = 1 [space]|. = 0
	# Register used / manually modified:
	# rax - rdi, r8, r9, r11, r12, r15
	leaq screen_clear(%rip), %rsi # Parameter (char*)
	mov $8, %rdx # Length
	mov $1, %rax # Print
	mov $1, %rdi # fd
	syscall
	mov $0, %r15
	.display_for_loop:
		movzbq %r15b, %rdx
		call display_line
		inc %r15b
		cmp N(%rip), %r15b
		jl .display_for_loop
	leaq lf(%rip), %rbx
	call print_char
	ret

display_line:
	# Displays a given line (index of the line in %rdx)
	movq tab(%rip),%r8
	movq (%r8,%rdx,8), %r9 # Values on the line stocked in r9
	mov $0, %r12
	.display_line_for_loop:
		# Do line printing here
		mov $1, %r11
		mov %r12b, %cl
		sal %cl, %r11 
		and %r9, %r11
		cmp $0, %r11
		jne .print_one
		.print_zero:
			leaq zero(%rip), %rbx
			jmp .display_line_loop_suite
		.print_one:
			leaq one(%rip), %rbx
		.display_line_loop_suite:
			call print_char
			inc %r12b
			cmp N(%rip), %r12b
			jl .display_line_for_loop
	leaq lf(%rip), %rbx
	call print_char 
	ret

copy:
	# Copy the tab %rax into the tab %rbx
	mov $0, %rcx # Compteur de tdb (i) <=> for (int i = 0;...
	.copy_loop:
		movq (%rax,%rcx,8), %rdx
		movq %rdx, (%rbx,%rcx,8)
		inc %cl # <=> i++; ...
		cmp N(%rip), %cl # i < N)
		jl .copy_loop
	ret


in_mat:
	# Prend en paramètre (i,j) dans (%dil,%sil) et renvoie dans %rax si (i,j) est une position valide (0 = false, 1 = true)
	# Registres modifiés:
	# rax
	cmp $0, %dil
	jl .in_mat_ret_0
	cmp $0, %sil
	jl .in_mat_ret_0
	cmp N(%rip), %dil
	jge .in_mat_ret_0
	cmp N(%rip), %sil
	jge .in_mat_ret_0
	mov $1, %rax
	ret
	.in_mat_ret_0:
		mov $0, %rax
		ret

get_val:
	# Prend en paramètre (i,j) dans (%dil,%sil) et renvoie dans %rax la valeur de la case
	# Registres modifiés:
	# rax - rdx
	movq tab(%rip), %rax
	movzbq %sil, %rcx
	movq (%rax,%rcx,8), %rbx
	movb %dil, %cl
	movq $1, %rdx
	sal %cl, %rdx
	and %rdx, %rbx
	cmp $0, %rbx
	setne %al
	movzbq %al, %rax
	ret

get_val_opt:
	# Same as get_val, but checks if value is accessible first
	# Registres modifiés:
	# rax - rdx
	call in_mat
	cmp $0, %rax
	jz get_val_opt_end
	call get_val
	get_val_opt_end:
		ret

nb_voisines_vivantes:
	# Prend en paramètre (i,j) dans (%dil,%sil) et renvoie dans %rax le nombre de voisines vivantes
	# Registres modifiés:
	# rax - rdx, r8
	xor %r8, %r8
	.nbv_e1:
		# ...
		# .o#
		# ...
		cmp %dil, Nm1(%rip)
		jbe .nbv_e3
		inc %dil
		call get_val
		add %rax, %r8
		dec %dil
	.nbv_e2:
		# ...
		# .o.
		# ..#
		cmp %sil, Nm1(%rip)
		jbe .nbv_e5
		inc %sil
		inc %dil
		call get_val
		add %rax, %r8
		dec %dil
		dec %sil
	.nbv_e3:
		# ...
		# .o.
		# .#.
		cmp %sil, Nm1(%rip)
		jbe .nbv_e5
		inc %sil
		call get_val
		add %rax, %r8
		dec %sil
	.nbv_e4:
		# ...
		# .o.
		# #..
		cmp $0, %dil
		jbe .nbv_e7
		dec %dil
		inc %sil
		call get_val
		add %rax, %r8
		inc %dil
		dec %sil
	.nbv_e5:
		# ...
		# #o.
		# ...
		cmp $0, %dil
		jbe .nbv_e7
		dec %dil
		call get_val
		add %rax, %r8
		inc %dil
	.nbv_e6:
		# #..
		# .o.
		# ...
		cmp $0, %dil
		jbe .nbv_fin
		dec %sil
		dec %dil
		call get_val
		add %rax, %r8
		inc %sil
		inc %dil
	.nbv_e7:
		# .#.
		# .o.
		# ...
		cmp $0, %sil
		jbe .nbv_fin
		dec %sil
		call get_val
		add %rax, %r8
		inc %sil
	.nbv_e8:
		# ..#
		# .o.
		# ...
		cmp %dil, Nm1(%rip)
		jbe .nbv_fin
		inc %dil
		dec %sil
		call get_val
		add %rax, %r8
		dec %dil
		inc %sil
	.nbv_fin:
		movq %r8, %rax
		ret

set_val:
	# Prend en paramètre (i,j) dans (%dil,%sil) et met cette case de buffer_tab à la valeur dans %rax
	# Registres modifiés:

	mov buffer_tab(%rip), %rbx
	movzbq %sil, %rsi
	mov (%rbx,%rsi,8),%r8
	mov %dil, %cl
	mov $1, %rdx
	sal %cl, %rdx
	cmp $0, %rax
	je .set_val_0
	or %r8, %rdx
	jmp .set_val_fin
	.set_val_0:
		not %rdx
		and %r8,%rdx
	.set_val_fin:
		mov %rdx, (%rbx,%rsi,8)
		ret

generation_case:
	# Prend en paramètre (i,j) dans (%dil,%sil) et calcule la nouvelle valeur de la case
	# à la génération suivante, la stocke dans le buffer
	# LA VALIDITE DES INDICES EST SUPPOSEE
	# Registres modifiés:
	# rax - rdx, r8
	call nb_voisines_vivantes
	movq %rax, %r8
	call get_val
	xor %rbx, %rbx
	mov $1, %rdx
	cmp $3, %r8
	cmove %rdx, %rbx
	cmp $2, %r8
	cmove %rax, %rbx
	movq %rbx, %rax
	call set_val
	ret


generation:
	# Calculates a generation and outputs either zero or one in %rax, zero if there were changes, one if there were none	

	mov $0, %sil
	.for_sil:
		mov $0, %dil
		.for_dil:
			call generation_case
			inc %dil
			cmp N(%rip), %dil
			jl .for_dil
		inc %sil
		cmp N(%rip), %sil
		jl .for_sil


	# copy from buffer to tab
	mov buffer_tab(%rip), %rax
	mov tab(%rip), %rbx
	call copy
	ret


main:
	# Allocate the necessary memory (tab + buffer)

	# Buffer malloc
	mov $64, %rdi
	imul $8, %rdi
	call malloc
	mov %rax, buffer_tab(%rip)
	
	# tab malloc
	mov $64, %rdi
	imul $8, %rdi
	call malloc
	mov %rax, tab(%rip)
	
	# Initialize tab
	mov $0, %rcx # Compteur de tdb (i) <=> for (int i = 0;...
	.init_loop:
		movq $0, (%rax,%rcx,8)
		inc %cl # <=> i++; ...
		cmp N(%rip), %cl # i < N)
		jl .init_loop

	# Change table values
	movq $0, %rcx
	movq $2, (%rax,%rcx,8)
	inc %rcx
	movq $4, (%rax, %rcx, 8)
	inc %rcx
	movq $7, (%rax, %rcx, 8)

	# Planeur:

	# .#...
	# ..#..
	# ###..
	# .....
	# .....
	
	# .....
	# #.#..
	# .##..
	# .#...
	# .....

	# .....
	# ..#..
	# #.#..
	# .##..
	# .....

	# .....
	# .#...
	# ..##.
	# .##..
	# .....

	mov $0, %rdi
	mov $1, %rsi
	call nb_voisines_vivantes

	# Call main loop
	.boucle:
		call display
		call generation
		call sleep
		jmp .boucle

	# Set return code to zero
	xor %rax, %rax
	ret
	.section .note.GNU-stack
