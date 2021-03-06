reset
#custom
#multiplot
ix=1
iy=1
sx=3*ix
sy=3*iy
xlb=" "
ylb=" "
ml=0.5/sx
mb=0.3/sy
mr=0.1/sx
mt=0.1/sy
gx=(1.-ml-mr)/ix
gy=(1.-mb-mt)/iy
#term
set term eps font ",18" size sx,sy enhance
set output "-."."eps"
set label ylb font ",20" rotate by 90 center at character 0.8,screen 0.5*(1+mb-mt)
set label xlb font ",20" center at screen 0.5*(1+ml-mr),character 0.5
set xtics out nomirror offset 0,0.5
set ytics out nomirror offset 0.5,0
set border front lw 5
#
set size gx,gy
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
do for[i=0:(ix*iy-1)]{
	oxi=i%ix
	oyi=i/ix+1
	set origin ml+oxi*gx,mb+(iy-oyi)*gy
	#set xtics word("1 0.5 0.5",i+1)
	if(oxi!=0){
		set format y ""
	}
	if(oyi!=iy){
		set format x ""
	}
	if(i==(ix*iy-1)){
		set key font ",16" at screen 1-mr-0.01/sx,1-mt-0.01/sy horizontal maxcols 1 opaque samplen 0.5 autotitle #columnhead
	}
	#set label sprintf("(%1.3f)",0.11+0.005*i) at graph 0.1/(gx*sx),1.-0.15/(gy*sy)
	#plot [:word("8.7 2.3 1",i+1)][0:0.16] for[j=0:1] "-" index i using ($0/word("5. 20. 40.",i+1)):(-column(5+j*2)):(column(6+j*2)) with p pt 6 ps var lc j+1 title " ", for[j=0:1] "-" index i using ($0/word("5. 20. 40.",i+1)):(column(13+j)) with line lw 5 lc j+4 title " "
	#plot [:][0:] for[j=0:11] "-" index i every :::j::j using 2:4  with lp pt 7 ps 0.3 title "".j,for[j=0:11] "-" index i every :::j::j using 2:3  with lp pt 5 ps 0.3 notitle, 
	plot [:][0:] for[j=0:0] "-" index i every :::j::j using 1:2  with lp pt 7 ps 0.3 title "".j
	unset label
	unset format
}
#data
