#temp='C:\Users\Administrator\Application Data\SSH\temp\temp.dat'
#gap='C:\Users\Administrator\Application Data\SSH\temp\gap.dat'
#raman='C:\Users\Administrator\Application Data\SSH\temp\raman.dat'
#spect='C:\Users\Administrator\Application Data\SSH\temp\spect_0.dat'
#energy='C:\Users\Administrator\Application Data\SSH\temp\energy_090.dat'
#fermi='C:\Users\Administrator\Application Data\SSH\temp\fermi.dat'
#energy='../data/energy.dat'
#fermi='../data/fermi.dat'
#temp='../data/temp.dat'
#gap='../data/gap.dat'
#raman='../data/raman.dat'
#spect='../data/spect_0.dat'
phase='~/data/phase_ddw_0.7_t_0.5.dat'
# set multiplot layout 2,1
# plot the energy band
#set term wxt 0
#unset key
#set ytic 0.01
#set size square
#plot for[i=1:4] energy using 0:(column(2*i-1)):(column(i*2)) with points lt 1 pt 7 ps variable,\
	 #for[i=1:4] energy using 0:(column(2*i-1)) with line lt 0
#reset
# # plot for[i=1:4] energy using 0:(column(2*i-1)-(column(i*2)*0.01)):(column(2*i-1)+(column(i*2)*0.01)) with filledcurves lt 1,\
	# # for[i=1:4] energy using 0:(column(2*i-1)) with line lt 0
#set term wxt 1
## # plot the fermi surface
## unset xtic
## unset key
## set size square
## set palette rgbformulae 22,13,-31
## set cbrange [0:1]
## set pm3d map
## set pm3d interpolate 0,0
## splot [0:3.1416][0:3.1416] fermi

set term wxt 2
#set term pngcairo font "AR PL UKai CN,14"
#set output "precipitation.png"
## plot the temprature dependence
set xtic 50
plot phase using 4:6 with linespoints pt 7 lw 5 , phase using 4:8 with linespoints pt 7 lw 5

#set term wxt 3
## # plot gap
## set xtic 5
## plot [:] gap using 1:2 with line
#set xtic 0.01
#set term wxt 4
#plot spect with line

#set term wxt 5
## # plot Raman
## set xtic 0.02
## plot [:][:] raman using 1:2 with line axis x1y1, raman using 1:3 with line axis x1y2
## plot [:][:] raman using 1:4 with line axis x1y1, raman using 1:5 with line axis x1y2

reset
set term wxt 6
# plot phase diagram
#set term pngcairo font "AR PL UKai CN,14"
#set output "precipitation.png"
unset key
plot phase using 2:4:($8<1e-4?1/0:$8) with labels, phase using 2:($8<1e-4?$4:1/0) with points pt 4