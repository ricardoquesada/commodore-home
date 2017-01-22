.SILENT:

.PHONY: all clean res run

X64 = x64
D64_IMAGE = "bin/commodore_home.d64"

all: data c_home d64 run

SRC=src/intro.s src/c_home.s src/exodecrunch.s src/menu.s src/utils.s src/data.s src/music_table.s

data:
	-cp res/mainscreen-colors.bin src/
	-cp res/alarm-map.bin src/
	-cp res/sprites.bin src/
	-cp res/sids/*.exo src/
	-exomizer mem -o src/mainscreen-map.bin.exo res/mainscreen-map.prg
	-exomizer mem -o src/mainscreen-charset.bin.exo res/mainscreen-charset.prg
	-exomizer mem -o src/intro-charset.bin.exo res/intro-charset.prg
	-exomizer mem -o src/intro-map.bin.exo res/intro-map.prg

c_home: ${SRC}
	echo "Compiling..."
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c64 -C $@.cfg $^
	echo "Compressing executable..."
	exomizer sfx sys -x1 -Di_line_number=2016 -o bin/$@_exo.prg bin/$@.prg

run:
	echo "Running game"
	$(X64) -verbose -moncommands bin/c_home.sym bin/c_home.prg

d64:
	echo "Generating d64 file..."
	$(C1541) -format "commodore home,rq" d64 $(D64_IMAGE)
	$(C1541) $(D64_IMAGE) -write bin/c_home.prg "commodore home"
	$(C1541) $(D64_IMAGE) -list

clean:
	rm -f bin/*.sym src/*.o

