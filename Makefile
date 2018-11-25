
renderer.out: source.o
	gcc -no-pie -O0 -g -Wall -o renderer.out source.o -l SDL2

source.o: source.s
	gcc -no-pie -O0 -g -Wall -c -o source.o source.s

clean: 
	rm -f source.o renderer.out

