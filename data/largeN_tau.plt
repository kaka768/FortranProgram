reset
sx=4.3
sy=3.12
x1lb="X"
y1lb="Y"
#x2lb="X"
#y2lb="Y"
#zlb="Z"
lmg=8.5
rmg=5.5
umg=2.5
dmg=2.5
fontsize=15
ticfontsize=floor(fontsize*0.7)
#term
c2sx=0.1235/12*fontsize
c2sy=0.2206/12*fontsize
set term eps rounded fontscale 1 font "Helvetica,".fontsize lw 5 size sx+(lmg+rmg)*c2sx,sy+(dmg+umg)*c2sy 
set output "-."."eps"
unset key
unset tics
set ticslevel 0
#set grid xtics ytics
set border 8+4+2+1+16+32+64+128+256+512+1024+2048 front
set margin lmg,rmg,dmg,umg
#set size ratio -1

set pm3d corners2color c2
set palette rgbformulae 22,13,-31
#set logscale cb
#set cbrange [0.8:100]
set cbrange [:]
set cbtics scale 0.5 offset 0,character 2.1 font ",".(ticfontsize)
set colorbox horiz user origin graph 0,1+c2sy/sy*0.5 size graph 1,character 0.6
#set cbtics scale 0.5 offset character -0.7, 0 font ",".(ticfontsize)
#set colorbox user origin graph 1+c2sx/sx*0.5,0 size character 1, graph 1

set xrange [:]
set yrange [:]
set zrange [:]
#set logscale x
#set logscale y
#a=0.769
a=0.41
b=0.0001/1.1*tan(pi*(1.+a)/2.)
#fit [x=0.00000001:0.00001] b*x**a  "-" index 70 u 1:(abs($2)/10000.) via a,b
array cl[2]=["SEf","GphiGf"]
array fact[2]=[1,-1]
#plot for[k=1:40] for[i=k*1-1:k*1-1] "-" index i every :::1::1 u (pi*column("T")/sin(pi*column("tau")*column("T"))):(-column("GB")) with l notitle#,  1/((1.7*x)**(-0.6)+2.) w line dt 2 notitle#,  (x)**(a) w line dt 2 notitle
plot for[k=1:1] for[j=1:|cl|] for[i=k*1-1:k*1-1] "-" index i u (column("tau")*column("T")):(column(cl[j])*fact[j]) with l notitle
#plot for[i=1:1] "-" index i u 0:(pi*column("T")/sin(pi*column("tau")*column("T"))) with l notitle sprintf("J= %1.2f",(i+1)/72*0.05+1)#,  1./((x)**(-a)+2) w line dt 2 notitle,  (x)**(a) w line dt 2 notitle
#plot "-" index 0 every 1:1:::574/2 u (pi*$1/sin(pi*$2*$1)):(pi*$1/sin(pi*$2*$1)) with p notitle
set key font ",".ticfontsize at graph 0.43,0.65,1 horizontal maxcols 1 spacing 0.9 samplen 1.5 #opaque autotitle
set label "(a)" font ",".fontsize front center textcolor rgb "black" at graph 0+c2sx/sx*2,1-c2sy/sy,1+2*c2sy/sy
if(exists("zlb")){
	set key at screen 1,1,1
}

set mxtics 5
set mytics 5
set mx2tics 5
set my2tics 5
set mztics 5
set format "%h"
if(exists("zlb")){
	set ztics out scale 0.7, 0.3 offset 0.7,0 font ",".(ticfontsize)
	set zlabel zlb offset character 3,0 
}
if(exists("x1lb")) {
	set xlabel x1lb offset character 0,1.2 
	#set label x1lb center at graph 0.5,screen 0 front offset character 0, 0.7
	set xtics out nomirror scale 0.7, 0.3 offset 0,0.5 font ",".(ticfontsize)
	if(exists("zlb")) {
		set xlabel offset character 0,0
		set xtics offset 0,0 
	}
} 
if(exists("x2lb")) {
	set x2label x2lb offset character 0,-1.2 
	#set label x2lb center at graph 0.5,screen 1 front offset character 0, -0.7
	set x2range [GPVAL_X_MIN:GPVAL_X_MAX]
	set x2tics out nomirror scale 0.7, 0.3 offset 0,-0.5 font ",".(ticfontsize)
	if(exists("zlb")) {
		set x2label offset character 0,0
		set x2tics offset 0,0
	}
}
if(exists("y1lb")) {
	set ylabel y1lb offset character 3,0 
	#set label y1lb center at screen 0,graph 0.5 front offset character 1,0 rotate by 90
	set ytics out mirror scale 0.7, 0.3 offset 0.7,0 font ",".(ticfontsize)
	if(exists("zlb")) {
		set ylabel offset character 0,0
		set ytics offset 0,0
	}
}
if(exists("y2lb")) {
	set y2label y2lb offset character -3,0 rotate by -90
	#set label y2lb center at screen 1,graph 0.5 front offset character -1,0 rotate by -90
	set y2range [GPVAL_Y_MIN:GPVAL_Y_MAX]
	set y2tics out mirror scale 0.7, 0.3 offset -0.7,0 font ",".(ticfontsize)
	if(exists("zlb")) {
		set y2label offset character 0,0
		set y2tics offset 0,0
	}
}


set output "-."."eps"
replot
if(GPVAL_TERM eq "qt"){
	pause -1
}
#data

