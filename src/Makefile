# Tema 5 - compilar el mini-programa de IPC
CC      = gcc
CFLAGS  = -O2 -Wall -Wextra -pthread -g

primes_ipc: primes_ipc.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f primes_ipc

.PHONY: clean
