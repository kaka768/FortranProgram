reset
#custom
#multiplot
ix=1
iy=1
sx=3*ix
sy=3*iy
xlb="dq"
ylb="Den"
ml=0.6/sx
mb=0.4/sy
mr=0.15/sx
mt=0.1/sy
gx=(1.-ml-mr)/ix
gy=(1.-mb-mt)/iy
#term
set term eps font "Times Bold,18" size sx,sy enhanced
set output "-."."eps"
set label ylb font ",20" rotate by 90 center at character 0.8,screen 0.5*(1+mb-mt)
set label xlb font ",20" center at screen 0.5*(1+ml-mr),character 0.7
set xtics 0.2 out nomirror scale 1 offset 0,0.5
set ytics 0.2 out nomirror scale 1 offset 0.5,0
set border front lw 5
#set grid xtics ytics
#
set size gx,gy
#set size ratio -1
set tmargin 0
set bmargin 0
set lmargin 0
set rmargin 0
set multiplot
set mxtics 5
set mytics 5
unset xlabel
unset ylabel
unset key
sp='< awk -v RS="\n\n\n" -v cmd="sort -g -k1 -k2" ''{print | cmd; close(cmd); print ""}'' "-" | awk ''NF < 3 {print;next};$1 != prev {printf "\n"; prev=$1};{print}'''
do for[i=0:(ix*iy-1)]{
	oxi=i%ix
	oyi=i/ix+1
	set origin ml+oxi*gx,mb+(iy-oyi)*gy
	set pm3d map
	set pm3d corners2color c2
	#set logscale cb
	set cbrange [:]
	#set size square
	set palette rgbformulae 22,13,-31
	if(oxi!=0){
		set format y ""
	}
	if(oyi!=iy){
		set format x ""
	}
	if(i==(ix*iy-1)){
		set key font ",20" at screen 1-mr-0.01/sx,0.45 horizontal maxcols 1 samplen 0.5 # autotitle
	}
	#set label sprintf("(%1.3f)",0.11+0.005*i) at graph 0.1/(gx*sx),1.-0.15/(gy*sy)
	set xzeroaxis lt -1 lw 5 dt 2
	plot [:][:] for[j=0:4] "-" index i every :::j::j using (3.1416-$3):4 with l lw 8 title word("x=0.05 0.1 0.123 0.135 0.15",j+1)
	#plot [:][:] for[j=0:4] "-" index i every :::j::j using (3.1416-$3):4 with l lw 8 title word("x=0.12 0.135 0.15",j+1)
	#splot [:][:] sp index 0 using 1:2:(-$5)
	unset label
	unset format
}
unset multiplot
if(GPVAL_TERM eq "qt"){
	pause -1
}
#data
