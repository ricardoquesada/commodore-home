    1 gosub 1000
   10 print chr$(147)
   11 poke53272,23:rem lowercase
   15 poke53280,0
   16 poke53281,0
   17 print "{wht}"
   20 print "            c64 I.D.I.o.T.R"
   30 print "            ---------------"
   40 print ""
   50 print "Intelligent Dimmer for Internet o'Things"
   51 print "                RRRRRRR"
   52 print ""
   55 print ""
   60 print "   The world's first IoT smart device"
   70 print ""
   80 print ""
   90 print ""
  100 print "   Connect the UniJoystiCle to port#2"
  110 print "      Connect your MPS 803 printer"
  120 print ""
  130 print "     And start dimming your lights!"
  150 open 3,4
  190 last=0
  200 a%=31 - peek(56320) and 31
  210 p%=int(2.5*a%)
  220 if p%<>last% goto 300
  230 goto 200
  300 last%=p%
  310 if p%>=10 goto 400
  330 l$="0"+mid$(str$(p%),2,2)
  340 goto 500
  400 l$=mid$(str$(p%),2,2)
  500 x%=17
  501 y%=19
  502 gosub2000
  503 print "   "
  504 gosub2000
  505 print a%
  510 print#3,chr$(16);l$;"."
  520 id%=a%/6.22
  530 poke53280,co%(id%)
  540 poke53281,co%(id%)
  560 goto 200
 1000 dim co%(4)
 1010 co%(0)=0
 1020 co%(1)=11
 1030 co%(2)=12
 1040 co%(3)=15
 1050 co%(4)=1
 1100 return
 2000 poke780,0
 2001 poke783,0
 2010 poke781,x%
 2020 poke782,y%
 2030 sys65520
 2040 return
