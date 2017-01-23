.SILENT:

.PHONY: all clean res run

D71_IMAGE = "bin/commodore_home.d71"
D64_IMAGE = "bin/commodore_home.d64"
C1541 = c1541
X128 = x128
X64 = x64

all: res bin64 bin128
bin128: c_home128 d71 run128
bin64: c_home64 d64 run64

SRC=src/intro.s src/c_home.s src/exodecrunch.s src/menu.s src/utils.s src/data.s src/music_table.s

res:
	echo "Compressing and copying resources..."
	-cp res/mainscreen-colors.bin src/
	-cp res/alarm-map.bin src/
	-cp res/sprites.bin src/
	-cp res/sids/*.exo src/
	-exomizer mem -o src/mainscreen-map.bin.exo res/mainscreen-map.prg
	-exomizer mem -o src/mainscreen-charset.bin.exo res/mainscreen-charset.prg
	-exomizer mem -o src/intro-charset.bin.exo res/intro-charset.prg
	-exomizer mem -o src/intro-map.bin.exo res/intro-map.prg

#
# c128
#

c_home128: ${SRC}
	echo "Compiling..."
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c128 -C $@.cfg $^
	echo "Compressing executable..."
	exomizer sfx sys -x1 -Di_line_number=2016 -t128 -o bin/$@_exo.prg bin/$@.prg

d71:
	echo "Generating d71 file..."
	$(C1541) -format "commodore home 128,rq" d71 $(D71_IMAGE)
	$(C1541) $(D71_IMAGE) -write bin/c_home128-exo.prg "commodore home"
	$(C1541) $(D71_IMAGE) -list

run128:
	echo "Running game"
	$(X128) -verbose -moncommands bin/c_home128.sym $(D71_IMAGE)

#
# c64
#

c_home64: ${SRC}
	echo "Compiling..."
	cl65 -d -g -Ln bin/$@.sym -o bin/$@.prg -u __EXEHDR__ -t c64 -C $@.cfg $^
	echo "Compressing executable..."
	exomizer sfx sys -x1 -Di_line_number=2016 -t64 -o bin/$@-exo.prg bin/$@.prg

d64:
	echo "Generating d64 file..."
	$(C1541) -format "commodore home 64,rq" d64 $(D64_IMAGE)
	$(C1541) $(D64_IMAGE) -write bin/c_home64-exo.prg "commodore home"
	$(C1541) $(D64_IMAGE) -list

run64:
	echo "Running"
	$(X64) -verbose -moncommands bin/c_home64.sym $(D64_IMAGE)


#
# clean
#
clean:
	rm -f src/*.o bin/*.sym bin/*.prg $(D71_IMAGE) $(D64_IMAGE)

