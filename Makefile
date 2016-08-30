BINARIES = c64-idiotr.prg

all: $(BINARIES)

clean:
	rm -f *.prg

%.prg: %.bas
	petcat -w2 -o $@ $<
