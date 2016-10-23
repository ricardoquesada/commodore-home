.SILENT:

.PHONY: all clean res run

X64 = x64

all: bin
bin: c_home run

SRC=src/c_home.s

c_home: ${SRC}
	echo "Compiling..."
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c64 -C $@.cfg $^
	echo "Compressing executable..."
	exomizer sfx sys -x1 -Di_line_number=2016 -o bin/$@_exo.prg bin/$@.prg

run:
	echo "Running game"
	$(X64) -verbose -moncommands bin/c_home.sym bin/c_home.prg

clean:
	rm -f bin/*.sym src/*.o

